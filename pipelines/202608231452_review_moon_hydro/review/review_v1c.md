# R1c: shared/ 基础设施模块审查

审查时间：2026-08-23

### 审查范围

生产代码：
- shared/task_scheduler.mbt
- shared/benchmark.mbt
- shared/auth.mbt
- shared/api.mbt
- shared/utils.mbt
- shared/hydro_trait.mbt
- shared/serde_bind.mbt
- shared/test_data.mbt

测试代码：
- shared/task_scheduler_test.mbt
- shared/benchmark_test.mbt
- shared/auth_test.mbt
- shared/api_test.mbt
- shared/utils_test.mbt
- shared/test_data_test.mbt
- shared/robustness_test.mbt

### 发现

#### [严重] bench 函数 n_iters=0 时产生 NaN

- **位置**：`shared/benchmark.mbt:53`
- **描述**：`let mean = sum / n_iters.to_double()` 当 `n_iters=0` 时，`0.0 / 0.0 = NaN`。同时 `min_val` 保持初始值 `999999999.0`（第42行），`max_val` 保持 `0.0`（第43行），三者均不合理。NaN 会通过 `BenchResult` 结构体传播，序列化为 JSON 时产生非法 JSON（`NaN` 不是合法 JSON 值），后续解析会失败。测试未覆盖 `n_iters=0` 边界。
- **建议**：在函数入口添加 `if n_iters <= 0` 的早返回，返回全字段为 `0.0` 的 `BenchResult`；或将 `min_val` 初始化为 `Double::infinity`，并在 `times` 为空时统一返回零值结果。

#### [严重] check_scheme_access 未集成角色权限检查，存在越权风险

- **位置**：`shared/auth.mbt:335-363`
- **描述**：`check_scheme_access` 仅做方案所有权隔离，不检查角色权限。函数注释声明"Viewer只能访问公开方案"，但实际代码中 `ownership.owner_id == user.id` 分支允许任意角色（含 Viewer）读写自己拥有的方案。这与 `role_has_permission(Viewer, SchemeWrite)` 返回 `false` 矛盾。`check_permission` 与 `check_scheme_access` 是两个独立函数，无组合调用入口；`backend/cli.mbt:703` 等处仅调用 `check_scheme_access` 而未先调用 `check_permission`，若调用方遗漏角色检查，Viewer 可绕过角色限制写入自有方案。
- **建议**：提供 `check_scheme_access_full(user, scheme_id, perm, write?)` 组合函数，内部先调 `check_permission` 再调 `check_scheme_access`；或修正注释使其与实现一致，并在文档中明确要求调用方必须同时调用两个检查。

#### [一般] TaskScheduler::add_task 不检查重复 task_id

- **位置**：`shared/task_scheduler.mbt:69-72`
- **描述**：`add_task` 直接 push 到 `tasks` 数组并设置 `status[task_id]`。若添加两个相同 `task_id` 的任务，`tasks` 中有两条记录但 `status` map 仅保留一个键。执行时两个任务都会执行，但 `completed_count()`（第93-101行）通过遍历 `status` map 计数，只计 1 次，导致进度报告 `completed` 与实际执行数不一致。
- **建议**：在 `add_task` 中检查 `self.status.contains(task.task_id)`，若已存在则 raise 或返回错误；或在文档中明确要求 task_id 唯一。

#### [一般] create_task_from_basin 丢弃 observed 数据

- **位置**：`shared/task_scheduler.mbt:238-248`
- **描述**：`BasinCase` 含 `observed : Array[Double]` 字段，但 `create_task_from_basin` 将 `observed` 硬编码为 `[]`，丢弃了流域案例的观测数据。若后续需对任务结果进行评价（NSE/KGE 等），将因缺少观测而无法计算。测试（task_scheduler_test.mbt:158-164）未验证 `observed` 字段。
- **建议**：改为 `observed: case.observed`，或在注释中说明丢弃观测的设计意图。

#### [一般] run_calibrate API 仅支持 DDS，不支持 SCE-UA

- **位置**：`shared/serde_bind.mbt:121-135`、`shared/api.mbt:67-73`
- **描述**：`CalibrateRequest.config` 类型为 `DDSConfig`，`run_calibrate` 硬编码调用 `dds_calibrate`。项目中存在 `sceua_calibrate` 函数，但无法通过 JSON API 调用。用户若需 SCE-UA 率定，必须绕过 API 层直接调用函数。
- **建议**：将 `CalibrateRequest` 改为含 `algorithm : String` 字段和通用配置，或在 API 层增加 `run_sceua_calibrate` 端点与对应请求/响应类型。

#### [一般] AuthManager::register 不验证 username/password 非空

- **位置**：`shared/auth.mbt:191-212`
- **描述**：`register` 仅检查用户名是否已存在，不校验 `username` 和 `password` 是否为空字符串。空用户名和空密码均可注册成功，可能导致后续登录逻辑混乱（空用户名查找语义不清）和安全风险。
- **建议**：在函数入口添加 `if username.length() == 0` 和 `if password.length() == 0` 的校验，raise 对应错误。

#### [一般] AuthManager::register user_id 生成可能复用已删除用户的 ID

- **位置**：`shared/auth.mbt:201`
- **描述**：`user_id = "user_\{timestamp}_\{self.users.length()}"` 使用当前 `users.length()` 作为序号。若用户被 `delete_user` 删除后，`users.length()` 减小，新注册用户在相同 `timestamp` 下可能生成与已删除用户相同的 `user_id`。虽然 `delete_user` 清理了该用户的方案所有权，但外部系统（日志、审计）中残留的旧 user_id 会被误关联到新用户。
- **建议**：引入类似 `token_counter` 的单调递增 `user_counter` 字段用于生成 user_id，避免复用。

#### [一般] verify_password 使用非常量时间字符串比较

- **位置**：`shared/auth.mbt:173`
- **描述**：`hash_with_salt(password, parts[0].to_owned()) == stored` 使用普通字符串相等比较，非常量时间。理论上攻击者可通过测量响应时间推断哈希前缀匹配长度，构成时序攻击。虽然当前哈希为固定格式 UInt64 字符串（时序差异极小），且注释已声明非生产级安全，但作为权限框架仍应遵循最佳实践。
- **建议**：实现常量时间比较函数，逐字节异或累积后判定全零。

#### [一般] JSON 端点无输入大小限制和参数值校验

- **位置**：`shared/serde_bind.mbt:20-51`、`shared/serde_bind.mbt:162-198`
- **描述**：各 `parse_*_request` 和 `*_json_endpoint` 函数直接解析 JSON 并传入模型，无请求体大小限制、无数组长度上限、无参数物理意义校验（如 `area < 0`、`dt <= 0`、`forcings` 超大数组）。恶意构造的超大 JSON 可导致内存耗尽（DoS）；非法参数值虽被模型层容错（见 robustness_test.mbt），但 API 层应作为首道防线显式拒绝。
- **建议**：在 `parse_*` 后增加 `validate_*` 函数校验参数范围与数组长度上限；在 HTTP/CLI 层限制请求体大小。

#### [一般] check_scheme_access 注释与实现不一致

- **位置**：`shared/auth.mbt:332-333`
- **描述**：注释声明"Viewer只能访问公开方案，Engineer只能访问自己的或公开方案"，但实现中 `ownership.owner_id == user.id` 分支对任意角色生效，即 Viewer 也能访问自己拥有的方案。注释与代码的语义差异会误导调用方对安全边界的理解。
- **建议**：若允许所有者访问自有方案为设计意图，则修正注释为"Viewer可读公开方案或访问自有方案"；若不允许 Viewer 拥有方案，则在 `grant_scheme_ownership` 中校验角色。

#### [轻微] TaskScheduler::get_status 冗余 match 表达式

- **位置**：`shared/task_scheduler.mbt:207-215`
- **描述**：`match self.status.get(task_id) { Some(s) => Some(s) None => None }` 等价于直接返回 `self.status.get(task_id)`，match 分支为恒等映射，无任何转换逻辑。
- **建议**：简化为 `pub fn TaskScheduler::get_status(self, task_id) -> TaskStatus? { self.status.get(task_id) }`。

#### [轻微] TaskScheduler::completed_count 每次遍历 status map

- **位置**：`shared/task_scheduler.mbt:93-101`
- **描述**：`completed_count` 和 `progress_report`（第219-234行）每次调用都遍历整个 `status` map 计数。在 `run` 方法中（第181行）每个任务完成后都调用 `completed_count`，总体为 O(n²)。
- **建议**：在 `TaskScheduler` 中维护 `completed_count` 和 `failed_count` 计数器，在状态变更时增量更新。

#### [轻微] bench 函数 min_val 初始值不够健壮

- **位置**：`shared/benchmark.mbt:42`
- **描述**：`min_val` 初始化为 `999999999.0`。若单次迭代耗时超过此值（约 11.6 天），`min_val` 不会被更新，结果错误。虽然实际基准测试不会运行如此之久，但使用 `Double::infinity` 作为初始值更为规范。
- **建议**：将 `min_val` 初始化为正无穷（或首个时间值），避免魔法数字。

#### [轻微] mock_long_term_forcings 硬编码 PI 值

- **位置**：`shared/test_data.mbt:191`
- **描述**：`2.0 * 3.14159265358979 * day.to_double() / 365.0` 硬编码 PI 近似值。同文件第341行 `mock_tidal_wave_grid` 也有相同硬编码。
- **建议**：使用 `@math.pi`（若标准库提供）或定义模块级常量 `let PI = 3.14159265358979`。

#### [轻微] check_permission 未使用 _self 参数

- **位置**：`shared/auth.mbt:309-317`
- **描述**：`check_permission(_self : AuthManager, user : User, perm : Permission)` 的 `_self` 参数完全未使用，函数仅依赖 `user.role`。作为方法绑定在 `AuthManager` 上但不需要实例状态，接口设计冗余。
- **建议**：改为独立函数 `fn check_user_permission(user : User, perm : Permission) -> Unit raise`，或保留方法形式但在文档中说明预留扩展（如未来从 AuthManager 查询用户额外权限）。

#### [轻微] HydroModel trait 绑定 XinanjiangState 限制泛化能力

- **位置**：`shared/hydro_trait.mbt:13-18`
- **描述**：`step` 方法签名绑定 `XinanjiangState` 作为输入输出类型，`run` 绑定 `SimResult`。这使得 LSTM、PINN 等 AI 模型若状态结构不同则无法实现该 trait。注释已说明此为 MoonBit 类型系统限制下的务实选择，并给出了未来泛化方案。
- **建议**：当前可接受。后续可考虑为不同模型族定义独立 trait（HydroXajModel/HydroLstmModel），或引入 ModelState trait 统一状态接口。

### 本轮统计

| 严重程度 | 数量 |
|---------|------|
| 严重 | 2 |
| 一般 | 7 |
| 轻微 | 6 |

### 总评

shared/ 基础设施模块整体设计清晰、职责划分合理，测试覆盖了主要功能路径和边界条件（空数组、长度不匹配、极端工况等），代码质量良好。`utils.mbt` 评价指标函数的除零保护、`test_data.mbt` mock 生成器的边界处理、`auth.mbt` 方案隔离的核心逻辑均实现正确。

主要风险集中在两个方面：（1）`benchmark.mbt` 的 `bench` 函数对 `n_iters=0` 未做防护，产生 NaN 并可能传播至 JSON 序列化；（2）`auth.mbt` 的权限检查体系将角色权限（`check_permission`）与方案所有权（`check_scheme_access`）分离为两个独立函数，无组合入口，且 `check_scheme_access` 注释与实现不一致，调用方遗漏任一检查即构成越权风险。建议优先修复这两个严重问题，并补充 `n_iters=0` 和 Viewer 写自有方案的测试用例。

`serde_bind.mbt` 的 JSON 端点缺少输入大小限制和参数值校验，作为 API 首道防线应加强。`task_scheduler.mbt` 的重复 task_id 和 observed 丢弃问题影响数据正确性，应一并修复。
