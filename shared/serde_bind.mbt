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
pub fn run_xaj(request : XajRunRequest) -> XajRunResponse raise {
  // T33修复：输入校验（S8修复：abort改为raise，可在端点捕获）
  if request.area <= 0.0 || request.dt <= 0.0 {
    raise InvalidInput("run_xaj: area和dt必须为正数")
  }
  if request.forcings.length() == 0 {
    raise InvalidInput("run_xaj: forcings不能为空")
  }
  let model = XinanjiangModel::new(
    params=request.params,
    area=request.area,
    dt=request.dt,
  )
  let result = model.run(request.forcings)
  // T32修复：观测长度与径流长度不匹配时不计算指标，避免静默返回错误值
  let has_valid_obs = request.observed.length() > 0 &&
    request.observed.length() == result.runoff_series.length()
  let (nse_val, kge_val, pbias_val) = if has_valid_obs {
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
pub fn run_swe(request : SweRunRequest) -> SweRunResponse raise {
  // T33修复：输入校验（S8修复：abort改为raise）
  if request.grid.nx <= 0 || request.grid.dx <= 0.0 {
    raise InvalidInput("run_swe: 网格参数nx和dx必须为正")
  }
  if request.config.dt <= 0.0 || request.config.n_steps < 0 {
    raise InvalidInput("run_swe: 求解器参数dt和n_steps必须为正")
  }
  let result = request.grid.run(request.config)
  let n = result.h_series.length()
  let final_h = if n > 0 { result.h_series[n - 1] } else { [] }
  let final_hu = if n > 0 { result.hu_series[n - 1] } else { [] }
  { max_depth: result.max_depth, stable: result.stable, final_h, final_hu }
}

///|
/// 运行耦合仿真
pub fn run_couple(request : CoupleRunRequest) -> CoupleRunResponse raise {
  // T33修复：输入校验（S8修复：abort改为raise）
  if request.area <= 0.0 || request.dt <= 0.0 {
    raise InvalidInput("run_couple: area和dt必须为正数")
  }
  if request.forcings.length() == 0 {
    raise InvalidInput("run_couple: forcings不能为空")
  }
  if request.swe_dt <= 0.0 {
    raise InvalidInput("run_couple: swe_dt必须为正")
  }
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
pub fn run_calibrate(request : CalibrateRequest) -> CalibrateResponse raise {
  // T33修复：输入校验（S8修复：abort改为raise）
  if request.area <= 0.0 || request.dt <= 0.0 {
    raise InvalidInput("run_calibrate: area和dt必须为正数")
  }
  if request.forcings.length() == 0 {
    raise InvalidInput("run_calibrate: forcings不能为空")
  }
  // T34修复：根据algorithm字段分派DDS或SCE-UA
  if request.algorithm == "sceua" || request.algorithm == "sce-ua" {
    let sceua_cfg = match request.sceua_config {
      Some(c) => c
      None => SCEUAConfig::default()
    }
    let result = sceua_calibrate(
      sceua_cfg,
      area=request.area,
      dt=request.dt,
      request.forcings,
      request.observed,
    )
    return {
      best_params: result.best_params,
      best_metric: result.best_metric,
      n_iter: result.n_iter,
      converged: result.converged,
    }
  }
  // DDS算法需要config
  let dds_cfg = match request.config {
    Some(c) => c
    None => raise InvalidInput("run_calibrate: DDS算法需要config字段")
  }
  let result = dds_calibrate(
    dds_cfg,
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
  // S8修复：捕获仿真输入错误，返回错误响应JSON而非崩溃
  try {
    let response = run_xaj(request)
    to_json_string(response)
  } catch {
    InvalidInput(msg) =>
      to_json_string(
        (ApiResponse::err(error=msg) : ApiResponse[XajRunResponse]),
      )
    other => raise other
  }
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（SWE）
pub fn swe_json_endpoint(json_str : String) -> String raise {
  let request = parse_swe_request(json_str)
  try {
    let response = run_swe(request)
    to_json_string(response)
  } catch {
    InvalidInput(msg) =>
      to_json_string(
        (ApiResponse::err(error=msg) : ApiResponse[SweRunResponse]),
      )
    other => raise other
  }
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（耦合）
pub fn couple_json_endpoint(json_str : String) -> String raise {
  let request = parse_couple_request(json_str)
  try {
    let response = run_couple(request)
    to_json_string(response)
  } catch {
    InvalidInput(msg) =>
      to_json_string(
        (ApiResponse::err(error=msg) : ApiResponse[CoupleRunResponse]),
      )
    other => raise other
  }
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（率定）
pub fn calibrate_json_endpoint(json_str : String) -> String raise {
  let request = parse_calibrate_request(json_str)
  try {
    let response = run_calibrate(request)
    to_json_string(response)
  } catch {
    InvalidInput(msg) =>
      to_json_string(
        (ApiResponse::err(error=msg) : ApiResponse[CalibrateResponse]),
      )
    other => raise other
  }
}

///|
/// 端到端：JSON请求字符串 → JSON响应字符串（评价）
pub fn evaluate_json_endpoint(json_str : String) -> String raise {
  let request = parse_evaluate_request(json_str)
  let response = run_evaluate(request)
  to_json_string(response)
}
