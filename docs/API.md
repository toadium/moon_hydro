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
- [GIS 接口](#gis-接口)
- [洪水淹没推演](#洪水淹没推演)

---

## 新安江模型

| 函数 | 签名 | 说明 |
|------|------|------|
| `XinanjiangModel::new` | `(params~, area~, dt~) -> XinanjiangModel` | 构造新安江模型实例 |
| `XinanjiangModel::step` | `(Self, ForcingData, XinanjiangState) -> XinanjiangState` | 单步仿真（V0.9修复：保持汇流状态qs/qi/qg） |
| `XinanjiangModel::run` | `(Self, Array[ForcingData]) -> SimResult` | 执行仿真，返回径流过程和状态序列 |
| `XinanjiangParams::default` | `() -> XinanjiangParams` | 默认参数（三水源典型值） |
| `XinanjiangState::initial` | `() -> XinanjiangState` | 构造初始状态（全零，含qs/qi/qg=0） |
| `set_xaj_param` | `(XinanjiangParams, String, Double) -> XinanjiangParams` | 按名称设置参数 |
| `params_to_xaj` | `(Array[CalibParam]) -> XinanjiangParams` | 率定参数数组转新安江参数 |
| `default_calib_params` | `() -> Array[CalibParam]` | 默认率定参数（11个） |

### XinanjiangState 字段（V0.9更新）

| 字段 | 类型 | 说明 |
|------|------|------|
| w/wu/wl/wd | Double | 张力水蓄量（总/上层/下层/深层） |
| s | Double | 自由水蓄量 |
| r/rs/ri/rg | Double | 产流量/地表径流/壤中流/地下径流 |
| e | Double | 时段蒸散发量 |
| q | Double | 出口断面流量 |
| **qs/qi/qg** | **Double** | **V0.9新增：地表水/壤中流/地下水汇流分量，修复逐步仿真路由状态丢失** |

### HydroModel Trait（V0.9更新）

```moonbit
pub trait HydroModel {
  fn step(self : Self, forcing : ForcingData, state : XinanjiangState) -> XinanjiangState
  fn run(self : Self, forcings : Array[ForcingData]) -> SimResult
}
```

> V0.9说明：当前trait签名绑定XinanjiangState，未来泛化方案：引入ModelState trait或关联类型。

---

## 浅水方程

### 1D SWE

| 函数 | 签名 | 说明 |
|------|------|------|
| `SWEGrid1D::uniform` | `(nx~, dx~, h0~) -> SWEGrid1D` | 均匀网格 |
| `SWEGrid1D::step_lf` | `(Self, Double, SWEBoundary) -> SWEGrid1D` | 单步Lax-Friedrichs推进（V0.9：不可变边界，返回新网格） |
| `SWEGrid1D::run` | `(Self, SWESolverConfig) -> SWESolverResult` | 执行 1D 求解（CFL自适应步长） |

> V0.9变更：`apply_boundary`返回网格副本不修改输入；Manning阈值从0.000001提高到0.001避免极浅水不稳定。

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
| `couple_step` | `(XinanjiangModel, SWEGrid1D, CouplingParams, SWEBoundary, ForcingData, XinanjiangState, Double) -> (XinanjiangState, SWEGrid1D, Double, Double)` | 单步耦合，返回(状态,网格,侧向入流,河道水位) |

> V0.9变更：`couple_run`状态序列包含qs/qi/qg字段；`run_couple` JSON端点正确返回runoff_series。

---

## 参数率定

### SCE-UA

| 函数 | 签名 | 说明 |
|------|------|------|
| `sceua_calibrate` | `(SCEUAConfig, area~, dt~, Array[ForcingData], Array[Double]) -> SCEUAResult` | SCE-UA 全局优化率定 |

> V0.9：SCE-UA支持target_metric配置("nse"或"kge")，不再硬编码NSE。

### DDS

| 函数 | 签名 | 说明 |
|------|------|------|
| `dds_calibrate` | `(DDSConfig, area~, dt~, Array[ForcingData], Array[Double]) -> CalibResult` | DDS 动态维度搜索率定 |

### DDSConfig 字段（V0.9更新）

| 字段 | 类型 | 说明 |
|------|------|------|
| max_iter | Int | 最大迭代次数 |
| r | Double | 扰动率(默认0.2) |
| seed | UInt64 | 随机种子 |
| target_metric | String | 目标指标("nse"或"kge")，V0.9修复：DDS正确传递此参数 |
| params | Array[CalibParam] | 待率定参数 |
| **max_no_improve** | **Int** | **V0.9新增：最大无改进迭代次数(默认100)，替代硬编码收敛阈值** |

---

## 批量仿真

| 函数 | 签名 | 说明 |
|------|------|------|
| `run_batch_sim` | `(Array[SimTask]) -> BatchSimResult` | 批量多流域仿真 |
| `run_ensemble_sim` | `(basin_name~, Array[XinanjiangParams], area~, dt~, Array[ForcingData], observed?) -> BatchSimResult` | 集合仿真 |
| `param_sensitivity_scan` | `(XinanjiangParams, param_name~, lower~, upper~, n_samples~, area~, dt~, Array[ForcingData], Array[Double]) -> Array[(Double, SimTaskResult)]` | 参数敏感性扫描 |
| `monte_carlo_uncertainty` | `(XinanjiangParams, Array[CalibParam], n_samples~, area~, dt~, Array[ForcingData], seed?) -> MonteCarloResult` | 蒙特卡洛不确定性分析 |

### SimTaskResult 字段（V0.9更新）

| 字段 | 类型 | 说明 |
|------|------|------|
| task_id/basin_name | String | 任务标识/流域名称 |
| runoff_series | Array[Double] | 径流过程 |
| peak_flow/peak_time | Double/Int | 洪峰流量/时段索引 |
| nse/kge/pbias | Double | 评价指标(若有观测) |
| **has_obs** | **Bool** | **V0.9新增：标记是否有观测数据，替代nse!=0过滤** |
| success/error_message | Bool/String | 执行状态/错误信息 |

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
| `delete_file` | `(String) -> Unit raise` | 删除文件（V0.9新增C FFI） |
| `hydro_file_exists` | `(String) -> Bool` | C FFI文件存在检查（V0.9新增） |
| `hydro_delete_file` | `(String) -> Int` | C FFI文件删除（V0.9新增） |
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
> 密码哈希使用 FNV-1a + splitmix 多轮哈希（V0.9增强），Token 使用 splitmix 伪随机生成。
> 安全提示：当前为轻量级哈希，生产环境应替换为 bcrypt/argon2。

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

## GIS 接口

> 模块 `gis/`，提供 DEM 分析、河网提取、流域 delineation 功能。
> 包含 `gis/types.mbt`（基础类型）、`gis/dem.mbt`（DEM 处理）、`gis/river.mbt`（河网处理）。

### 基础类型

| 类型 | 说明 |
|------|------|
| `GeoPoint` | 地理坐标点（经纬度） |
| `XYPoint` | 平面坐标点（投影坐标，如 UTM） |
| `Polyline` | 多段线（河流走向、边界线） |
| `Polygon` | 多边形（流域边界，外边界 + 内部空洞） |
| `BasinBoundary` | 流域边界（名称 + 多边形 + 面积 + 形心） |
| `DEMGrid` | DEM 网格（规则网格高程数据） |
| `RiverNode` | 河流节点（ID + 坐标 + 高程 + 类型） |
| `RiverNodeType` | 河流节点类型枚举（Source/Confluence/Outlet/Intermediate） |
| `RiverReach` | 河段（起止节点 + 长度 + 坡度 + Strahler 河序） |
| `RiverNetwork` | 河网（节点表 + 河段表 + 出口 ID） |
| `FlowDirection` | D8 流向矩阵 |
| `FlowAccumulation` | 汇流累积矩阵 |

### 几何运算 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `polygon_area` | `(Polygon) -> Double` | 多边形面积（Shoelace 公式） |
| `polygon_centroid` | `(Polygon) -> XYPoint` | 多边形形心 |
| `xy_distance` | `(XYPoint, XYPoint) -> Double` | 两点距离 |
| `polyline_length` | `(Polyline) -> Double` | 多段线长度 |
| `BasinBoundary::from_polygon` | `(name~, Polygon) -> BasinBoundary` | 从多边形构造流域边界 |

### DEM 处理 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `DEMGrid::uniform` | `(nx~, ny~, dx~, dy~, ...) -> DEMGrid` | 构造均匀高程 DEM |
| `DEMGrid::get_elevation` | `(Self, Int, Int) -> Double` | 获取某点高程 |
| `DEMGrid::set_elevation` | `(Self, Int, Int, Double) -> Unit` | 设置某点高程 |
| `DEMGrid::has_data` | `(Self, Int, Int) -> Bool` | 判断是否有数据 |
| `compute_flow_direction` | `(DEMGrid) -> FlowDirection` | D8 流向分析 |
| `compute_flow_accumulation` | `(FlowDirection) -> FlowAccumulation` | 汇流累积（BFS 拓扑排序） |
| `delineate_watershed` | `(FlowDirection, outlet_i~, outlet_j~) -> Array[(Int, Int)]` | 流域 delineation（反向 BFS） |
| `watershed_area` | `(DEMGrid, Array[(Int, Int)]) -> Double` | 流域面积（km²） |
| `extract_river_network` | `(FlowAccumulation, threshold~) -> Array[(Int, Int)]` | 河网提取 |
| `dem_stats` | `(DEMGrid) -> (Double, Double, Double, Double)` | DEM 统计（最小/最大/均值/计数） |
| `synthetic_dem` | `(nx~, ny~, dx~?, dy~?) -> DEMGrid` | 生成合成 DEM |

### 河网处理 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `RiverNetwork::new` | `() -> RiverNetwork` | 构造空河网 |
| `RiverNetwork::add_node` | `(Self, RiverNode) -> Unit` | 添加节点 |
| `RiverNetwork::add_reach` | `(Self, RiverReach) -> Unit` | 添加河段 |
| `RiverNetwork::upstream_reaches` | `(Self, Int) -> Array[RiverReach]` | 获取上游河段 |
| `RiverNetwork::downstream_reaches` | `(Self, Int) -> Array[RiverReach]` | 获取下游河段 |
| `RiverNetwork::compute_strahler_orders` | `(Self) -> Unit` | 计算 Strahler 河序 |
| `RiverNetwork::topological_order` | `(Self) -> Array[Int]` | 拓扑排序（汇流顺序） |
| `RiverNetwork::trace_to_sources` | `(Self, Int) -> Array[Int]` | 追溯源头 |
| `RiverNetwork::trace_to_outlet` | `(Self, Int) -> Array[Int]` | 追溯出口 |
| `RiverNetwork::stats` | `(Self) -> String` | 河网统计信息 |
| `extract_network_from_dem` | `(DEMGrid, FlowAccumulation, threshold~) -> RiverNetwork` | 从 DEM 提取河网拓扑 |

---

## 洪水淹没推演

> 模块 `flood/`，提供 2D SWE 淹没仿真、风险图生成、损失评估功能。
> 包含 `flood/inundation.mbt`（淹没推演）、`flood/risk_map.mbt`（风险图）、`flood/damage.mbt`（损失评估）。

### 淹没推演 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `InundationConfig::default` | `() -> InundationConfig` | 默认配置 |
| `dem_to_swe_grid` | `(DEMGrid, h0~?, manning~?) -> SWEGrid2D` | 从 DEM 构造 SWE 网格 |
| `set_inflow` | `(SWEGrid2D, i0~, i1~, j0~, j1~, h_value~, ...) -> SWEGrid2D` | 设置入流边界 |
| `simulate_inundation` | `(SWEGrid2D, InundationConfig) -> InundationResult` | 运行淹没仿真 |
| `extract_inundation_extent` | `(InundationResult, threshold~?) -> Array[(Int, Int)]` | 提取淹没范围 |
| `inundation_stats` | `(InundationResult) -> (Int, Double, Double, Double)` | 淹没统计 |
| `synthetic_flood_scenario` | `(nx~?, ny~?, dx~?, dy~?) -> (SWEGrid2D, InundationConfig)` | 合成洪水场景 |

### 风险图 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `classify_risk` | `(Double, Double) -> RiskLevel` | 风险分类（水深+流速） |
| `generate_risk_map` | `(Array[Double], Array[Double], Array[Double], nx~, ny~) -> RiskMap` | 生成风险图 |
| `generate_risk_map_depth_only` | `(Array[Double], nx~, ny~) -> RiskMap` | 仅水深版风险图 |
| `risk_statistics` | `(RiskMap) -> RiskStatistics` | 风险统计 |
| `to_ascii_map` | `(RiskMap, max_width~?) -> String` | ASCII 艺术风险图 |

### 损失评估 API

| 函数 | 签名 | 说明 |
|------|------|------|
| `LandUseMap::uniform` | `(nx~, ny~, land_type~, unit_value~?) -> LandUseMap` | 均匀土地利用图 |
| `LandUseMap::set_region` | `(Self, i0~, i1~, j0~, j1~, land_type~, unit_value~) -> Unit` | 设置区域土地利用 |
| `damage_ratio` | `(Double, LandUseType) -> Double` | 水深-损失率曲线（JRC） |
| `estimate_damage` | `(Array[Double], LandUseMap) -> DamageResult` | 损失评估 |
| `synthetic_land_use` | `(nx~, ny~) -> LandUseMap` | 合成土地利用图 |

### 数据类型

| 类型 | 说明 |
|------|------|
| `InundationConfig` | 淹没推演配置（dt/n_steps/cfl/depth_threshold/output_interval） |
| `InundationResult` | 淹没推演结果（max_depth/final_depth/arrival_time/duration/inundated_area） |
| `RiskLevel` | 风险等级枚举（Safe/LowRisk/ModerateRisk/HighRisk/ExtremeRisk） |
| `RiskMap` | 风险图（levels/max_depth/max_velocity） |
| `RiskStatistics` | 风险统计（各等级计数/占比） |
| `LandUseType` | 土地利用类型枚举（Residential/Commercial/Industrial/Agricultural/Forest/Water） |
| `LandUseMap` | 土地利用图（types/unit_value） |
| `DamageResult` | 损失评估结果（total_damage/各类型损失/damaged_cells） |

---

*生成时间：2026-09-03｜MoonBit 0.1.20260827｜230+ 个公开函数｜415+ 测试通过｜V0.8.1*