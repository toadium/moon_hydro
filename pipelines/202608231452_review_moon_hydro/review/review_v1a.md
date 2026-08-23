# R1a: shared/ 核心算法模块审查（model / xaj_core / swe_core / swe2d / coupling）

审查时间：2026-08-23

### 审查范围

- `shared/model.mbt`（核心数据模型/结构体定义）
- `shared/xaj_core.mbt`（新安江演算内核）
- `shared/swe_core.mbt`（1D 浅水方程求解器）
- `shared/swe2d.mbt`（2D 浅水方程求解器）
- `shared/coupling.mbt`（新安江+SWE 耦合）
- `shared/xaj_core_test.mbt`
- `shared/swe_core_test.mbt`
- `shared/swe2d_test.mbt`
- `shared/coupling_test.mbt`
- 参照：`shared/hydro_trait.mbt`（HydroModel trait 定义）

### 发现

#### [严重] 新安江模型水量平衡双计——净雨量 PE 被重复加入张力水蓄量

- **位置**：`shared/xaj_core.mbt:65`、`shared/xaj_core.mbt:77`、`shared/xaj_core.mbt:104`、`shared/xaj_core.mbt:119`、`shared/xaj_core.mbt:215-217`、`shared/xaj_core.mbt:242-244`
- **描述**：
  `compute_evaporation` 在第 65 行将降雨 P 加入上层蓄量（`state.wu = wu + p - eu`），第 77 行汇总 `state.w = state.wu + state.wl + state.wd`，因此蒸发后 `state.w = W_初始 + P - E`。
  随后 `step_impl`（第 216 行）计算 `pe = p - state.e`，`compute_runoff`（第 119 行）执行 `state.w = w_safe + pe - r`，将 PE 再次加入 W。
  最终结果为 `state.w = W_初始 + 2*(P-E) - R`，而正确的水量平衡应为 `state.w = W_初始 + (P-E) - R`。净雨量 PE 被双重计入。
  同时，`compute_runoff` 第 104 行使用膨胀后的 `w_safe`（已含 P-E）计算蓄水容量分布参数 `a`，导致产流量 R 的计算也基于错误的 W 值。
  数值验证：W=0, P=50, E=2 → 蒸发后 W'=48, PE=48 → 代码给出 W_final≈65.02, R≈30.98；正确值应为 W_final≈17.02, R≈21.0。
  该错误在 `step_impl` 和 `run_impl` 中均存在。
- **建议**：
  在 `step_impl`/`run_impl` 中蒸发前保存 `let w_prev = state.w`，将 `w_prev` 传入 `compute_runoff` 作为产流公式中的 W（而非使用蒸发后的 `state.w`），并更新 `state.w = w_prev + pe - r`。或改为在 `compute_evaporation` 中不将 P 加入 WU（仅扣减蒸发 E），然后在 `compute_runoff` 中执行 `state.w = w_safe + pe - r`。

#### [严重] 三水源划分公式错误——fr=1.0 时全部产流退化为地表径流，壤中流/地下径流失去补给

- **位置**：`shared/xaj_core.mbt:159`
- **描述**：
  当前公式 `rs = r * (fr + (1.0 - fr) * @math.pow(s_ratio_safe, ex))`，默认 `fr = 1.0`（`model.mbt:108`）代入得 `rs = r`，即全部产流恒为地表径流。
  自由水蓄量更新（第 167 行）`state.s = s + r - rs - ri - rg = s + r - r - ki*s*fr - kg*s*fr = s*(1 - ki - kg)`，自由水蓄量仅靠消退系数衰减、永不被产流补给。默认 ki=0.3、kg=0.35 时每步衰减因子 0.35，约 10 步后 s→0，壤中流和地下径流归零。
  标准新安江三水源划分公式为 `rs = r * (1 - (1 - S/SM)^EX)`：当 S/SM=0（干燥）时 RS=0，产流全部补充自由水；当 S/SM=1（饱和）时 RS=R，全部为地表径流。当前公式行为与标准完全相反。
- **建议**：
  将公式改为 `rs = r * (1.0 - @math.pow(1.0 - s_ratio_safe, ex))`（或含不透水面积修正，见下一个问题）。同时需将不透水面积产流 `r_im` 直接归入 RS 而不参与自由水分配。

#### [严重] 不透水面积产流被纳入自由水分配——水源划分未区分不透水/透水面积

- **位置**：`shared/xaj_core.mbt:116-118`、`shared/xaj_core.mbt:159`
- **描述**：
  `compute_runoff` 第 116-118 行将产流拆分为不透水部分 `r_im = im * pe` 和透水部分 `r_b = (1-im) * r`，合并为 `r = r_im + r_b` 后存入 `state.r`。`compute_source_split` 接收的 `r` 是合并值，在水源划分公式中对整体 `r` 应用自由水容量曲线分配。不透水面积产流应直接成为地表径流，不经过自由水蓄量分配。当前因公式 bug（rs=r）恰好全部归入 RS，掩盖了此问题；一旦修正公式，不透水产流将被错误地分配到自由水/壤中流/地下径流。
- **建议**：
  将 `r_im` 和 `r_b` 分别传入 `compute_source_split`，RS = r_im + r_b * (1 - (1 - S/SM)^EX)，自由水补给仅为 r_b * (1 - S/SM)^EX。

#### [一般] 深层蒸散发未检查负值——ed 可能为负导致深层蓄量异常增加

- **位置**：`shared/xaj_core.mbt:59-62`
- **描述**：
  第 59 行 `ed = c * (em - eu) - el`，其中 `el = wl`（第 58 行）。当 `c * (em - eu) < wl` 时 `ed < 0`，此时第 73 行 `state.wd = wd - ed` 会使深层蓄量增加（蒸发反而补水），物理上不合理。代码仅检查了 `ed > wd`（第 60-62 行）的上界，缺少 `ed < 0` 的下界保护。
- **建议**：
  在第 59 行后增加 `if ed < 0.0 { ed = 0.0 }`，或调整 `el` 使 `ed` 非负。

#### [一般] SWE 1D run 检测到不稳定后不提前终止——继续推进浪费算力且加剧发散

- **位置**：`shared/swe_core.mbt:268-307`
- **描述**：
  `run` 函数在每步记录状态时检测稳定性（第 299 行 `stable = false`），但循环不 break，继续推进剩余步数。对比 `swe2d.mbt:429-431` 的 2D 版本在 `!stable` 时 break，1D 版本缺少此优化。
- **建议**：
  在稳定性检测后添加 `if !stable { break }`。

#### [一般] coupling_run 检测到不稳定后不提前终止

- **位置**：`shared/coupling.mbt:259-262`、`shared/coupling.mbt:230-283`
- **描述**：
  `couple_run` 在第 259-261 行检测 SWE 水深越界并置 `stable = false`，但循环不 break，继续执行后续耦合步。
- **建议**：
  在稳定性检测后添加 `if !stable { break }`。

#### [一般] SWE 2D set_block/set_elevation 就地修改输入网格——与 step_lf 不可变风格不一致

- **位置**：`shared/swe2d.mbt:463`、`shared/swe2d.mbt:484`
- **描述**：
  `set_block`（第 463 行 `self.h[idx2d(i, j, ny)] = h_value`）和 `set_elevation`（第 484 行）直接修改传入网格的数组并返回 `self`。而 `step_lf` 采用不可变模式返回新网格。两种风格混用容易导致调用方误用——若调用方期望返回副本而保留原始网格，实际原始网格已被修改。
- **建议**：
  统一为不可变风格：在函数内部复制数组后修改副本并返回新网格；或在文档注释中明确标注"就地修改"语义。

#### [一般] apply_boundary 未处理 nx < 2 的小网格——数组越界风险

- **位置**：`shared/swe_core.mbt:149-176`
- **描述**：
  `apply_boundary` 在左边界（第 151 行 `h[0] = h[1]`）和右边界（第 166 行 `h[nx-1] = h[nx-2]`）访问相邻单元。当 `nx = 1` 时，`h[1]` 越界；`nx = 0` 时所有访问越界。`step_lf` 虽然在循环范围上对小网格有自然保护（`n_faces = nx-1` 可能为 0），但 `apply_boundary` 始终被调用。
- **建议**：
  在 `apply_boundary` 开头添加 `if nx < 2 { return grid }` 或返回网格副本的守卫。

#### [一般] apply_water_level_feedback 无上界钳制——wd/s 可超出容量上限

- **位置**：`shared/coupling.mbt:124-133`
- **描述**：
  第 124 行 `xaj_state.wd = xaj_state.wd + feedback` 和第 128 行 `xaj_state.s = xaj_state.s + feedback * 0.5` 仅做了下界保护（第 125-127、129-131 行 `< 0.0` 钳制），未做上界钳制。当河道水深远大于阈值时，正反馈可使 `wd` 超过 `wdm`、`s` 超过 `sm`，后续 `compute_source_split` 虽有钳制但 `compute_evaporation` 使用未钳制的 `wd` 可能产生异常蒸发量。
- **建议**：
  添加上界钳制：`if xaj_state.wd > params.wdm { xaj_state.wd = params.wdm }` 和 `if xaj_state.s > params.sm { xaj_state.s = params.sm }`。需将 params 传入或在调用方处理。

#### [一般] couple_step 就地修改输入 xaj_state——调用方状态被隐式修改

- **位置**：`shared/coupling.mbt:156`
- **描述**：
  `couple_step` 调用 `xaj_model.step(forcing, xaj_state)`（第 156 行），`step_impl` 直接在传入的 `state` 上修改并返回。因此 `couple_step` 的调用方传入的 `xaj_state` 被就地修改。函数签名暗示返回新状态（返回元组含 `XinanjiangState`），但实际输入也被改变，违反最小意外原则。对比 SWE 网格的处理（第 160-166 行做了深拷贝），XAJ 状态未做隔离。
- **建议**：
  在 `couple_step` 中对 `xaj_state` 做深拷贝后再传入 `step`，或在文档注释中明确标注"就地修改 xaj_state"。

#### [一般] 耦合 SWE 子步使用固定 swe_dt——未做 CFL 自适应检查

- **位置**：`shared/coupling.mbt:170-183`
- **描述**：
  `couple_step` 第 181-183 行以固定 `swe_dt` 推进 SWE 子步循环，未调用 `SWEGrid1D::max_stable_dt` 或在子步内做 CFL 检查。当侧向入流注入后局部水深增大、波速增大，固定 `swe_dt` 可能违反 CFL 条件导致数值发散。代码注释（第 144 行）已标注此限制。
- **建议**：
  在每个子步前计算 `dt_cfl = current_swe.max_stable_dt(cfl=0.5)`，取 `min(swe_dt, dt_cfl)` 作为实际步长；或在 `couple_run` 层面做 CFL 预检查并调整 `swe_dt`。

#### [一般] XAJ 核心测试缺少精确值验证和水量平衡检验——无法捕获算法回归

- **位置**：`shared/xaj_core_test.mbt`（全文）
- **描述**：
  现有测试以 `assert_true(new_state.r >= 0.0)` / `assert_true(new_state.q >= 0.0)` 等非负断言为主（第 71-72、78、94-96、115 行），缺少：(1) 已知输入的精确输出值验证；(2) 水量平衡检验 `W_final + R == W_initial + P - E`；(3) 水源划分守恒 `RS + RI + RG == R`；(4) 退水过程单调递减验证。"退水过程"测试（第 100-118 行）仅检查 `runoff_series[0] >= 0.0`，未验证退水特性。上述严重 bug（水量平衡双计、水源划分公式错误）均未被现有测试捕获。
- **建议**：
  补充：(1) 单步精确值测试（固定参数/输入，inspect 输出数值）；(2) 水量平衡断言 `|W_final + sum(R) - W_initial - sum(P-E)| < epsilon`；(3) 水源划分守恒断言；(4) 退水过程 `runoff_series[t] >= runoff_series[t+1]` for t in 退水段。

#### [轻微] SWE 1D 负水深保护注释与实现不符

- **位置**：`shared/swe_core.mbt:238-248`
- **描述**：
  注释（第 238 行）称"按比例缩放动量保持守恒"，但 `h_clamped = 0.0`（第 240 行），缩放因子 `h_clamped / h_old = 0.0`，动量被置零而非按比例保留。实际行为是丢弃动量，注释有误导性。
- **建议**：
  修正注释为"负水深时置零水深和动量"，或改用正值钳制（如 `h_clamped = 1e-6`）以保留动量比例。

#### [轻微] SWE 2D 负水深保护策略与 1D 不一致

- **位置**：`shared/swe2d.mbt:359-363`
- **描述**：
  2D 版本直接置零 `h_new[k] = 0.0; hu_new[k] = 0.0; hv_new[k] = 0.0`（第 360-362 行），1D 版本尝试按比例缩放（虽实际也置零）。两处实现策略不统一，增加维护成本。
- **建议**：
  统一 1D/2D 负水深处理策略，提取为共用函数或保持一致逻辑。

#### [轻微] 负蒸发能力无保护——em < 0 时产生负蒸散发

- **位置**：`shared/xaj_core.mbt:44`
- **描述**：
  `compute_evaporation` 未对 `em < 0.0` 做守卫。当 `em < 0` 时，`p + wu >= em` 恒真（第 44 行），`eu = em < 0`，导致 `state.wu = wu + p - eu > wu + p`，蒸发反而增加蓄量。
- **建议**：
  在函数开头添加 `let em = if em < 0.0 { 0.0 } else { em }`。

#### [轻微] 蓄水容量曲线指数 b = -1 无保护——除零风险

- **位置**：`shared/xaj_core.mbt:104`、`shared/xaj_core.mbt:109`
- **描述**：
  第 104 行 `1.0 / (1.0 + b)` 和第 109 行同表达式，当 `b = -1.0` 时除零。`b` 典型值 0.0-0.5，但参数来自外部配置无约束。
- **建议**：
  添加 `if b <= -1.0` 守卫返回 0 或报错，或在参数校验阶段拦截。

#### [轻微] SWE 2D 维度分裂仅一阶精度——可用 Strang 分裂提升精度

- **位置**：`shared/swe2d.mbt:273-325`
- **描述**：
  `step_lf` 先 x 方向全步推进（第 275-292 行），再 y 方向全步推进（第 313-325 行），为一阶 Strang 分裂，时间精度 O(dt)。二阶 Strang 分裂（x(dt/2) → y(dt) → x(dt/2)）可将时间精度提升至 O(dt²)。
- **建议**：
  如需更高精度，改为二阶 Strang 分裂；当前一阶对显式格式整体 O(dt, dx²) 影响有限，可标注为已知限制。

#### [轻微] inject_lateral_inflow 硬编码单元宽度 1m

- **位置**：`shared/coupling.mbt:103`
- **描述**：
  第 103 行 `dh = inflow_per_cell * dt / swe_grid.dx`，注释说明"假设单元宽度1m"。实际 1D SWE 网格的单元宽度（垂直于流向方向）未参数化，当实际河道宽度非 1m 时水深增量计算有误。
- **建议**：
  在 `CouplingParams` 中增加 `cell_width` 字段，或从 `SWEGrid1D` 获取实际宽度。

#### [轻微] couple_step 返回四元组可读性差

- **位置**：`shared/coupling.mbt:154`、`shared/coupling.mbt:206`
- **描述**：
  返回 `(XinanjiangState, SWEGrid1D, Double, Double)` 四元组，调用方需按位置解构（如 `coupling_test.mbt:38`），语义不明确。代码注释（第 145 行）已标注此问题（P3-7）。
- **建议**：
  定义 `CouplingStepResult` 结构体包含 `xaj_state`/`swe_grid`/`lateral_inflow`/`river_level` 命名字段。

#### [轻微] couple_run 手动逐字段复制 XAJ 状态——冗长且易遗漏

- **位置**：`shared/coupling.mbt:268-282`
- **描述**：
  第 268-282 行逐字段复制 `new_xaj` 到 `xaj_state`（13 个字段），若 `XinanjiangState` 新增字段此处需同步修改，易遗漏。类似复制在第 237-252 行也存在。
- **建议**：
  为 `XinanjiangState` 提供 `copy_from(other)` 方法或使用结构体展开 `{ ..new_xaj }` 语法。

#### [轻微] XinanjiangParams 同时 derive(Default) 和手动 default()——语义冲突

- **位置**：`shared/model.mbt:37`、`shared/model.mbt:87`
- **描述**：
  `XinanjiangParams` 标注 `derive(Debug, ToJson, FromJson, Default)`（第 37 行），同时手写 `pub fn XinanjiangParams::default()`（第 87 行）提供有意义的默认值。`derive(Default)` 生成的默认值全零（wm=0, b=0 等），与手写版本语义不同。若调用方通过 trait 约束使用 Default 而非直接调用 `default()`，可能获得无效的全零参数。`CouplingParams`（`coupling.mbt:18`）有同样模式。
- **建议**：
  移除 `derive(Default)` 中的 `Default`，仅保留手写 `default()`；或确认 MoonBit 手写方法可靠覆盖 derive 生成方法后添加注释说明。

#### [轻微] XAJ 测试断言过弱——仅检查非负无法验证正确性

- **位置**：`shared/xaj_core_test.mbt:71-72`、`shared/xaj_core_test.mbt:78`、`shared/xaj_core_test.mbt:94-96`、`shared/xaj_core_test.mbt:115`
- **描述**：
  多处使用 `assert_true(x >= 0.0)` 断言，仅验证非负性，无法区分正确计算与退化为零的错误实现。例如水源划分 bug 导致 ri/rg 归零后仍满足 `>= 0.0`。
- **建议**：
  对关键输出使用 `inspect` 精确值断言或 `assert_true((x - expected).abs() < epsilon)` 近似断言。

#### [轻微] coupling_test 中 debug_inspect 与 inspect 使用不一致

- **位置**：`shared/coupling_test.mbt:9-12`、`shared/coupling_test.mbt:42`、`shared/coupling_test.mbt:115-117`、`shared/coupling_test.mbt:152`、`shared/coupling_test.mbt:154`
- **描述**：
  `coupling_test.mbt` 使用 `debug_inspect`，而 `xaj_core_test.mbt` 和 `swe_core_test.mbt` 使用 `inspect`。两种断言函数行为可能不同（`debug_inspect` 可能仅在 debug 构建生效），测试一致性受影响。
- **建议**：
  统一使用 `inspect` 或确认 `debug_inspect` 在 release 构建中同样生效后保持现状。

#### [轻微] SWE 1D 稳定性检测在推进前而非推进后——最后一步不稳定未捕获

- **位置**：`shared/swe_core.mbt:290-302`
- **描述**：
  `run` 在每步推进前（第 290-302 行）检测当前状态稳定性，然后推进（第 306 行）。最后一步推进后的状态未做稳定性检测（仅更新 max_depth，第 309-313 行），若最后一步产生发散则 `stable` 仍为 true。
- **建议**：
  在循环结束后对最终 `grid` 做稳定性检测，或将检测移至推进后。

### 本轮统计

| 严重程度 | 数量 |
|---------|------|
| 严重 | 3 |
| 一般 | 9 |
| 轻微 | 11 |

### 总评

shared/ 核心算法模块整体架构清晰、职责划分合理，SWE 求解器（1D/2D）的 Lax-Friedrichs 格式实现规范，CFL 自适应、边界条件处理、负水深保护等数值稳定性措施到位，测试覆盖了静水稳定性、dam-break、边界反射、质量守恒等关键场景。

但新安江模型核心演算存在两个严重正确性缺陷：(1) 水量平衡双计——`compute_evaporation` 已将降雨 P 加入蓄量，`compute_runoff` 再次加入净雨 PE，导致张力水蓄量每步膨胀 PE，产流量计算也基于错误的 W 值；(2) 三水源划分公式错误——默认 `fr=1.0` 时 `rs=r` 恒成立，自由水蓄量永不被产流补给，壤中流和地下径流在约 10 步后归零，模型退化为纯地表径流。两个缺陷均未被现有测试捕获，测试仅用 `>= 0.0` 非负断言，缺少精确值验证和水量平衡检验。建议优先修复上述严重问题并补充回归测试。

耦合模块的数据流基本正确（侧向入流计算、SWE 网格深拷贝隔离、反馈机制），但 SWE 子步未做 CFL 自适应、输入 XAJ 状态被就地修改、不稳定时未提前终止等问题需关注。SWE 求解器数值实现质量较高，仅有小网格越界风险和 1D/2D 负水深处理不一致等轻微问题。
