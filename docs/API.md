# 沐澜水文 · API 文档

> 自动生成自 `moon info` 接口文件，共 106 个公开函数

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

*生成时间：2026-08-14｜MoonBit 0.1.20260713｜106 个公开函数*