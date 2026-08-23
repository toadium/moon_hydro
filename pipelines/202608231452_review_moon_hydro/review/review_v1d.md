# R1d: ml/、gis/、flood/ 三模块代码审查

审查时间：2026-08-23

### 审查范围

生产代码：
- ml/matrix.mbt, ml/lstm.mbt, ml/hybrid.mbt
- gis/types.mbt, gis/dem.mbt, gis/river.mbt
- flood/inundation.mbt, flood/risk_map.mbt, flood/damage.mbt

测试代码：
- ml/matrix_test.mbt, ml/lstm_test.mbt, ml/hybrid_test.mbt
- gis/types_test.mbt, gis/dem_test.mbt, gis/river_test.mbt
- flood/inundation_test.mbt, flood/risk_map_test.mbt, flood/damage_test.mbt

### 发现

#### [严重] train_residual_lstm 在 lookback≠input_dim 时训练崩溃

- **位置**：`ml/hybrid.mbt:132`、`ml/hybrid.mbt:150`
- **描述**：`train_residual_lstm` 通过 `prepare_sequences(train_residual, config.lookback)` 构造训练输入，每个输入长度为 `config.lookback`。随后调用 `lstm.mse(inputs, targets)` → `lstm.forward` → `lstm.step`，在 `step` 中 `vec_concat(x_t, prev_state.h)` 长度为 `lookback + hidden_dim`，而权重矩阵 `w_i` 的列数为 `input_dim + hidden_dim`。当 `config.lookback != config.lstm_config.input_dim` 时，`mat_vec_mul` 将触发 `abort("mat_vec_mul: row length != vector length")` 崩溃。`hybrid_forecast` 已在 `hybrid.mbt:236-250` 对此维度不匹配做了填充/截断处理，说明 `lookback != input_dim` 是受支持的使用场景，但训练路径缺少对应适配。现有测试均设 `lookback == input_dim`，未覆盖此分支。
- **建议**：在 `train_residual_lstm` 中对 `prepare_sequences` 产出的每个输入做与 `hybrid_forecast:236-250` 相同的维度适配（截断或零填充到 `input_dim`），或在训练前校验 `lookback == input_dim` 并给出明确错误信息。

#### [严重] Forest 水深-损失率曲线在 depth=1.0 处不连续

- **位置**：`flood/damage.mbt:142-148`
- **描述**：Forest 曲线在 `depth < 1.0` 时返回 `depth * 0.05`，在 `depth >= 1.0` 时返回 `0.1`。当 depth 从下方趋近 1.0 时损失率趋近 0.05，而 depth=1.0 时跳至 0.1，形成 2 倍跳变。对比 Residential/Commercial/Industrial/Agricultural 曲线在所有分段边界处均连续，Forest 曲线此处为唯一的间断点，会导致水深略超 1.0m 时损失估计翻倍。
- **建议**：将 `depth >= 1.0` 分支改为 `0.05 + (depth - 1.0) * k`（k 为衰减斜率，如 0.02），使曲线在 depth=1.0 处连续；或将 `depth < 1.0` 分支斜率调整为 0.1 使其在 depth=1.0 时达到 0.1。

#### [一般] hybrid_forecast 测试段输入使用未来观测值（数据泄露）

- **位置**：`ml/hybrid.mbt:224-234`
- **描述**：在测试段循环 `for i in test_start..<n` 中，LSTM 输入使用 `observed[idx] - physical_forecast[idx]`，其中 `idx = i - lookback + j`。当 `i >= test_start + lookback` 时，`idx` 落入测试段 `[test_start, n)`，即使用了待预报时段的观测值作为输入。在真实实时预报场景中这些观测值不可得，会导致评估性能虚高。若仅用于回算（hindcasting）验证则可接受，但函数名 `hybrid_forecast` 暗示预报用途。
- **建议**：在文档注释中明确说明此函数为回算/验证用途；或为真正的实时预报模式提供独立路径，测试段输入仅使用物理预报值或已发布的观测值。

#### [一般] LSTM::forecast 首步重复处理末位输入

- **位置**：`ml/lstm.mbt:160-170`
- **描述**：`forward_with_state(history)` 处理全部历史序列并返回包含最后一个输入 `history[n-1]` 效应的状态 `state_init`。随后 `last_input = history[n-1]`，首步预报执行 `step(history[n-1], state_init)`，即 `history[n-1]` 被处理两次：一次在 `forward_with_state` 中，一次在首步预报中。这导致首步预报输出基于冗余输入，后续自回归步骤虽正确但起始状态已偏差。
- **建议**：首步预报应使用 `forward_with_state` 返回的最后一步输出 `y_{n-1}`（当前被 `_` 丢弃）作为 `last_input`，而非 `history[n-1]`；或用 `forward_with_state(history[0..n-1])` 获取不含末位输入的状态，再以 `history[n-1]` 作为首步输入。

#### [一般] generate_risk_map 流速与水深时刻不匹配

- **位置**：`flood/risk_map.mbt:104-117`
- **描述**：`generate_risk_map` 用 `max_depth[k]` 作为水深、`hu_final[k]/h` 作为流速参与风险分类，其中 `hu_final` 是仿真最终时刻的动量，`max_depth` 是全过程最大水深。两者来自不同时刻，物理上不自洽。水深最大时刻未必是流速最大时刻，用最终动量除以最大水深可能高估或低估危险度指数。代码注释（`risk_map.mbt:91-92`，P2-7）已承认此局限。
- **建议**：在 `simulate_inundation` 中同步记录 `max_hu`/`max_hv`（或 `max_velocity`），`generate_risk_map` 使用与 `max_depth` 同时刻的流速场；若暂不实现，应在 `RiskMap` 结构或文档中标注流速为最终时刻值，提醒使用者注意。

#### [一般] to_ascii_map 方向标注与迭代轴不一致

- **位置**：`flood/risk_map.mbt:213-227`
- **描述**：`to_ascii_map` 标注 `"(上游) N"`（北方），但外层循环 `i in 0..<nx` 对应 SWE 网格的 x 轴（东西方向），内层循环 `j in 0..<ny` 对应 y 轴。输出每行固定 x、遍历 y，实际呈现的是物理网格的转置视图。标注 "N" 与实际方向不符，可能误导使用者对淹没方位的判断。
- **建议**：将标注改为正确的方向标识（如 "W→E" 表示行方向），或调整循环顺序使 i 对应 y 轴（南北）、j 对应 x 轴（东西），使输出与地理方位一致。

#### [一般] vec_norm/vec_std 注释声称使用 sqrt 但代码仍用 pow

- **位置**：`ml/matrix.mbt:185-188`、`ml/matrix.mbt:206-218`
- **描述**：`vec_norm` 注释标注 "P3-1：使用sqrt替代pow提升精度和性能"，但实现仍为 `@math.pow(vec_dot(a, a), 0.5)`。`vec_std` 同样使用 `@math.pow(..., 0.5)`。注释与代码不一致，P3-1 修复未实际落地。`@math.pow(x, 0.5)` 在数学上等价于 `sqrt(x)`，但通常精度略低且性能更差。
- **建议**：将 `@math.pow(x, 0.5)` 替换为 `@math.sqrt(x)`（若 MoonBit 标准库提供），或删除注释中的 P3-1 标注以避免误导。

#### [一般] vec_add/vec_mul/vec_dot/mat_vec_mul 维度检查后的 min 逻辑为死代码

- **位置**：`ml/matrix.mbt:30-33`、`ml/matrix.mbt:44-47`、`ml/matrix.mbt:173-176`、`ml/matrix.mbt:91-94`
- **描述**：以 `vec_add` 为例，先检查 `a.length() != b.length()` 并 `abort`，随后计算 `n = min(a.length(), b.length())`。由于 `abort` 已保证两长度相等，`min` 恒等于任一长度，该分支永不执行。`vec_mul`、`vec_dot`、`mat_vec_mul` 存在相同模式。注释 "维度安全：取较短向量长度避免越界" 描述的是未实现的行为，具有误导性。
- **建议**：移除冗余的 `min` 计算和 "维度安全" 注释，直接使用 `a.length()`；或若确实需要宽容处理维度不匹配，则移除 `abort` 改为静默截断。

#### [一般] inundation_duration 包含干旱间隙

- **位置**：`flood/inundation.mbt:135`、`flood/inundation.mbt:202-211`
- **描述**：`last_wet_time[k]` 记录单元最后一次水深超过阈值的时刻，`inundation_duration[k] = last_wet_time[k] - arrival_time[k]`。若单元在仿真过程中先淹没、再退水、再淹没，该公式将中间干旱时段也计入持续时间，高估实际淹没时长。
- **建议**：改为累积式计算——每步检查 `h > depth_threshold` 时 `duration[k] += dt_eff`，得到真实的总湿时；或保留当前定义但在文档中明确标注为"淹没时间跨度"而非"淹没持续时间"。

#### [一般] compute_strahler_orders/topological_order 对悬空 to_node 会崩溃

- **位置**：`gis/river.mbt:58`、`gis/river.mbt:89`
- **描述**：`in_degree` Map 仅包含 `self.nodes` 中的节点。若某 `RiverReach` 的 `to_node` 未通过 `add_node` 加入网络，`in_degree[reach.to_node]` 将触发 KeyError 崩溃。`extract_network_from_dem` 构建的网络不会有此问题，但用户手动构建的 `RiverNetwork` 可能遗漏节点。
- **建议**：在函数入口校验所有 reach 的 `from_node`/`to_node` 均在 `self.nodes` 中，或使用 `in_degree.get(reach.to_node)` 安全访问并跳过无效引用。

#### [一般] extract_network_from_dem 多出口时 outlet_id 被覆盖

- **位置**：`gis/river.mbt:272-275`
- **描述**：标记 Outlet 节点时执行 `network.outlet_id = node_id`，若 DEM 存在多个独立流域出口（如多个局部低洼地），仅保留最后遍历到的出口 ID，先前出口信息丢失。`RiverNetwork` 结构也仅支持单一 `outlet_id` 字段。
- **建议**：将 `outlet_id` 改为 `Array[Int]` 或 `Set[Int]` 支持多出口；或在文档中明确单流域假设并校验出口数 ≤ 1。

#### [一般] estimate_damage 未校验 max_depth 与网格尺寸一致性

- **位置**：`flood/damage.mbt:177-188`
- **描述**：`estimate_damage` 以 `n_total = land_use.nx * land_use.ny` 为循环上界访问 `max_depth[k]`，但未校验 `max_depth.length() >= n_total`。若 `max_depth` 来自不同分辨率的仿真结果或经降采样后长度不足，将触发数组越界崩溃。同类函数 `generate_risk_map` 也存在此问题（`risk_map.mbt:100-104`）。
- **建议**：在函数入口校验 `max_depth.length() >= n_total`，不一致时 `abort` 并给出明确错误信息，或截断到较小长度。

#### [一般] simulate_inundation 不稳定状态被记入 max_depth

- **位置**：`flood/inundation.mbt:169-187`
- **描述**：每步先记录 `max_depth[k]` 和 `arrival_time[k]`，再检查稳定性 `h < -0.001 || h > 1000000.0`。若检测到不稳定则 `break`，但不稳定步的极端水深值（如 h=2000000.0）已被写入 `max_depth`。下游 `generate_risk_map` 和 `estimate_damage` 会基于含异常值的 `max_depth` 计算风险和损失，产生荒谬结果。负水深虽因 `h > max_depth[k]`（初始 0.0）不会被记入，但极大正值会。
- **建议**：将稳定性检查移至记录之前，不稳定时跳过本步记录直接 `break`；或在 `InundationResult` 中标记 `max_depth` 包含不稳定数据，下游消费者据此决定是否使用。

#### [轻微] d8_distances 中 √2 近似值精度不足

- **位置**：`gis/dem.mbt:50`、`gis/dem.mbt:52`、`gis/dem.mbt:54`、`gis/dem.mbt:56`
- **描述**：对角线距离使用 `1.41421356`（9 位有效数字），而 Double 精度的 √2 = 1.4142135623730951。误差约 6.2e-9，对流向判定几乎无影响，但在高精度汇流分析中可能引入微小偏差。
- **建议**：替换为 `@math.sqrt(2.0)` 或更高精度字面量 `1.4142135623730951`。

#### [轻微] classify_risk 边界条件依赖浮点舍入

- **位置**：`flood/risk_map.mbt:81`
- **描述**：测试 "浅水中流速" 中 `depth=0.2, velocity=1.0`，`danger = 0.2 * 1.5`。在 IEEE 754 Double 下 `0.2 * 1.5 = 0.30000000000000004 > 0.3` 恰好为 true，测试通过。但代码使用 `danger > 0.3`（严格大于），若浮点舍入稍有不同则结果会翻转为 LowRisk。边界判定依赖舍入行为，不够稳健。
- **建议**：将边界阈值调整为略小于 0.3（如 0.299）或改用 `>=` 并调整阈值，使边界判定不依赖浮点舍入。

#### [轻微] inundation_stats 统计阈值与其他模块不一致

- **位置**：`flood/inundation.mbt:259`
- **描述**：`inundation_stats` 以 `max_depth[k] > 0.0` 统计淹没单元数，而 `simulate_inundation` 和 `extract_inundation_extent` 使用 `depth_threshold`（默认 0.05）作为淹没判据。`inundation_stats` 的计数可能包含水深极小（如 0.001m）的单元，与 `total_inundated_cells` 不一致。
- **建议**：`inundation_stats` 增加 `depth_threshold` 参数，或从 `InundationResult` 中携带阈值信息，保持统计口径一致。

#### [轻微] extract_network_from_dem 中 slope 未限制非负

- **位置**：`gis/river.mbt:244-248`
- **描述**：`slope = (from_node.elevation - to_node.elevation) / length`。D8 流向保证 from_node 高于 to_node（drop > 0），但在平坦区域（drop = 0）或 DEM 数据异常时 slope 可能为 0 或负值。负坡度在后续水力计算中可能引发数值问题。
- **建议**：对 slope 做 `max(slope, 0.0)` 下限保护，或在平坦段赋予最小坡度（如 0.0001）。

#### [轻微] train_residual_lstm 训练超参数硬编码

- **位置**：`ml/hybrid.mbt:142`、`ml/hybrid.mbt:158-159`
- **描述**：全局搜索起点数 `n_global = 50`、局部微调轮数 `n_local_rounds = 5`、每轮扰动数 `n_perturb_per_round = 30` 均硬编码在函数体内，无法从 `HybridConfig` 配置。不同规模/复杂度的残差序列可能需要不同的搜索强度。
- **建议**：将关键超参数纳入 `HybridConfig`，或提供带默认值的可选参数。

#### [轻微] trace_to_outlet 仅跟踪第一条下游河段

- **位置**：`gis/river.mbt:145`
- **描述**：`current = downstream[0].to_node` 仅取第一条下游河段。在正常树状河网中每个节点至多一条下游河段，行为正确；但若网络存在分叉（一个节点多条下游河段），则只返回一条路径，可能遗漏部分下游链路。
- **建议**：在文档中明确单下游假设；或改为返回所有可能路径的集合。

#### [轻微] prepare_rainfall_runoff 默认参数 input_dim=0 绕过维度校验

- **位置**：`ml/hybrid.mbt:66-71`
- **描述**：维度校验条件为 `if input_dim > 0 && input_dim != 2 * lookback`，而 `input_dim` 默认值为 0，即不传参时校验被完全跳过。函数始终生成 `2*lookback` 长度的输入，若调用方 LSTM 的 `input_dim != 2*lookback`，错误将在后续 `mat_vec_mul` 中以不直观的 "row length != vector length" 崩溃，而非在此处获得清晰错误信息。
- **建议**：将默认值改为 `2 * lookback` 使校验始终生效，或移除默认值要求调用方显式传入；也可在无 `input_dim` 时从上下文推断。

#### [轻微] vec_normalize 测试断言未取绝对值

- **位置**：`ml/matrix_test.mbt:114`、`ml/matrix_test.mbt:117`
- **描述**：`assert_true(vec_mean(normalized) - 0.0 < 0.0001)` 和 `assert_true(restored[i] - v[i] < 0.0001)` 使用单向比较而非 `abs(diff) < 0.0001`。若 `vec_mean(normalized)` 为负（如 -0.001），断言仍会通过，无法检测回归误差。`restored[i] - v[i]` 同理，负偏差不会被捕获。
- **建议**：改为 `(vec_mean(normalized)).abs() < 0.0001` 和 `(restored[i] - v[i]).abs() < 0.0001`。

### 本轮统计

| 严重程度 | 数量 |
|---------|------|
| 严重 | 2 |
| 一般 | 10 |
| 轻微 | 8 |

### 总评

三个模块整体架构清晰、职责划分合理：ml/ 提供矩阵/LSTM/混合预报基础能力，gis/ 提供 DEM 分析与河网拓扑，flood/ 提供淹没推演与风险评估，层间通过明确的数据结构（`DEMGrid`、`SWEGrid2D`、`InundationResult`）解耦。LSTM 前向传播公式实现正确（标准门控方程：i_t/f_t/o_t 用 sigmoid、g_t 用 tanh、c_t = f_t⊙c_{t-1}+i_t⊙g_t、h_t = o_t⊙tanh(c_t)），D8 流向编码与坡降归一化正确，Strahler 河序的 max/second_max 逻辑正确（两条最高级相同则+1，否则取最大），JRC 损失曲线（除 Forest 外）在分段边界处均连续，Xavier 初始化公式 `sqrt(6/(rows+cols))` 正确，测试覆盖了主要功能路径。

需优先修复的两个严重问题：(1) `train_residual_lstm` 在 `lookback != input_dim` 时因缺少维度适配而崩溃——`hybrid_forecast` 已处理此场景但训练路径遗漏，属于已支持配置下的确定性崩溃；(2) Forest 损失曲线在 depth=1.0 处 2 倍跳变，破坏了损失评估的连续性。一般问题中，`hybrid_forecast` 测试段数据泄露、`LSTM::forecast` 首步重复处理末位输入、`simulate_inundation` 不稳定状态记入 max_depth 三项对结果可信度影响较大，建议后续优先处理。其余为健壮性增强和文档一致性问题，不影响当前正常路径下的功能正确性。
