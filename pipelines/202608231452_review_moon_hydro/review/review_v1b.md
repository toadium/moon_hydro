# R1b: shared/ 率定、评价、时间序列模块审查

审查时间：2026-08-23

### 审查范围

生产代码：
- shared/sceua.mbt
- shared/calibration.mbt
- shared/evaluation.mbt
- shared/extended_metrics.mbt
- shared/timeseries.mbt
- shared/batch_sim.mbt
- shared/basin_cases.mbt

测试代码：
- shared/sceua_test.mbt
- shared/calibration_test.mbt
- shared/evaluation_test.mbt
- shared/extended_metrics_test.mbt
- shared/timeseries_test.mbt
- shared/batch_sim_test.mbt
- shared/basin_cases_test.mbt

参照上下文：shared/utils.mbt（NSE/KGE/PBIAS/RMSE/R² 定义）、shared/model.mbt（XinanjiangParams/ForcingData 定义）、@splitmix RandomState 接口、@math 常量。

### 发现

#### [严重] DDS 扰动随机索引存在 Int::min 溢出导致负下标崩溃

- **位置**：`shared/calibration.mbt:120`
- **描述**：`dds_perturb` 中使用 `let idx = rng.next_int().abs() % n` 选取扰动参数下标。`@splitmix.RandomState::next_int` 返回 32 位有符号整数，可覆盖全 `Int` 范围。当其返回 `Int::min = -2147483648` 时，`Int::abs` 实现为 `if self < 0 { -self } else { self }`，而 `-(-2147483648)` 在二补码下溢出仍为 `-2147483648`（负值）。随后 `(-2147483648) % n` 在 MoonBit 中保留被除数符号，结果为负，`new_params[idx]` 以负索引访问数组，触发越界 panic。该路径概率为 1/2^32/次调用，在长时率定（max_iter=1000、多参数）下非可忽略，且 `@splitmix` 已提供 `next_positive_int` 专门规避此情况（见 random.mbt:84-92）。
- **建议**：改用 `let idx = rng.next_positive_int() % n`（返回值已保证为正且非零），或 `let idx = (rng.next_uint() % n.to_uint()).to_int()`。

#### [一般] SCE-UA CCE 未随机选取子单纯形，偏离算法规范

- **位置**：`shared/sceua.mbt:206`、`shared/sceua.mbt:238-247`
- **描述**：`cce_evolution` 的 `_rng` 参数未使用（前缀下划线表明已知未用）。标准 SCE-UA（Duan et al. 1992）的 CCE 步骤要求从 complex 中**按概率无放回抽样** `q = dim+1` 个点构成子单纯形，以保证全局搜索的随机性和多样性。当前实现固定取排序后前 `q` 个（最优）点做 Nelder-Mead 进化，使 CCE 退化为确定性局部搜索，削弱了 shuffle 后多 complex 的探索能力，在高维多峰空间下更易陷入局部最优。
- **建议**：在 CCE 每次迭代中，按 SCE-UA 规定的概率 `prob_i = 2(n+1-i)/(n(n+1))` 对 complex 内点无放回抽样 q 个点构造子单纯形；启用 `_rng` 参数。

#### [一般] baseflow_separation 多次滤波未递归作用于上次基流，passes 参数失效

- **位置**：`shared/timeseries.mbt:100-144`
- **描述**：Lyne-Hollick 递归数字滤波的标准多遍做法是：第 k 遍的输入应为第 k-1 遍的**基流**结果，逐遍平滑基流。当前实现中，前向滤波始终用原始 `streamflow` 计算差分（`streamflow[i] - streamflow[i-1]`，第 106 行）与钳制（第 109-117 行），后向滤波亦基于本次前向结果，最后 `baseflow[i] = streamflow[i] - quickflow_b[i]`（第 136 行）。每遍输入完全相同，计算确定性，故 `passes=2` 与 `passes=1` 产出完全一致——`passes` 参数被静默忽略，文档注释"前向/后向滤波次数（通常2-3次）"对用户产生误导。
- **建议**：将每遍前向滤波的输入从 `streamflow` 改为上一遍结束后的 `baseflow`；即第 1 遍用 `streamflow`，第 2 遍起用前一遍的 `baseflow` 数组作为输入序列。

#### [一般] gumbel_return_value 未校验重现期，T≤1 产生 -inf/NaN

- **位置**：`shared/timeseries.mbt:205-213`
- **描述**：`gumbel_return_value` 计算 `mu - beta * ln(-ln(1 - 1/T))`。当 `return_period == 1.0` 时 `1 - 1/T = 0.0`，`ln(0.0) = -inf`，最终返回 `-inf`；当 `return_period < 1.0` 时 `1 - 1/T < 0`，`ln(负数) = NaN`，污染后续计算。函数无任何前置校验，调用方（如设计洪水推算）可能静默得到非有限值。
- **建议**：在函数入口校验 `return_period > 1.0`，否则返回 `NaN` 或以 `Result`/`Option` 显式报错；或在文档明确约束并在调用处防御。

#### [一般] run_sim_task 无错误处理路径，success/error_message 为死字段

- **位置**：`shared/batch_sim.mbt:71-115`、`shared/batch_sim.mbt:121-146`
- **描述**：`run_sim_task` 恒返回 `success: true, error_message: ""`，不存在任何置 `false` 的分支。MoonBit 无异常机制，若 `XinanjiangModel::run` 因参数越界（如 kg+ki>1、cs<0）触发 panic，将直接终止整个批量任务而非记录为失败。`run_batch_sim` 的 `failure_count` 恒为 0，`BatchSimResult` 的失败统计失去意义，用户无法据其识别部分失败。
- **建议**：在 `run_sim_task` 内对模型输入做前置校验（参数物理约束、forcings/observed 长度等），不合法时返回 `success: false` 与具体 `error_message`；或引入 `try`/`catch`（若运行时支持）包裹模型运行。

#### [一般] calibrate_basin_case 忽略 algorithm 参数，恒走 DDS

- **位置**：`shared/basin_cases.mbt:427-447`
- **描述**：`calibrate_basin_case(case, _algorithm? = "dds")` 参数名前缀下划线且函数体内未引用，始终构造 `DDSConfig` 调用 `dds_calibrate`。调用方传入 `algorithm="sceua"` 仍执行 DDS，API 行为与签名契约不一致。
- **建议**：移除该参数（若仅支持 DDS），或根据 `algorithm` 分派到 `dds_calibrate`/`sceua_calibrate`（已有 `sceua_calibrate_basin_case` 可复用）。

#### [一般] 流域校验案例使用模型自身生成的伪观测，reference_nse/kge 误导

- **位置**：`shared/basin_cases.mbt:153-186`、`shared/basin_cases.mbt:190-221`、`shared/basin_cases.mbt:225-254`
- **描述**：三个实测流域案例的 `observed` 均由 `XinanjiangModel::new(params=推荐参数).run(forcings).runoff_series` 生成（第 173-174、208-209、241-242 行），即"伪观测"。随后 `validate_basin_case` 用同一组参数仿真并与该伪观测对比，NSE 必然≈1.0。然而 `reference_nse` 分别填 0.85/0.80/0.82、`reference_kge` 填 0.82/0.78/0.80，这些"文献参考值"从未被任何代码校验或对比，仅作为结构体字段存在。测试 `validate_basin_case 闽江竹岐校验` 断言 `result.nse > 0.7` 因自洽性恒成立，无法真正验证模型对实测流域的预报能力。代码注释（第 151-152 行）已说明此为自洽性验证，但 `reference_*` 字段的存在仍给调用方以"已与文献对比"的假象。
- **建议**：若暂无实测数据，将 `reference_nse`/`reference_kge` 字段移除或重命名为 `synthetic_self_consistency_nse` 并置 1.0；在接入实测数据前，在 `BasinCase` 文档中明确标注数据来源为合成。

#### [一般] persistence_index 分子分母求和范围不一致

- **位置**：`shared/extended_metrics.mbt:194-216`
- **描述**：分子 `sum_sq_err = Σ_{t=0}^{n-1}(obs(t)-sim(t))²`（第 204-207 行，共 n 项），分母 `sum_sq_persist = Σ_{t=1}^{n-1}(obs(t)-obs(t-1))²`（第 208-211 行，共 n-1 项）。标准持续性指数（Persistence Index）定义中分子分母应覆盖相同时段 `t=1..n`（持续性预报 `obs(t-1)` 在 t=0 无定义故从 t=1 起）。当前分子多含 t=0 项 `(obs(0)-sim(0))²`，使 PI 系统性偏低，偏离标准公式。
- **建议**：将分子求和也改为 `for i in 1..<n`，与分母范围对齐；或在文档明确说明采用的是含 t=0 的变体并给出引用。

#### [轻微] gaussian_perturbation 的 Box-Muller 实现引入偏差且浪费第二个样本

- **位置**：`shared/calibration.mbt:80-91`
- **描述**：`u1 = rng.next_double()`（值域 [0,1)），`ln(u1 + 0.00001)` 用 `+0.00001` 规避 `ln(0)`。当 `u1=0` 时 `ln(0.00001)≈-11.51`，产生 `z≈4.8` 的大扰动，且整体分布尾部被截断/偏移，非标准正态。此外 Box-Muller 同时产生两个独立正态样本 `z0=r·cosθ`、`z1=r·sinθ`，当前仅用 cos 分量，sin 分量被丢弃，效率减半。
- **建议**：改用 `u1 = 1.0 - rng.next_double()`（值域 (0,1]）后直接 `ln(u1)`；或采用拒绝采样确保 `u1>0`。可缓存第二个样本供下次调用使用。

#### [轻微] 多处使用 π 字面量而非 @math.PI

- **位置**：`shared/calibration.mbt:89`、`shared/timeseries.mbt:195`
- **描述**：使用 `3.14159265358979`（14 位有效数字），而 `@math.PI`（`0x3.243F6A8885A308CA8A54`）为 Double 满精度常量。Gumbel 参数估计 `beta = std * sqrt(6)/pi` 与 Box-Muller `cos(2*pi*u2)` 均对 π 精度敏感，使用字面量损失约 2 位精度。
- **建议**：替换为 `@math.PI`（注意 `@math.pi` 已 deprecated，应使用大写 `PI`）。

#### [轻微] detect_peaks 不检测首点为洪峰

- **位置**：`shared/timeseries.mbt:66-76`
- **描述**：主循环 `for i in 1..<(n-1)`，末点单独检查（第 74 行），但首点 `i=0` 从未被作为峰检测。若序列开头为全局最大且递减（如 `[50, 30, 10, 5]`），首点洪峰被遗漏。首末点处理不对称。
- **建议**：增加首点检查 `if n >= 2 && series[0] > series[1] && series[0] > threshold { peaks.push(0) }`，或在文档明确"仅检测内部峰"。

#### [轻微] baseflow 前向滤波钳制逻辑冗余且可读性差

- **位置**：`shared/timeseries.mbt:107-120`
- **描述**：先 `quickflow[i] = if q > 0.0 { q } else if q < streamflow[i] { q } else { streamflow[i] }`，再 `if quickflow[i] > streamflow[i] { quickflow[i] = streamflow[i] }`，再 `if quickflow[i] < 0.0 { quickflow[i] = 0.0 }`。三段条件等价于 `clamp(q, 0.0, streamflow[i])`，但嵌套 if-else 与后续重复钳制使逻辑难以一眼确认正确性。
- **建议**：简化为 `quickflow[i] = q.clamp(min=0.0, max=streamflow[i])`（若 `streamflow[i] >= 0`），或显式三段式 `if q < 0.0 { 0.0 } else if q > streamflow[i] { streamflow[i] } else { q }`。

#### [轻微] compute_batch_summary 的 mean_peak_flow 除数应为成功任务数

- **位置**：`shared/batch_sim.mbt:173-176`、`shared/batch_sim.mbt:196`
- **描述**：`peak_flow_sum` 仅对 `r.success` 的任务累加，但 `mean_peak_flow = peak_flow_sum / results.length().to_double()` 用全部任务数做除数。若存在失败任务（当前虽不可能，但 `success` 字段设计暗示未来支持），平均洪峰会被低估。`mean_nse`/`mean_kge`/`mean_pbias` 正确使用 `valid_count`，此处不一致。
- **建议**：改为 `peak_flow_sum / success_count.to_double()`（需在函数内维护 `success_count`，或将成功任务的 peak_flow 统计纳入 `valid_count` 分组）。

#### [轻微] 蒙特卡洛分位数采用整数截断索引，小样本下粗糙

- **位置**：`shared/batch_sim.mbt:371-373`、`shared/batch_sim.mbt:433-434`
- **描述**：`p5 = values[(n * 5 / 100).clamp(...)]`，整数除法 `n*5/100` 截断。如 `n=10` 时 `10*5/100=0`，p5 取最小值；`n=20` 时 `20*5/100=1`。对大样本蒙特卡洛可接受，但测试用 `n_samples=10` 时 p5 实为最小值而非 5% 分位，精度偏低。
- **建议**：采用最近秩法 `ceil(n * p)` 或线性插值；或在文档注明小样本下分位数为近似。

#### [轻微] log_nse 以 0.0 作为无效哨兵值，与"无技巧"NSE=0 语义混淆

- **位置**：`shared/extended_metrics.mbt:21-39`
- **描述**：当 `observed[i] <= 0` 或 `simulated[i] <= 0` 时返回 `0.0`（第 29 行）。NSE=0 在水文评价中意为"与观测均值等效"（有具体物理含义），将无效输入也映射为 0.0 会使调用方无法区分"数据非法"与"模型无技巧"。`evaluate_extended` 直接将该值填入结果结构体，无任何标记。
- **建议**：返回 `NaN` 表示无效（调用方可通过 `is_nan` 判断），或返回 `Option[Double]`/增加 `valid` 标志位。

#### [轻微] volume_relative_error 静默截断不等长序列

- **位置**：`shared/evaluation.mbt:192-212`
- **描述**：当 `observed.length() != simulated.length()` 时，取 `n = min(n_obs, n_sim)` 仅比较重叠前缀（第 201 行），不报错不告警。若模拟序列被意外截断或延长，洪量误差仅基于部分时段计算，结果具误导性。`nse`/`kge`/`rmse` 等在长度不匹配时返回 0.0，本函数行为不一致。
- **建议**：与其它指标统一：长度不匹配时返回 0.0 或 NaN；或要求等长并在不等长时 panic/返回 Result。

#### [轻微] SCE-UA 主循环中 complex 点存在冗余深拷贝

- **位置**：`shared/sceua.mbt:425-431`、`shared/sceua.mbt:215-222`
- **描述**：主循环将 `all_points[k]` 逐元素拷贝到 `complex`（第 425-429 行），随后 `cce_evolution` 内部又对 `complex` 全量拷贝到 `points`（第 215-222 行）。两层深拷贝使每轮迭代多 O(s·dim) 次分配与复制，对 `s=5×(2·11+1)=115`、`dim=11`、`max_iter=1000` 的典型配置有可观的冗余开销。
- **建议**：`cce_evolution` 直接消费传入的 complex（内部排序/替换均为原地操作），或在主循环中传引用避免第一层拷贝。

#### [轻微] 多文件重复数组深拷贝模式，缺少通用辅助

- **位置**：`shared/sceua.mbt:216-221`、`shared/sceua.mbt:425-429`、`shared/sceua.mbt:477-480`、`shared/calibration.mbt:109-117`、`shared/calibration.mbt:269-276`、`shared/calibration.mbt:299-315`
- **描述**：多处以 `let copy : Array[Double] = []; for v in arr { copy.push(v) }` 或对 `CalibParam` 逐字段重建的方式做深拷贝，模式重复，增加维护成本与出错概率。
- **建议**：抽取 `fn copy_array(arr : Array[Double]) -> Array[Double]` 与 `fn copy_calib_params(arr : Array[CalibParam]) -> Array[CalibParam]` 辅助函数（或使用标准库的 `Array::copy`/`clone` 若可用），统一调用。

### 本轮统计

| 严重程度 | 数量 |
|---------|------|
| 严重 | 1 |
| 一般 | 7 |
| 轻微 | 10 |

### 总评

整体来看，shared/ 率定、评价与时间序列模块的代码结构清晰、职责划分合理，评价指标（NSE/KGE/PBIAS/RMSE/R²/LogNSE/RSR/一致性指数等）的数学公式实现正确，GB/T 22482 预报等级判定阈值符合规范，边界条件（空数组、除零、零标准差）均有防御性处理，测试覆盖了主要路径与边界场景，质量基础扎实。

但存在 1 处严重缺陷：`dds_perturb` 中 `rng.next_int().abs() % n` 在 `next_int` 返回 `Int::min` 时因 `abs` 溢出产生负索引，导致数组越界崩溃，需优先修复。7 处一般问题集中在算法规范符合性（SCE-UA 子单纯形非随机抽样、baseflow 多遍滤波未递归）、数值健壮性（Gumbel 重现期未校验）、错误处理缺失（`run_sim_task` 恒成功）、API 契约不一致（`calibrate_basin_case` 忽略 algorithm 参数）、验证数据自洽性误导（流域案例伪观测）及公式范围不匹配（persistence_index 分子分母求和范围不一致）。10 处轻微问题涉及数值精度（π 字面量）、分布偏差（Box-Muller hack）、可读性（baseflow 钳制逻辑）与可维护性（重复深拷贝）等。

建议优先级：先修复严重崩溃缺陷，再处理 baseflow 多遍滤波与 Gumbel 校验等影响数值正确性的一般问题，最后迭代轻微项。
