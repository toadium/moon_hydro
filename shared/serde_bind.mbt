///|
/// JSON序列化/反序列化服务层
///
/// 提供各仿真服务的JSON接口：
/// - parse_xaj_request: JSON → XajRunRequest
/// - run_xaj: XajRunRequest → XajRunResponse
/// - to_json_string: 任意ToJson类型 → JSON字符串
///
/// 后端CLI或HTTP层通过本模块调用仿真服务

///|
/// 将任意ToJson类型序列化为JSON字符串
pub fn[T : ToJson] to_json_string(value : T) -> String {
  let json = value.to_json()
  json.stringify()
}

///|
/// 从JSON字符串解析为新安江仿真请求
pub fn parse_xaj_request(json_str : String) -> XajRunRequest raise {
  let json = @json.parse(json_str)
  @json.from_json(json)
}

///|
/// 从JSON字符串解析为SWE仿真请求
pub fn parse_swe_request(json_str : String) -> SweRunRequest raise {
  let json = @json.parse(json_str)
  @json.from_json(json)
}

///|
/// 从JSON字符串解析为耦合仿真请求
pub fn parse_couple_request(json_str : String) -> CoupleRunRequest raise {
  let json = @json.parse(json_str)
  @json.from_json(json)
}

///|
/// 从JSON字符串解析为率定请求
pub fn parse_calibrate_request(json_str : String) -> CalibrateRequest raise {
  let json = @json.parse(json_str)
  @json.from_json(json)
}

///|
/// 从JSON字符串解析为评价请求
pub fn parse_evaluate_request(json_str : String) -> EvaluateRequest raise {
  let json = @json.parse(json_str)
  @json.from_json(json)
}

///|
/// 运行新安江仿真
pub fn run_xaj(request : XajRunRequest) -> XajRunResponse {
  let model = XinanjiangModel::new(
    params=request.params,
    area=request.area,
    dt=request.dt,
  )
  let result = model.run(request.forcings)
  let (nse_val, kge_val, pbias_val) = if request.observed.length() > 0 {
    (
      nse(request.observed, result.runoff_series),
      kge(request.observed, result.runoff_series),
      pbias(request.observed, result.runoff_series),
    )
  } else {
    (0.0, 0.0, 0.0)
  }
  {
    runoff_series: result.runoff_series,
    nse: nse_val,
    kge: kge_val,
    pbias: pbias_val,
    state_count: result.state_series.length(),
  }
}

///|
/// 运行SWE仿真
pub fn run_swe(request : SweRunRequest) -> SweRunResponse {
  let result = request.grid.run(request.config)
  let n = result.h_series.length()
  let final_h = if n > 0 { result.h_series[n - 1] } else { [] }
  let final_hu = if n > 0 { result.hu_series[n - 1] } else { [] }
  { max_depth: result.max_depth, stable: result.stable, final_h, final_hu }
}

///|
/// 运行耦合仿真
pub fn run_couple(request : CoupleRunRequest) -> CoupleRunResponse {
  let xaj_model = XinanjiangModel::new(
    params=request.params,
    area=request.area,
    dt=request.dt,
  )
  let result = couple_run(
    xaj_model,
    request.swe_grid,
    request.coupling_params,
    request.boundary,
    request.forcings,
    request.swe_dt,
  )
  // P1-3修复：从xaj_states提取径流过程
  let runoff_series : Array[Double] = []
  for state in result.xaj_states {
    runoff_series.push(state.q)
  }
  {
    lateral_inflow_series: result.lateral_inflow_series,
    water_level_series: result.water_level_series,
    stable: result.stable,
    runoff_series,
  }
}

///|
/// 运行参数率定
pub fn run_calibrate(request : CalibrateRequest) -> CalibrateResponse {
  let result = dds_calibrate(
    request.config,
    request.forcings,
    request.observed,
    area=request.area,
    dt=request.dt,
  )
  {
    best_params: result.best_params,
    best_metric: result.best_metric,
    n_iter: result.n_iter,
    converged: result.converged,
  }
}

///|
/// 运行评价指标计算
pub fn run_evaluate(request : EvaluateRequest) -> EvaluateResponse {
  let result = evaluate(
    request.observed,
    request.simulated,
    forecast_type=request.forecast_type,
  )
  {
    nse: result.nse,
    kge: result.kge,
    pbias: result.pbias,
    rmse: result.rmse,
    r_squared: result.r_squared,
    peak_error: result.peak_error,
    peak_time_error: result.peak_time_error,
    volume_error: result.volume_error,
    grade: result.grade,
    grade_nse: result.grade_nse,
    grade_pbias: result.grade_pbias,
  }
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（新安江）
pub fn xaj_json_endpoint(json_str : String) -> String raise {
  let request = parse_xaj_request(json_str)
  let response = run_xaj(request)
  to_json_string(response)
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（SWE）
pub fn swe_json_endpoint(json_str : String) -> String raise {
  let request = parse_swe_request(json_str)
  let response = run_swe(request)
  to_json_string(response)
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（耦合）
pub fn couple_json_endpoint(json_str : String) -> String raise {
  let request = parse_couple_request(json_str)
  let response = run_couple(request)
  to_json_string(response)
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（率定）
pub fn calibrate_json_endpoint(json_str : String) -> String raise {
  let request = parse_calibrate_request(json_str)
  let response = run_calibrate(request)
  to_json_string(response)
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（评价）
pub fn evaluate_json_endpoint(json_str : String) -> String raise {
  let request = parse_evaluate_request(json_str)
  let response = run_evaluate(request)
  to_json_string(response)
}
