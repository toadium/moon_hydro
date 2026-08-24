///|
/// API请求/响应类型定义
///
/// V0.2服务层：定义各仿真服务的请求/响应结构
/// 支持JSON序列化，可通过CLI或HTTP调用

///|
/// 新安江仿真请求
pub(all) struct XajRunRequest {
  params : XinanjiangParams
  area : Double
  dt : Double
  forcings : Array[ForcingData]
  observed : Array[Double]
} derive(Debug, ToJson, FromJson)

///|
/// 新安江仿真响应
pub(all) struct XajRunResponse {
  runoff_series : Array[Double]
  nse : Double
  kge : Double
  pbias : Double
  state_count : Int
} derive(Debug, ToJson, FromJson)

///|
/// SWE仿真请求
pub(all) struct SweRunRequest {
  grid : SWEGrid1D
  config : SWESolverConfig
} derive(Debug, ToJson, FromJson)

///|
/// SWE仿真响应
pub(all) struct SweRunResponse {
  max_depth : Array[Double]
  stable : Bool
  final_h : Array[Double]
  final_hu : Array[Double]
} derive(Debug, ToJson, FromJson)

///|
/// 耦合仿真请求
pub(all) struct CoupleRunRequest {
  params : XinanjiangParams
  area : Double
  dt : Double
  forcings : Array[ForcingData]
  swe_grid : SWEGrid1D
  coupling_params : CouplingParams
  swe_dt : Double
  boundary : SWEBoundary
} derive(Debug, ToJson, FromJson)

///|
/// 耦合仿真响应
pub(all) struct CoupleRunResponse {
  lateral_inflow_series : Array[Double]
  water_level_series : Array[Double]
  stable : Bool
  runoff_series : Array[Double]
} derive(Debug, ToJson, FromJson)

///|
/// 仿真输入错误（S8修复：替代abort，可在JSON端点捕获返回错误响应）
pub(all) suberror SimError {
  InvalidInput(String) // 非法输入参数
} derive(Debug, ToJson, FromJson)

///|
/// 率定请求
pub(all) struct CalibrateRequest {
  config : DDSConfig? // S修复：DDSConfig改为可选，algorithm="sceua"时不需要
  area : Double
  dt : Double
  forcings : Array[ForcingData]
  observed : Array[Double]
  algorithm : String // T34修复：支持"dds"或"sceua"
  sceua_config : SCEUAConfig? // SCE-UA配置（algorithm="sceua"时使用）
} derive(Debug, ToJson, FromJson)

///|
/// 率定响应
pub(all) struct CalibrateResponse {
  best_params : Array[CalibParam]
  best_metric : Double
  n_iter : Int
  converged : Bool
} derive(Debug, ToJson, FromJson)

///|
/// 评价请求
pub(all) struct EvaluateRequest {
  observed : Array[Double]
  simulated : Array[Double]
  forecast_type : ForecastType
} derive(Debug, ToJson, FromJson)

///|
/// 评价响应
pub(all) struct EvaluateResponse {
  nse : Double
  kge : Double
  pbias : Double
  rmse : Double
  r_squared : Double
  peak_error : Double
  peak_time_error : Int
  volume_error : Double
  grade : ForecastGrade
  grade_nse : ForecastGrade
  grade_pbias : ForecastGrade
} derive(Debug, ToJson, FromJson)

///|
/// 统一API响应包装
pub(all) struct ApiResponse[T] {
  success : Bool
  data : T?
  error : String
} derive(Debug, ToJson, FromJson)

///|
/// 构造成功响应
pub fn[T] ApiResponse::ok(data : T) -> ApiResponse[T] {
  { success: true, data: Some(data), error: "" }
}

///|
/// 构造错误响应
pub fn[T] ApiResponse::err(error~ : String) -> ApiResponse[T] {
  { success: false, data: None, error }
}
