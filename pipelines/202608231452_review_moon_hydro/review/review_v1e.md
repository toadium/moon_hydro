# R1e: persistence/ + backend/ + frontend/ 三模块审查

审查时间：2026-08-23 15:10

### 审查范围

- persistence/store.mbt, persistence/file_io.mbt, persistence/store_test.mbt, persistence/file_io_test.mbt
- backend/main.mbt, backend/cli.mbt, backend/cli_wbtest.mbt
- frontend/main.mbt, frontend/lib/tea_arch.mbt, frontend/lib/msg_enum.mbt, frontend/lib/update_logic.mbt, frontend/lib/view_layout.mbt, frontend/lib/wasm_slim_model.mbt, frontend/lib/tea_test.mbt, frontend/lib/wasm_slim_test.mbt
- 参照：persistence/fileio.c（C FFI 实现）、各 moon.pkg、pkg.generated.mbti、shared/model.mbt、shared/xaj_core.mbt、shared/auth.mbt

### 发现

---

#### [严重] validate_path 使用 abort 导致路径遍历输入直接崩溃进程

- **位置**：`persistence/file_io.mbt:36-40`
- **描述**：`validate_path` 检测到路径包含 `".."` 时调用 `abort(...)` 终止整个进程。`abort` 抛出的是不可捕获的致命错误，无法被 `try/catch` 拦截。`write_file`/`read_file`/`delete_file` 均已声明 `raise`，本应通过 `raise FileError::...` 返回可恢复错误，但路径校验却走 `abort`，导致：① 任意含 `".."` 的路径（包括误传）直接 crash；② 若本模块未来用于服务端，单条恶意请求即令整个服务崩溃（DoS）。这与同文件中其他错误用 `raise FileError` 的处理方式不一致。
- **建议**：改为 `raise FileError::WriteFailed("path traversal detected: " + path)`（或新增 `FileError::InvalidPath` 变体），使调用方可捕获并友好处理。同时将 `validate_path` 签名改为 `-> Unit raise`。

---

#### [严重] file_exists 绕过路径遍历校验

- **位置**：`persistence/file_io.mbt:80-83`
- **描述**：`write_file`/`read_file`/`delete_file` 均在入口调用 `validate_path`，但 `file_exists` 未调用，直接将原始路径编码后传给 C FFI `hydro_file_exists`。攻击者可通过 `file_exists("../../../etc/passwd")` 探测任意系统文件是否存在，构成信息泄露；也与上述三个函数的安全边界不一致。
- **建议**：在 `file_exists` 首行添加 `validate_path(path)`（并将 `validate_path` 改为 `raise` 后，`file_exists` 签名相应改为 `-> Bool raise`，或内部 try-catch 转为返回 `false`）。

---

#### [严重] DataStore 无任何并发保护，多协程访问存在数据竞争

- **位置**：`persistence/store.mbt:49-53`（DataStore 定义）、`store.mbt:69-74`（save_scheme）、`store.mbt:108-110`（save_result）
- **描述**：`DataStore` 内部使用 `Map[String, ...]` 和 `Array[ResultRecord]`（均为可变引用类型），所有 CRUD 方法以 `self : DataStore` 借用接收但直接原地修改字段。MoonBit 的 `Map`/`Array` 非线程安全，若多个协程/线程共享同一 `DataStore` 实例并发调用 `save_scheme`/`save_result`/`delete_scheme` 等，将产生数据竞争（Map 并发写可能丢失条目或损坏内部结构）。当前 CLI 单线程使用暂无触发，但 scope 明确要求关注并发安全，且 `cli_persistence` 演示了 `DataStore` 的复用模式。
- **建议**：在文档/类型上明确标注 `DataStore` 非线程安全、仅限单线程使用；若需并发，封装为带锁的 `SyncDataStore` 或改为不可变值类型 + CAS 替换。

---

#### [一般] save_result 仅追加不去重，重复保存产生重复记录

- **位置**：`persistence/store.mbt:108-110`
- **描述**：`save_result` 直接 `self.results.push(result)`，不按 `result.id` 去重也不更新。对同一 `ResultRecord` 多次调用 `save_result` 会产生重复条目，`list_results` 会返回重复结果。这与 `save_scheme`/`save_param_set`（基于 Map 的 upsert 语义）不一致。此外不存在 `delete_result`/`update_result`/`clear_results` 方法，结果数组只能单调增长，长运行进程存在内存增长隐患。
- **建议**：① 将 `results` 改为 `Map[String, ResultRecord]` 以 id 为键实现 upsert 语义；或 ② 提供 `delete_result(id)`/`clear_results(scheme_id)` 方法并文档说明追加语义。至少补充 `delete_result` 以支持清理。

---

#### [一般] validate_path 仅检查 ".." 子串，未拦截绝对路径

- **位置**：`persistence/file_io.mbt:36-40`
- **描述**：`path.contains("..")` 仅检测相对路径回溯，不拦截绝对路径（如 `/etc/passwd`、`/root/.ssh/id_rsa`）。若路径来源于外部输入，攻击者可读写任意系统文件。此外 `contains("..")` 会误拦合法文件名（如 `foo..bar.json`），属于过严误报。C 侧 `hydro_write_file` 以 `"wb"` 打开，`fchmod` 设 0640，但文件位置无限制。
- **建议**：① 增加绝对路径检测（`path.starts_with("/")` 或 Windows 盘符检测）；② 将 `".."` 检测改为路径分量级检测（按分隔符拆分后检查分量是否为 `".."`），避免误报；③ 约定固定数据目录并校验最终规范化路径在该目录内。

---

#### [一般] hydro_read_file 部分读取时静默返回空字节，与空文件不可区分

- **位置**：`persistence/fileio.c:62-68`、`persistence/file_io.mbt:65-74`
- **描述**：C 侧 `hydro_read_file` 在 `fread` 返回字节数不等于 `size` 时返回 `moonbit_make_bytes(0, 0)`（空字节），与文件真实为空时的返回值完全相同。MoonBit 侧 `read_file` 对空字节执行 `@utf8.decode` 得到 `""`，调用方无法区分"文件内容为空"与"读取中途失败（如 I/O 错误、文件被截断）"。这会导致损坏文件的错误被静默吞没。
- **建议**：C 侧在 `read != size` 时通过某种方式区分错误（如返回 `NULL` 或单独的错误码接口），MoonBit 侧据此 `raise FileError::ReadFailed(path)`。

---

#### [一般] delete_file 失败抛出 WriteFailed，错误语义错误

- **位置**：`persistence/file_io.mbt:94-101`
- **描述**：`delete_file` 在 C 侧返回非 0 时 `raise FileError::WriteFailed(path)`。删除操作失败语义上不是"写入失败"，`FileError` 也无 `DeleteFailed` 变体。调用方按 `WriteFailed` 分支处理删除错误会产生误判。
- **建议**：为 `FileError` 新增 `DeleteFailed(String)` 变体，或复用 `ReadFailed`，并在文档中注明。

---

#### [一般] 路径遍历安全校验（validate_path）无任何测试覆盖

- **位置**：`persistence/file_io_test.mbt`（全文件）
- **描述**：`validate_path` 是安全关键代码（防路径遍历），但测试文件中无任何用例验证含 `".."` 路径被拒绝。由于当前实现用 `abort`，确实难以用常规 `test` 捕获，但这恰恰说明 `abort` 选择阻碍了可测试性。`file_exists` 绕过校验的问题也因此未暴露。
- **建议**：将 `validate_path` 改为 `raise` 后，补充测试：`try write_file("../evil", "x") catch { FileError::... => () }`，并测试 `file_exists("../evil")` 被拦截。

---

#### [一般] CLI 入口硬编码 dispatch("demo")，20 个子命令从命令行不可达

- **位置**：`backend/main.mbt:11-15`
- **描述**：`main` 固定调用 `dispatch("demo")`，注释说明"待 MoonBit 标准库提供 argv 后接入"。当前状态下，用户无法通过命令行参数选择 `sim`/`calibrate`/`persistence` 等子命令，CLI 实际不可用——所有子命令仅能通过 `demo` 间接运行。`dispatch` 函数本身已完整实现 21 路分发，仅缺 argv 接入。
- **建议**：若 MoonBit 已提供 `@env.argv` 或等价 API，立即接入 `dispatch(argv[1])`；否则在 `help` 输出和 README 中明确标注此限制，避免用户误以为 CLI 可按子命令调用。

---

#### [一般] cli_metrics 中 sim = obs，评价指标恒为完美值，演示具有误导性

- **位置**：`backend/cli.mbt:462-464`
- **描述**：`let obs = model.run(forcings).runoff_series` 后 `let sim = obs`，即仿真序列直接等于观测序列，随后 `evaluate_extended(obs, sim)` 计算的 NSE/KGE/d 等全部为完美值（NSE=1.0, KGE=1.0, d=1.0, RSR=0, MAE=0）。该子命令名为"扩展评价指标计算"但实际从不展示非完美结果，无法体现指标区分能力，对用户产生误导。
- **建议**：对 `sim` 引入可控扰动（如 `obs.map(fn(x) { x * 1.1 + 0.5 })`）或使用不同参数运行模型生成 `sim`，使指标反映真实差异。

---

#### [一般] cli_auth 硬编码明文密码并直接访问 AuthManager 内部 Map

- **位置**：`backend/cli.mbt:636-651`（硬编码密码）、`cli.mbt:685-687`（`auth.users[admin_id]`）
- **描述**：① 演示中密码 `"admin123"`/`"eng123"`/`"view123"` 以明文字面量写入源码，虽为演示，但若此代码被用作模板或部署，硬编码凭据构成安全隐患。② `auth.users[admin_id]` 直接索引 `AuthManager` 的内部 `users : Map[String, User]` 字段，绕过 `AuthManager` 的封装边界。若 `AuthManager` 内部结构变更（如 `users` 改名或改类型），此处即编译失败；且无越界保护（若 `admin_id` 不在 map 中会 panic）。
- **建议**：① 将演示密码移至配置或标注 `// DEMO ONLY — never use in production`；② 在 `AuthManager` 提供 `get_user(id) -> User?` 方法，CLI 通过该方法获取用户。

---

#### [一般] cli_auth 用 `_ => false` 过宽捕获异常，吞没所有错误

- **位置**：`backend/cli.mbt:693-698`、`cli.mbt:709-714`
- **描述**：`try { auth.check_permission(eng_user, ...); true } catch { _ => false }` 捕获所有异常类型并统一视为"权限拒绝"。`check_permission` 可能抛出 `AuthError::UserNotFound`、`InvalidToken` 等非权限类错误，这些均被静默当作 DENY 处理，错误信息丢失。同样模式出现在 `check_scheme_access` 的调用处。
- **建议**：精确捕获 `AuthError::PermissionDenied`/`SchemeNotOwned`，对其他异常重新抛出或记录。

---

#### [一般] cli_flood / cli_gis / cli_auth / cli_ai_forecast 通过 println 直接输出，未走 CliResult.details 结构化返回

- **位置**：`backend/cli.mbt:915-964`（cli_flood）、`cli.mbt:815-911`（cli_gis）、`cli.mbt:629-743`（cli_auth）、`cli.mbt:747-811`（cli_ai_forecast）
- **描述**：这四个子命令在函数体内大量调用 `println(...)` 直接向 stdout 输出演示内容，而返回的 `CliResult` 的 `details` 字段为空串或仅含少量信息。与 `cli_sim`/`cli_calibrate` 等将结果存入 `details` 的模式不一致。后果：① 输出无法被调用方程序化捕获（只能截获 stdout）；② `print_cli_result` 对这些命令仅打印一行摘要，大量信息已通过 println 提前输出，输出顺序不统一；③ 白盒测试无法验证输出内容。
- **建议**：将演示内容构造为字符串赋给 `details`，由 `print_cli_result` 统一输出；或为演示类命令定义独立的输出协议。

---

#### [一般] CalibrationCompleted 硬编码 calib_metric="nse"，KGE 率定结果被误存入 NSE 字段

- **位置**：`frontend/lib/update_logic.mbt:81-91`
- **描述**：`CalibrationCompleted(result)` 中 `calib_metric` 硬编码为 `"nse"`，`calib_value` 和 `nse` 均设为 `result.best_metric`。但 `CalibResult` 的 `best_metric` 取决于率定配置的 `target_metric`（可为 `"nse"` 或 `"kge"`）。若用户以 KGE 为目标率定，`best_metric` 实为 KGE 值，却同时写入 `nse` 字段和 `calib_metric="nse"`，造成指标名与值的双重错标。根因之一是 `CalibResult` 未携带 `target_metric` 信息。
- **建议**：① 在 `CalibResult`（shared 层）中增加 `metric_name : String` 字段；② `update` 中 `calib_metric: result.metric_name`，并按 `metric_name` 分别写入 `nse` 或 `kge` 字段。

---

#### [一般] StartCalibration 携带的算法名被 update 丢弃，DDS 与 SCE-UA 选择无效

- **位置**：`frontend/lib/update_logic.mbt:74-79`、`frontend/lib/msg_enum.mbt:24`、`frontend/lib/view_layout.mbt:150-153`
- **描述**：`Msg::StartCalibration(String)` 携带算法名（`"dds"` 或 `"sceua"`），view 中两个按钮分别发送 `StartCalibration("dds")` 和 `StartCalibration("sceua")`。但 `update` 以 `StartCalibration(_algo)` 忽略该参数，仅设置 `loading: true`。用户在 UI 上选择 DDS 或 SCE-UA 实际无任何区别，算法选择信息丢失。后续 Effect 也无法从 Model 得知应启动哪个算法。
- **建议**：在 `SimResultState` 或 `AppModel` 中增加 `pending_calib_algo : String` 字段，`update` 中保存 `_algo`，供 Effect 层读取。

---

#### [一般] cli_wbtest 对 validate/batch/ensemble/swe/coupling 子命令缺少 success 断言

- **位置**：`backend/cli_wbtest.mbt:26-67`
- **描述**：`cli_validate`/`cli_batch`/`cli_ensemble`/`cli_swe`/`cli_coupling` 五个子命令的测试仅断言 `result.command`，未断言 `result.success`。若这些命令返回 `success: false`（如 SWE 仿真不稳定、批量仿真有失败任务），测试仍通过。对比同文件中 `cli_sim`/`cli_calibrate` 等均有 `assert_true(result.success)`，断言不一致。
- **建议**：为这五个测试补充 `assert_true(result.success)`（或对预期可能失败的命令断言具体失败原因）。

---

#### [一般] generate_id 使用全局可变 Ref 计数器，测试顺序依赖且非并发安全

- **位置**：`persistence/store.mbt:200-206`、`store_test.mbt:214-216`
- **描述**：`let id_counter : Ref[UInt64] = { val: 0UL }` 是包级全局可变状态，`generate_id` 每次调用递增该计数器。问题：① 测试 `"generate_id ID生成"` 仅断言 `id.contains("scheme_1723000000")` 而非完整 ID，正因为计数器值取决于该测试前的所有 `generate_id` 调用次数（含 `cli_persistence` 等），测试间存在隐式顺序耦合；② 多协程并发调用 `generate_id` 存在计数器竞争（非原子递增）。③ 计数器在进程生命周期内单调增长，虽 UInt64 实际不会溢出，但语义上 `generate_id` 不是纯函数。
- **建议**：将计数器移入 `DataStore` 或专用 `IdGenerator` 结构体，由调用方持有实例；或改用 `timestamp + 随机后缀` 消除全局状态。

---

#### [一般] view 渲染层无 HTML 转义机制，未来接入 HTML/DOM 渲染器存在 XSS 风险

- **位置**：`frontend/lib/view_layout.mbt:225-298`（view_to_text/render_text）、`view_layout.mbt:1-6`（注释）
- **描述**：当前 `view_to_text` 输出纯文本，`VText(text)`/`VLabel(label, value)`/`VError(msg)` 等直接将字符串插入输出，无转义。文件头注释明确"后续接入 Rui 时可将 ViewNode 转换为 Rui 组件树"。当 ViewNode 被转换为 HTML 时，若 `error_message`、`basin_name`、历史记录的 `action` 等用户可控字符串包含 `<script>` 标签，且未来渲染器不做转义，即产生 XSS。当前架构中 ViewNode 携带原始字符串、无转义职责划分，未为此做铺垫。
- **建议**：在 ViewNode 或渲染层明确转义职责：① 文本类节点（VText/VLabel/VError）在 HTML 渲染时对内容做 HTML 实体转义；② 或引入 `VHtml(String)` 专用原始 HTML 节点，其余一律转义。在当前文本渲染器中可先加注释标注转义契约。

---

#### [轻微] load_param_set 冗余 match，与 load_scheme 风格不一致

- **位置**：`persistence/store.mbt:148-156`
- **描述**：`load_param_set` 中 `match self.param_sets.get(id) { Some(p) => Some(p); None => None }` 恒等于 `self.param_sets.get(id)`。同文件 `load_scheme`（line 78-83）直接返回 `self.schemes.get(id)`，风格不一致。
- **建议**：简化为 `self.param_sets.get(id)`。

---

#### [轻微] list_schemes / list_param_sets / list_all_results 用命令式 push 循环，未利用函数式 API

- **位置**：`persistence/store.mbt:87-93`、`store.mbt:129-135`、`store.mbt:160-166`
- **描述**：三个方法均以 `let arr = []; for ... { arr.push(...) }` 构建，可分别用 `self.schemes.keys().to_array()`、`self.results`（或 `.copy()`）等更简洁的惯用写法替代。`list_all_results` 实质是 `self.results` 的浅拷贝，可直接返回。
- **建议**：采用 `Map::keys()` 等标准库 API 简化。

---

#### [轻微] delete_scheme / delete_param_set 先 contains 后 remove，双次哈希查找

- **位置**：`persistence/store.mbt:97-104`、`store.mbt:170-177`
- **描述**：`if self.schemes.contains(id) { ignore(self.schemes.remove(id)); true } else { false }` 对同一键做两次 Map 查找。`remove` 本身可返回 `Option` 指示是否存在。
- **建议**：改为 `match self.schemes.remove(id) { Some(_) => true; None => false }`，单次查找。

---

#### [轻微] read_file 存在 TOCTOU 竞态：file_exists 与 read_file 之间文件可能被删除

- **位置**：`persistence/file_io.mbt:65-74`
- **描述**：`read_file` 先调 `hydro_file_exists` 确认存在，再调 `hydro_read_file` 读取。两步之间文件可能被其他进程删除，此时 `hydro_read_file` 返回空字节，`@utf8.decode` 得到 `""`，函数返回空串而非抛出 `FileNotFound`。当前单进程 CLI 场景下实际风险极低。
- **建议**：合并为单次 C 调用，由 C 侧同时区分"不存在"与"空文件"并返回状态码；或在 MoonBit 侧对 `hydro_read_file` 返回空字节且 exists 为 false 的情况补判。

---

#### [轻微] repeat_str 用循环字符串拼接，O(n²) 拷贝

- **位置**：`backend/cli.mbt:19-25`
- **描述**：`for _ in 0..<n { result = result + s }` 每次迭代创建新 String，总拷贝 O(n²)。同项目 `view_layout.mbt:234` 已用 `String::make` 做同类操作。当前 n≤50 影响可忽略。
- **建议**：改用 `StringBuilder` 或对单字符场景用 `String::make`。

---

#### [轻微] cli_swe 中 set_block 调用用 ignore 吞掉返回值，潜在越界被静默

- **位置**：`backend/cli.mbt:356`
- **描述**：`ignore(grid2d.set_block(i0=0, i1=10, j0=0, j1=20, h_value=2.0))`，网格为 20×20，`j1=20` 是否越界取决于 `set_block` 的索引语义（含/排他）。`ignore` 使任何越界错误被静默忽略，若 dam-break 未实际设置则 2D 仿真结果失真但不报错。
- **建议**：移除 `ignore`，对返回值做断言或日志；确认 `set_block` 索引语义后修正 `j1`。

---

#### [轻微] JSON 预览截断 request_json[0:100] 按字节切片，可能切断多字节 UTF-8 字符

- **位置**：`backend/cli.mbt:489-498`、`cli.mbt:611-615`
- **描述**：`request_json[0:100].to_owned() + "..."` 对 String 按字节偏移切片。若第 100 字节落在多字节 UTF-8 序列中间，切片产生无效 UTF-8 字符串。当前 JSON 内容以 ASCII 键名+数值为主，实际触发概率低，但模式不安全。
- **建议**：实现按字符数截断的辅助函数，或使用 `StringBuilder` 逐字符追加至目标长度。

---

#### [轻微] RunEvaluation / RunBatchSim 命名误导：携带的数据被 update 丢弃

- **位置**：`frontend/lib/update_logic.mbt:100-105`、`update_logic.mbt:119-120`
- **描述**：`RunEvaluation(obs, sim)` 和 `RunBatchSim(tasks)` 携带观测/任务数据，但 update 以 `_obs, _sim` / `_tasks` 忽略，仅设 `loading: true`。与 `StartCalibration` 的 `Start` 前缀语义不同，`Run` 前缀暗示会执行计算，实际为 no-op（仅状态翻转）。调用方若期望发送数据即触发计算会被误导。
- **建议**：重命名为 `StartEvaluation`/`StartBatchSim`，或保留数据到 Model 供 Effect 层使用。

---

#### [轻微] SimulationCompleted 清空 calib_metric/calib_value/batch_summary，仿真完成隐式重置率定与批量状态

- **位置**：`frontend/lib/update_logic.mbt:48-64`
- **描述**：`SimulationCompleted` 将 `calib_metric: ""`, `calib_value: 0.0`, `batch_summary: ""` 重置。用户先率定再仿真的常见流程中，仿真完成后率定结果从 UI 消失，可能令人困惑。`has_result: true` 与被清空的率定字段并存也使状态语义不清晰。
- **建议**：保留 `calib_metric`/`calib_value`/`batch_summary`，仅更新仿真相关字段；或明确文档说明仿真完成会重置率定/批量展示。

---

#### [轻微] SimulationCompleted 中 peak_flow 初始为 0.0，空 runoff_series 时 has_result=true 但 peak_flow=0.0

- **位置**：`frontend/lib/update_logic.mbt:40-47`
- **描述**：`run_impl` 对空 forcings 返回空 `runoff_series`（见 `shared/xaj_core.mbt:234`）。`SimulationCompleted` 以 `peak_flow = 0.0` 起始遍历，空序列时 `peak_flow=0.0, peak_time=0, has_result=true`。物理上径流非负，0.0 作为下界合理，但 `has_result=true` 配合空序列语义上不精确。
- **建议**：对空 `runoff_series` 设 `has_result: false` 或 `peak_flow` 设为 `Double::nan`/可选值。

---

#### [轻微] AppModel 同时 derive(Default) 与手写 default()，语义冗余

- **位置**：`frontend/lib/tea_arch.mbt:23`（derive 含 Default）、`tea_arch.mbt:131-170`（手写 default）
- **描述**：`AppModel` 标注 `derive(Debug, ToJson, FromJson, Default)` 同时手写 `pub fn AppModel::default()`。手写实现覆盖 derive 生成版本，但 `derive(Default)` 仍为各字段生成 Default 调用，造成冗余。同文件 `Page`/`ChartType` 仅手写 Default 不 derive，模式不统一。
- **建议**：从 `AppModel` 的 derive 列表移除 `Default`，仅保留手写实现。

---

#### [轻微] pkg.generated.mbti 中 SimResultState 缺失 calib_metric/calib_value/batch_summary 字段，生成文件过期

- **位置**：`frontend/lib/pkg.generated.mbti:109-118`
- **描述**：源码 `tea_arch.mbt:37-49` 中 `SimResultState` 含 `calib_metric`/`calib_value`/`batch_summary` 三个字段，但 `pkg.generated.mbti`（自动生成、标记 DON'T EDIT）中 `SimResultState` 仅列出 8 个字段，缺失上述三个。说明 `moon info` 未在源码修改后重新运行，生成文件与源码不同步。
- **建议**：重新执行 `moon info` 刷新 `.mbti` 文件，保持构建产物与源码一致。

---

#### [轻微] VTable 渲染未转义单元格中的 "|"，破坏 Markdown 表格格式

- **位置**：`frontend/lib/view_layout.mbt:264-285`
- **描述**：`render_text` 对 `VTable` 以 `|` 分隔列，但单元格内容若含 `|`（如 `basin_name` 含竖线），会破坏表格列对齐。当前数据源无 `|`，实际不触发。
- **建议**：渲染时将单元格内 `|` 替换为 `\|` 或 `｜`。

---

#### [轻微] VHeading 未校验 level，level ≤ 0 时产生无 "#" 前缀的异常输出

- **位置**：`frontend/lib/view_layout.mbt:259-262`
- **描述**：`String::make(level, '#')` 对 `level ≤ 0` 产生空串，输出如 `" text"` 无标题标记。`VHeading` 构造处也未约束 level 范围。
- **建议**：clamp `level` 到 `[1, 6]` 或在构造时断言。

---

#### [轻微] slim_run 固定使用默认新安江参数，前端无法做参数 what-if 试算

- **位置**：`frontend/lib/wasm_slim_model.mbt:55-59`
- **描述**：`slim_run` 硬编码 `@shared.XinanjiangParams::default()`，`SlimSimRequest` 不含参数字段。前端浏览器内试算无法调整参数，限制了交互能力。注释说明"使用默认新安江参数"属设计意图，但与前端"参数面板"UI 的交互能力不匹配。
- **建议**：在 `SlimSimRequest` 增加可选 `params : XinanjiangParams?` 字段，默认 None 时用 default。

---

#### [轻微] slim_json_endpoint 将异常 e.to_string() 直接写入响应，可能泄露内部信息

- **位置**：`frontend/lib/wasm_slim_model.mbt:83-103`
- **描述**：`catch { e => { ... error: e.to_string() ... } }` 将原始异常字符串作为 JSON 响应返回浏览器。若异常含内部路径、类型名或调试信息，构成信息泄露。当前异常主要为 JSON 解析错误，风险低。
- **建议**：对外返回通用错误消息（如"请求格式无效"），在服务端日志记录详细异常。

---

#### [轻微] load_basin_config 对未知流域名静默回退到合成基准，不报错

- **位置**：`frontend/lib/wasm_slim_model.mbt:143-157`
- **描述**：`match name { ... _ => @shared.synthetic_benchmark_case() }` 对未知流域名返回合成基准配置，不提示用户。`wasm_slim_test.mbt:101-103` 将此行为作为预期测试。用户拼错流域名会得到默认配置而无感知。
- **建议**：返回 `SimConfig?` 或在配置中标注 `is_default_fallback: Bool`，由 UI 提示。

---

#### [轻微] cli_persistence 使用 @env.now() 引入非确定性，阻碍可重复测试

- **位置**：`backend/cli.mbt:548`
- **描述**：`let now = @env.now()` 使 `cli_persistence` 每次运行产生不同时间戳和 ID，结果不可重复。`cli_wbtest.mbt:98-102` 仅断言 `success` 和 `command`，无法验证具体数据。
- **建议**：演示命令接受可选 `timestamp` 参数，测试时传入固定值。

---

#### [轻微] cli_auth / cli_ai_forecast / cli_gis / cli_flood 测试向 stdout 大量打印，污染测试输出

- **位置**：`backend/cli_wbtest.mbt:135-160`
- **描述**：这四个测试调用对应子命令，函数内部大量 `println`，测试运行时向 stdout 输出演示文本，混入测试结果输出。
- **建议**：演示类命令将输出存入 `details` 字段（见前述一般问题），测试通过断言 `details` 内容验证，避免 stdout 污染。

---

#### [轻微] Msg 未 derive Eq，无法比较消息相等性

- **位置**：`frontend/lib/msg_enum.mbt:9`（derive 仅 Debug, ToJson, FromJson）
- **描述**：`Msg` 无 `Eq` derive，无法用 `assert_eq` 比较两个 `Msg` 值。测试中验证 `VButton` 携带的 `Msg` 时需逐字段手动比对。`Page`/`ChartType` 已 derive `Eq`，`Msg` 未跟上。
- **建议**：为 `Msg` 添加 `Eq` derive（需确保 `@shared.XinanjiangParams` 等成员类型也支持 Eq，否则保持现状并文档说明）。

---

### 本轮统计

| 严重程度 | 数量 |
|---------|------|
| 严重 | 3 |
| 一般 | 15 |
| 轻微 | 20 |

### 总评

三个模块整体架构清晰、分层合理：persistence 层以 DataStore + JSON 序列化 + C FFI 文件 I/O 分层，backend 层 20 个子命令结构化返回 CliResult，frontend 层 TEA 架构 Model/Msg/Update/View 纯函数式分离到位，wasm_slim_model 与 shared 层共享同一算法内核（有结果一致性测试保障）。测试覆盖面较广，TEA 测试尤其全面。C FFI 侧（fileio.c）的缓冲区溢出防护（1GB 上限、INT32_MAX 检查、负长度拦截）和资源管理（fclose 返回值检查）已相当扎实，值得肯定。

主要风险集中在三处：① **persistence 安全边界**——`validate_path` 用 `abort` 而非 `raise`、`file_exists` 绕过校验、未拦截绝对路径，三者叠加使路径遍历防护既不完整又不可恢复（3 个严重）；② **DataStore 并发与结果管理**——无并发保护、`save_result` 不去重且无删除接口；③ **frontend TEA 语义错标**——`CalibrationCompleted` 硬编码 "nse" 将 KGE 误存入 NSE 字段、`StartCalibration` 算法名被丢弃，二者配合使率定流程的指标与算法选择均失真。

backend 层的 `cli_metrics`（sim=obs 恒完美）和四个演示命令的 println 侧输出问题影响演示质量与可测试性，但不影响核心算法。前端 view 层当前文本渲染无 XSS 风险，但需在接入 HTML 渲染器前建立转义契约。`pkg.generated.mbti` 过期反映构建产物未同步，建议补充 CI 中 `moon info` 一致性检查。
