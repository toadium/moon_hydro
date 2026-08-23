# 待办事项

---

## 严重问题（P0，需优先修复）

- [x] T1: 三水源划分公式错误，默认参数下壤中流/地下径流恒为零 — 来源：R1a，位置：`shared/xaj_core.mbt:159`
- [x] T2: 蓄量重复计入净雨，水量平衡错误 — 来源：R1a，位置：`shared/xaj_core.mbt:65,119`
- [x] T3: DDS 扰动随机索引 Int::min 溢出导致负下标崩溃 — 来源：R1b，位置：`shared/calibration.mbt:120`
- [x] T4: Session TTL 时间单位不匹配，会话在约 86ms 后过期 — 来源：R1c，位置：`shared/auth.mbt:241`
- [x] T5: benchmark/task_scheduler 时间单位标注错误（纳秒标记为毫秒）— 来源：R1c，位置：`shared/benchmark.mbt:35-37`
- [x] T6: benchmark 计时因 UInt64→Double 提前转换丢失精度 — 来源：R1c，位置：`shared/benchmark.mbt:35-37`
- [x] T7: bench 在 n_iters=0 时产生 NaN — 来源：R1c，位置：`shared/benchmark.mbt:32-53`
- [x] T8: 用户删除后 register 产生 user_id 碰撞，覆盖现有用户 — 来源：R1c，位置：`shared/auth.mbt:201`
- [x] T9: train_residual_lstm 输入维度不匹配导致训练崩溃 — 来源：R1d，位置：`ml/hybrid.mbt:132,150`
- [x] T10: Forest 水深-损失率曲线在 depth=1.0 处不连续 — 来源：R1d，位置：`flood/damage.mbt:142-148`
- [x] T11: C FFI 路径 Bytes 未保证 null 终止，缓冲区过读风险 — 来源：R1e，位置：`persistence/fileio.c:20,32,75,84`
- [x] T12: read_file 静默吞掉读取错误，返回空字符串 — 来源：R1e，位置：`persistence/file_io.mbt:69-73`

## 一般问题（P1，需修复）

- [x] T13: 深层蒸散发 ed 未钳制下界，可能为负 — 来源：R1a，位置：`shared/xaj_core.mbt:59-62`
- [x] T14: SWE 1D run 检测不稳定后不中断循环 — 来源：R1a，位置：`shared/swe_core.mbt:299-301`
- [x] T15: SWE 2D 水深非负保护直接置零，未按比例缩放动量 — 来源：R1a，位置：`shared/swe2d.mbt:359-363`
- [x] T16: 侧向入流计算未考虑新安江时段长度 — 来源：R1a，位置：`shared/coupling.mbt:49-55`
- [x] T17: 河道水位反馈量与蓄量单位不匹配 — 来源：R1a，位置：`shared/coupling.mbt:124,128`
- [x] T18: CouplingParams.n_river_cells 字段冗余 — 来源：R1a，位置：`shared/coupling.mbt:17,99`
- [x] T19: run_impl 重复实现 step_impl 逻辑 — 来源：R1a，位置：`shared/xaj_core.mbt:239-270`
- [x] T20: couple_run 逐字段手动复制状态 — 来源：R1a，位置：`shared/coupling.mbt:268-281`
- [x] T21: SCE-UA CCE 未随机选取子单纯形 — 来源：R1b，位置：`shared/sceua.mbt:206,238-247`
- [x] T22: baseflow_separation 多次滤波未递归，passes 参数失效 — 来源：R1b，位置：`shared/timeseries.mbt:100-144`
- [x] T23: gumbel_return_value 未校验重现期 — 来源：R1b，位置：`shared/timeseries.mbt:205-213`
- [x] T24: run_sim_task 无错误处理路径 — 来源：R1b，位置：`shared/batch_sim.mbt:71-115`
- [x] T25: calibrate_basin_case 忽略 algorithm 参数 — 来源：R1b，位置：`shared/basin_cases.mbt:427-447`
- [ ] T26: 流域校验案例使用伪观测，reference_nse/kge 误导 — 来源：R1b，位置：`shared/basin_cases.mbt:153-254`
- [x] T27: persistence_index 分子分母求和范围不一致 — 来源：R1b，位置：`shared/extended_metrics.mbt:194-216`
- [x] T28: add_task 不校验重复 task_id — 来源：R1c，位置：`shared/task_scheduler.mbt:69-72`
- [x] T29: Viewer 角色拥有 SimRun 权限，与"只读"语义矛盾 — 来源：R1c，位置：`shared/auth.mbt:298`
- [x] T30: check_permission 方法签名接收 AuthManager 但未使用 — 来源：R1c，位置：`shared/auth.mbt:309-317`
- [x] T31: grant_scheme_ownership/make_scheme_public 内部不做权限校验 — 来源：R1c，位置：`shared/auth.mbt:321-378`
- [x] T32: run_xaj 长度不匹配时静默返回 0 指标 — 来源：R1c，位置：`shared/serde_bind.mbt:62-70`
- [x] T33: API 请求类型无输入校验 — 来源：R1c，位置：`shared/api.mbt:9-90`
- [x] T34: CalibrateRequest 仅支持 DDS — 来源：R1c，位置：`shared/api.mbt:67-73`
- [ ] T35: 密码哈希使用非加密安全原语 — 来源：R1c，位置：`shared/auth.mbt:133-164`
- [ ] T36: Token 生成非加密安全 — 来源：R1c，位置：`shared/auth.mbt:180-185`
- [x] T37: 无登录频率限制 — 来源：R1c，位置：`shared/auth.mbt:218-245`
- [x] T38: TaskScheduler::run completed_count O(n²) 复杂度 — 来源：R1c，位置：`shared/task_scheduler.mbt:181`
- [ ] T39: HydroModel trait 绑定 XinanjiangState — 来源：R1c，位置：`shared/hydro_trait.mbt:13-19`
- [ ] T40: hybrid_forecast 测试段数据泄露 — 来源：R1d，位置：`ml/hybrid.mbt:224-234`
- [x] T41: generate_risk_map 流速与水深时刻不匹配 — 来源：R1d，位置：`flood/risk_map.mbt:104-117`
- [x] T42: to_ascii_map 方向标注与迭代轴不一致 — 来源：R1d，位置：`flood/risk_map.mbt:213-227`
- [x] T43: vec_norm/vec_std 注释与代码不一致 — 来源：R1d，位置：`ml/matrix.mbt:185-188`
- [x] T44: vec_add/vec_mul 等维度检查后 min 逻辑为死代码 — 来源：R1d，位置：`ml/matrix.mbt:30-33`
- [x] T45: inundation_duration 包含干旱间隙 — 来源：R1d，位置：`flood/inundation.mbt:135,202-211`
- [x] T46: compute_strahler_orders 对悬空 to_node 会崩溃 — 来源：R1d，位置：`gis/river.mbt:58,89`
- [x] T47: extract_network_from_dem 多出口时 outlet_id 被覆盖 — 来源：R1d，位置：`gis/river.mbt:272-275`
- [x] T48: validate_path 使用 abort 终止进程 — 来源：R1e，位置：`persistence/file_io.mbt:36-40`
- [x] T49: validate_path 路径遍历防护不完整 — 来源：R1e，位置：`persistence/file_io.mbt:37`
- [x] T50: file_exists 未调用 validate_path — 来源：R1e，位置：`persistence/file_io.mbt:80-83`
- [x] T51: delete_file 复用 WriteFailed 语义错误 — 来源：R1e，位置：`persistence/file_io.mbt:94-101`
- [x] T52: hydro_write_file 未 fsync — 来源：R1e，位置：`persistence/fileio.c:22-26`
- [ ] T53: generate_id 全局可变 Ref 并发不安全 — 来源：R1e，位置：`persistence/store.mbt:200-206`
- [ ] T54: DataStore 无并发同步 — 来源：R1e，位置：`persistence/store.mbt:49-53`
- [x] T55: save_result 无去重无容量上限 — 来源：R1e，位置：`persistence/store.mbt:108-110`
- [x] T56: delete_scheme 不级联删除关联结果 — 来源：R1e，位置：`persistence/store.mbt:97-104`
- [ ] T57: load_from_file 错误未包装 — 来源：R1e，位置：`persistence/store.mbt:193-196`
- [x] T58: main 硬编码 dispatch("demo") — 来源：R1e，位置：`backend/main.mbt:11-15`
- [ ] T59: cli_auth 硬编码明文密码 — 来源：R1e，位置：`backend/cli.mbt:636-651`
- [ ] T60: cli_auth 未检查 register 返回值 — 来源：R1e，位置：`backend/cli.mbt:635-687`
- [x] T61: 字符串按字节切片可能截断 UTF-8 — 来源：R1e，位置：`backend/cli.mbt:490-492`
- [x] T62: repeat_str O(n²) 复杂度 — 来源：R1e，位置：`backend/cli.mbt:19-25`
- [ ] T63: CalibrationCompleted 硬编码 calib_metric — 来源：R1e，位置：`frontend/lib/update_logic.mbt:74`
- [x] T64: SimulationCompleted 清空 calib 字段 — 来源：R1e，位置：`frontend/lib/update_logic.mbt:48-64`
- [x] T65: CalibrationCompleted 覆盖 nse 字段语义过载 — 来源：R1e，位置：`frontend/lib/update_logic.mbt:84-89`
- [ ] T66: RunEvaluation/RunBatchSim 数据被忽略 — 来源：R1e，位置：`frontend/lib/update_logic.mbt:100,119`
- [x] T67: slim_run 不校验 area/dt — 来源：R1e，位置：`frontend/lib/wasm_slim_model.mbt:33-77`
- [ ] T68: load_basin_config 未知流域名静默回退 — 来源：R1e，位置：`frontend/lib/wasm_slim_model.mbt:144-150`
- [ ] T69: View 层无转义基础设施，XSS 风险 — 来源：R1e，位置：`frontend/lib/view_layout.mbt:225-298`
- [x] T70: VSelect 渲染未检查 idx >= 0 — 来源：R1e，位置：`frontend/lib/view_layout.mbt:290-292`
- [ ] T71: cli_persistence 依赖 @env.now() 跨后端可移植性 — 来源：R1e，位置：`backend/cli.mbt:548`
