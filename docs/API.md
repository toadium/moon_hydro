# 沐澜水文 · API 文档

> 自动生成自 `moon info` 接口文件，共 150+ 个公开函数

---

## 目录

- [新安江模型](#新安江模型)
- [浅水方程](#浅水方程)
- [耦合仿真](#耦合仿真)
- [参数率定](#参数率定)
- [批量仿真](#批量仿真)
- [评价指标](#评价指标)
- [时间序列分析](#时间序列分析)
- [流域校验](#流域校验)
- [JSON 端点](#json-端点)
- [测试数据生成](#测试数据生成)
- [持久化存储](#持久化存储)
- [任务调度](#任务调度)
- [性能基准](#性能基准)
- [权限框架](#权限框架)

---

## 新安江模型

| 函数 | 签名 | 说明 |
|------|------|------|
| `XinanjiangModel::new` | `(params~, area~, dt~) -> XinanjiangModel` | 构造新安江模型实例 |
| `XinanjiangModel::run` | `(Self, Array[ForcingData]) -> SimResult` | 执行仿真，返回径流过程和状态序列 |
| `XinanjiangParams::default` | `() -> XinanjiangParams` | 默认参数（三水源典型值） |
| `set_xaj_param` | `(XinanjiangParams, String, Double) -> XinanjiangParams` | 按名称设置参数 |
| `params_to_xaj` | `(Array[CalibParam]) -> XinanjiangParams` | 率定参数数组转新安江参数 |
| `default_calib_params` | `() -> Array[CalibParam]` | 默认率定参数（11个） |

---

## 浅水方程

### 1D SWE

| 函数 | 签名 | 说明 |
|------|------|------|
| `SWEGrid1D::uniform` | `(nx~, dx~, h0~) -> SWEGrid1D` | 均匀网格 |
| `SWEGrid1D::run` | `(Self, SWESolverConfig) -> SWESolverResult` | 执行 1D 求解 |

### 2D SWE

| 函数 | 签名 | 说明 |
|------|------|------|
| `SWEGrid2D::uniform` | `(nx~, ny~, dx~, dy~, h0~) -> SWEGrid2D` | 均匀 2D 网格 |
| `SWEGrid2D::set_block` | `(Self, i0~, i1~, j0~, j1~, h_value~) -> Unit` | 设置区块水深 |
| `SWEGrid2D::run` | `(Self, SWE2DSolverConfig) -> SWE2DSolverResult` | 执行 2D 求解 |

---

## 耦合仿真

| 函数 | 签名 | 说明 |
|------|------|------|
| `couple_run` | `(XinanjiangModel, SWEGrid1D, CouplingParams, SWEBoundary, Array[ForcingData], Double) -> CouplingResult` | 新安江+SWE 耦合仿真 |
| `couple_step` | `(XinanjiangModel, SWEGrid1D, CouplingParams, SWEBoundary, ForcingData, XinanjiangState, Double) -> (XinanjiangState, SWEGrid1D, Double, Double)` | 单步耦合 |

---

## 参数率定

### SCE-UA

| 函数 | 签名 | 说明 |
|------|------|------|
| `sceua_calibrate` | `(SCEUAConfig, area~, dt~, Array[ForcingData], Array[Double]) -> SCEUAResult` | SCE-UA 全局优化率定 |

### DDS

| 函数 | 签名 | 说明 |
|------|------|------|
| `dds_calibrate` | `(DDSConfig, area~, dt~, Array[ForcingData], Array[Double]) -> CalibResult` | DDS 动态维度搜索率定 |

---

## 批量仿真

| 函数 | 签名 | 说明 |
|------|------|------|
| `run_batch_sim` | `(Array[SimTask]) -> BatchSimResult` | 批量多流域仿真 |
| `run_ensemble_sim` | `(basin_name~, Array[XinanjiangParams], area~, dt~, Array[ForcingData], observed?) -> BatchSimResult` | 集合仿真 |
| `param_sensitivity_scan` | `(XinanjiangParams, param_name~, lower~, upper~, n_samples~, area~, dt~, Array[ForcingData], Array[Double]) -> Array[(Double, SimTaskResult)]` | 参数敏感性扫描 |
| `monte_carlo_uncertainty` | `(XinanjiangParams, Array[CalibParam], n_samples~, area~, dt~, Array[ForcingData], seed?) -> MonteCarloResult` | 蒙特卡洛不确定性分析 |

---

## 评价指标

### 基础指标

| 函数 | 签名 | 说明 |
|------|------|------|
| `nse` | `(Array[Double], Array[Double]) -> Double` | Nash-Sutcliffe 效率系数 |
| `kge` | `(Array[Double], Array[Double]) -> Double` | Kling-Gupta 效率系数 |
| `pbias` | `(Array[Double], Array[Double]) -> Double` | 百分比偏差 |
| `evaluate` | `(Array[Double], Array[Double], forecast_type?) -> EvaluationResult` | 综合评价 |

### 扩展指标

| 函数 | 签名 | 说明 |
|------|------|------|
| `log_nse` | `(Array[Double], Array[Double]) -> Double` | 对数 NSE |
| `kge_decomposition` | `(Array[Double], Array[Double]) -> (Double, Double, Double)` | KGE 分解 (r, α, β) |
| `mae` | `(Array[Double], Array[Double]) -> Double` | 平均绝对误差 |
| `mse` | `(Array[Double], Array[Double]) -> Double` | 均方误差 |
| `rsr` | `(Array[Double], Array[Double]) -> Double` | RSR |
| `index_of_agreement` | `(Array[Double], Array[Double]) -> Double` | 一致性指数 |
| `persistence_index` | `(Array[Double], Array[Double]) -> Double` | 持续性指数 |
| `percent_forecast_correct` | `(Array[Double], Array[Double]) -> Double` | 预报正确率(%) |
| `evaluate_extended` | `(Array[Double], Array[Double]) -> ExtendedEvaluationResult` | 一次性计算所有扩展指标 |

### 预报等级

| 函数 | 签名 | 说明 |
|------|------|------|
| `forecast_grade_nse` | `(Double) -> ForecastGrade` | NSE 等级评定 |
| `forecast_grade_pbias` | `(Double, forecast_type~) -> ForecastGrade` | PBIAS 等级评定 |
| `forecast_grade_rsr` | `(Double) -> ForecastGrade` | RSR 等级评定 |
| `comprehensive_grade` | `(grade_nse~, grade_pbias~) -> ForecastGrade` | 综合等级 |

---

## 时间序列分析

| 函数 | 签名 | 说明 |
|------|------|------|
| `ts_stats` | `(Array[Double]) -> TSStats` | 统计（均值/标准差/范围/趋势） |
| `detect_peaks` | `(Array[Double], threshold?) -> Array[Int]` | 洪峰检测 |
| `baseflow_separation` | `(Array[Double], alpha?, passes?) -> Array[Double]` | 基流分离 |
| `flow_duration_curve` | `(Array[Double]) -> Array[(Double, Double)]` | 流量历时曲线 |
| `moving_average` | `(Array[Double], window~) -> Array[Double]` | 滑动平均 |
| `annual_maxima` | `(Array[Double], year_length~) -> Array[Double]` | 年最大值序列 |
| `autocorrelation` | `(Array[Double], max_lag?) -> Array[Double]` | 自相关函数 |
| `gumbel_estimate` | `(Array[Double]) -> (Double, Double)` | Gumbel 参数估计 |
| `gumbel_return_value` | `(Double, Double, return_period~) -> Double` | Gumbel 重现期值 |

---

## 流域校验

| 函数 | 签名 | 说明 |
|------|------|------|
| `all_basin_cases` | `() -> Array[BasinCase]` | 全部流域案例 |
| `minjiang_zhuqi_basin_case` | `() -> BasinCase` | 闽江竹岐 |
| `feiyunjiang_basin_case` | `() -> BasinCase` | 飞云江 |
| `qingyijiang_basin_case` | `() -> BasinCase` | 青弋江 |
| `calibrate_basin_case` | `(BasinCase, _algorithm?) -> CalibResult` | 单流域率定 |
| `generate_validation_report` | `() -> ValidationReport` | 生成校验报告 |

---

## JSON 端点

| 函数 | 签名 | 说明 |
|------|------|------|
| `to_json_string` | `(T : ToJson) -> String` | 序列化为 JSON |
| `xaj_json_endpoint` | `(String) -> String raise` | 新安江仿真 JSON 端点 |
| `swe_json_endpoint` | `(String) -> String raise` | SWE 仿真 JSON 端点 |
| `couple_json_endpoint` | `(String) -> String raise` | 耦合仿真 JSON 端点 |
| `evaluate_json_endpoint` | `(String) -> String raise` | 评价 JSON 端点 |
| `calibrate_json_endpoint` | `(String) -> String raise` | 率定 JSON 端点 |
| `parse_xaj_request` | `(String) -> XajRunRequest raise` | 解析新安江请求 |
| `parse_swe_request` | `(String) -> SweRunRequest raise` | 解析 SWE 请求 |
| `parse_couple_request` | `(String) -> CoupleRunRequest raise` | 解析耦合请求 |
| `parse_evaluate_request` | `(String) -> EvaluateRequest raise` | 解析评价请求 |
| `parse_calibrate_request` | `(String) -> CalibrateRequest raise` | 解析率定请求 |

---

## 测试数据生成

| 函数 | 说明 |
|------|------|
| `mock_xaj_params` | 随机新安江参数 |
| `mock_flood_rainfall` | 洪水降雨过程 |
| `mock_multi_peak_rainfall` | 多峰降雨过程 |
| `mock_dry_period` | 干旱期数据 |
| `mock_long_term_forcings` | 长期气象数据 |
| `mock_dam_break_grid` | dam-break 网格 |
| `mock_sloped_river_grid` | 斜坡河道网格 |
| `mock_tidal_wave_grid` | 潮波网格 |
| `mock_scenario` | 完整测试场景 |
| `mock_coupling_params` | 耦合参数 |

---

## 持久化存储

> 包 `persistence`，提供仿真方案、历史结果、参数库的持久化读写。
> 内存 DataStore 全后端可用；文件 I/O 仅 native 后端（C FFI）。

### 数据类型

| 类型 | 说明 |
|------|------|
| `SimulationScheme` | 仿真方案（ID/名称/流域/参数/驱动/时间戳） |
| `ResultRecord` | 仿真结果记录（洪峰/NSE/KGE/PBIAS/径流过程） |
| `ParameterSet` | 参数集（ID/名称/流域/参数/描述） |
| `DataStore` | 数据存储（方案 Map + 结果数组 + 参数集 Map） |
| `FileError` | 文件操作错误（FileNotFound/WriteFailed/ReadFailed） |

### DataStore 内存 CRUD

| 函数 | 签名 | 说明 |
|------|------|------|
| `DataStore::new` | `() -> DataStore` | 构造空 DataStore |
| `DataStore::save_scheme` | `(Self, SimulationScheme) -> Unit` | 保存仿真方案 |
| `DataStore::load_scheme` | `(Self, String) -> SimulationScheme?` | 加载仿真方案 |
| `DataStore::list_schemes` | `(Self) -> Array[String]` | 列出所有方案 ID |
| `DataStore::delete_scheme` | `(Self, String) -> Bool` | 删除仿真方案 |
| `DataStore::save_result` | `(Self, ResultRecord) -> Unit` | 保存仿真结果 |
| `DataStore::list_results` | `(Self, String) -> Array[ResultRecord]` | 查询方案的仿真结果 |
| `DataStore::list_all_results` | `(Self) -> Array[ResultRecord]` | 列出所有结果 |
| `DataStore::save_param_set` | `(Self, ParameterSet) -> Unit` | 保存参数集 |
| `DataStore::load_param_set` | `(Self, String) -> ParameterSet?` | 加载参数集 |
| `DataStore::list_param_sets` | `(Self) -> Array[String]` | 列出所有参数集 ID |
| `DataStore::delete_param_set` | `(Self, String) -> Bool` | 删除参数集 |
| `DataStore::stats` | `(Self) -> String` | 统计信息 |
| `DataStore::to_json_string` | `(Self) -> String` | 序列化为 JSON |
| `DataStore::from_json_string` | `(String) -> DataStore raise` | 从 JSON 反序列化 |
| `generate_id` | `(String, UInt64) -> String` | 生成方案 ID |

### 文件 I/O（native 专用）

| 函数 | 签名 | 说明 |
|------|------|------|
| `write_file` | `(String, String) -> Unit raise` | 写入文件 |
| `read_file` | `(String) -> String raise` | 读取文件 |
| `file_exists` | `(String) -> Bool` | 检查文件是否存在 |
| `DataStore::save_to_file` | `(Self, String) -> Unit raise` | DataStore 保存到 JSON 文件 |
| `DataStore::load_from_file` | `(String) -> DataStore raise` | 从 JSON 文件加载 DataStore |
| `SimulationScheme::save_to_file` | `(Self, String) -> Unit raise` | 方案保存到文件 |
| `SimulationScheme::load_from_file` | `(String) -> SimulationScheme raise` | 从文件加载方案 |
| `ParameterSet::save_to_file` | `(Self, String) -> Unit raise` | 参数集保存到文件 |
| `ParameterSet::load_from_file` | `(String) -> ParameterSet raise` | 从文件加载参数集 |

---

## 任务调度

> 模块 `shared/task_scheduler.mbt`，提供批量仿真任务调度与进度推送。
> 复用 `batch_sim.mbt` 中的 `SimTask` 类型。

### 数据类型

| 类型 | 说明 |
|------|------|
| `TaskStatus` | 任务状态枚举（Pending/Running/Completed/Failed） |
| `TaskExecResult` | 任务执行结果（含计时与状态） |
| `ProgressInfo` | 进度信息（已完成/总数/当前任务/百分比） |
| `TaskScheduler` | 任务调度器（任务队列 + 结果 + 状态） |

### 调度器 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `TaskScheduler::new` | `() -> TaskScheduler` | 构造空调度器 |
| `TaskScheduler::add_task` | `(Self, SimTask) -> Unit` | 添加任务到队列 |
| `TaskScheduler::add_tasks` | `(Self, Array[SimTask]) -> Unit` | 批量添加任务 |
| `TaskScheduler::task_count` | `(Self) -> Int` | 获取任务总数 |
| `TaskScheduler::completed_count` | `(Self) -> Int` | 获取已完成数 |
| `TaskScheduler::run` | `(Self, (ProgressInfo) -> Unit) -> Unit` | 执行所有任务（带进度回调） |
| `TaskScheduler::get_results` | `(Self) -> Array[TaskExecResult]` | 获取所有执行结果 |
| `TaskScheduler::get_status` | `(Self, String) -> TaskStatus?` | 获取指定任务状态 |
| `TaskScheduler::progress_report` | `(Self) -> String` | 生成进度报告 |

### 任务执行 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `run_task` | `(SimTask) -> TaskExecResult` | 执行单个任务 |
| `run_tasks` | `(Array[SimTask], (ProgressInfo) -> Unit) -> Array[TaskExecResult]` | 批量执行任务（带进度回调） |
| `create_task_from_basin` | `(String, BasinCase) -> SimTask` | 从流域案例创建任务 |
| `create_basin_tasks` | `(Array[BasinCase]) -> Array[SimTask]` | 批量创建流域任务 |

---

## 性能基准

> 模块 `shared/benchmark.mbt`，轻量级基准测试框架。
> 使用 `@env.now()` 获取时间戳，统计均值/最小/最大/标准差/吞吐量。

### 数据类型

| 类型 | 说明 |
|------|------|
| `BenchResult` | 单次基准测试结果（名称/迭代/耗时/均值/最小/最大/标准差/吞吐量） |
| `BenchSuiteResult` | 基准测试套件结果（套件名/结果数组/总耗时） |

### 基准测试 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `bench` | `(name~, n_iters~, () -> Unit) -> BenchResult` | 运行单次基准测试 |
| `bench_suite` | `(suite_name~, Array[BenchResult]) -> BenchSuiteResult` | 运行基准测试套件 |
| `format_bench_result` | `(BenchResult) -> String` | 格式化基准测试结果 |
| `format_bench_suite` | `(BenchSuiteResult) -> String` | 格式化套件结果 |
| `run_all_benchmarks` | `() -> String` | 运行全部 10 项基准测试并输出报告 |

### 基准测试项

| # | 测试项 | 规模 |
|---|--------|------|
| 1 | 新安江模型仿真 | 100 步 × 50 迭代 |
| 2 | 1D SWE 求解 | 100 单元 × 100 步 × 30 迭代 |
| 3 | 2D SWE 求解 | 30×30 网格 × 50 步 × 20 迭代 |
| 4 | SCE-UA 率定 | 11 参数 × 30 迭代 × 5 次 |
| 5 | DDS 率定 | 11 参数 × 30 迭代 × 5 次 |
| 6 | 批量仿真 | 10 流域 × 100 步 × 10 迭代 |
| 7 | 耦合仿真 | 20 步 × 20 迭代 |
| 8 | 扩展评价指标 | 100 点 × 100 迭代 |
| 9 | 蒙特卡洛不确定性 | 20 采样 × 3 迭代 |
| 10 | JSON 序列化 | 100 步请求 × 100 迭代 |

---

## 权限框架

> 模块 `shared/auth.mbt`，提供用户管理、API 鉴权、方案隔离三大功能。
> 密码哈希使用 FNV-1a + splitmix，Token 使用 splitmix 伪随机生成。

### 数据类型

| 类型 | 说明 |
|------|------|
| `Role` | 用户角色枚举（Admin/Engineer/Viewer） |
| `Permission` | 权限动作枚举（SimRun/Calibrate/SchemeRead/SchemeWrite/SchemeDelete/UserManage/BenchmarkRun） |
| `User` | 用户（ID/用户名/密码哈希/角色/创建时间） |
| `Session` | 会话（Token/用户ID/创建时间/过期时间） |
| `SchemeOwnership` | 方案所有权（方案ID/所有者ID/是否公开） |
| `AuthError` | 认证错误（UserAlreadyExists/UserNotFound/InvalidPassword/InvalidToken/TokenExpired/PermissionDenied/SchemeNotOwned） |
| `AuthManager` | 认证管理器（用户表/用户名索引/会话表/方案所有权表） |

### 用户管理 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `AuthManager::new` | `() -> AuthManager` | 构造空认证管理器 |
| `AuthManager::register` | `(Self, username~, password~, role~, timestamp~) -> String raise` | 注册用户，返回 user_id |
| `AuthManager::login` | `(Self, username~, password~, timestamp~, ttl_seconds~?) -> String raise` | 登录，返回 token |
| `AuthManager::verify_token` | `(Self, String, current_time~) -> User raise` | 验证 token，返回用户 |
| `AuthManager::logout` | `(Self, String) -> Bool` | 登出，返回是否成功 |
| `AuthManager::list_users` | `(Self) -> Array[User]` | 获取所有用户 |
| `AuthManager::delete_user` | `(Self, String) -> Bool` | 删除用户（清理会话和方案） |
| `AuthManager::stats` | `(Self) -> String` | 统计信息 |

### 权限检查 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `role_has_permission` | `(Role, Permission) -> Bool` | 检查角色是否拥有权限 |
| `AuthManager::check_permission` | `(Self, User, Permission) -> Unit raise` | 检查用户权限，失败抛出 PermissionDenied |

### 方案隔离 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `AuthManager::grant_scheme_ownership` | `(Self, user_id~, scheme_id~, is_public~?) -> Unit` | 授予方案所有权 |
| `AuthManager::check_scheme_access` | `(Self, User, String, write~?) -> Unit raise` | 检查方案访问权限 |
| `AuthManager::make_scheme_public` | `(Self, String) -> Bool` | 将方案设为公开 |
| `AuthManager::list_user_schemes` | `(Self, String) -> Array[String]` | 获取用户的所有方案 ID |

### 工具函数

| 函数 | 签名 | 说明 |
|------|------|------|
| `hash_password` | `(String) -> UInt64` | 密码哈希（FNV-1a + splitmix） |
| `generate_token` | `(seed~) -> String` | 生成 Token（splitmix 伪随机） |

### 角色权限矩阵

| 权限 \ 角色 | Admin | Engineer | Viewer |
|-------------|:-----:|:--------:|:------:|
| SimRun | ✅ | ✅ | ✅ |
| Calibrate | ✅ | ✅ | ❌ |
| SchemeRead | ✅ | ✅ | ✅ |
| SchemeWrite | ✅ | ✅ | ❌ |
| SchemeDelete | ✅ | ✅ | ❌ |
| UserManage | ✅ | ❌ | ❌ |
| BenchmarkRun | ✅ | ✅ | ❌ |

---

*生成时间：2026-08-16｜MoonBit 0.1.20260713｜180+ 个公开函数｜V0.5*