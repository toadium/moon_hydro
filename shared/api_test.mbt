///|
/// API层 + JSON序列化服务测试
///
/// 测试JSON往返、端到端仿真服务、错误处理

///|
test "to_json_string 基本序列化" {
  let params = XinanjiangParams::default()
  let json_str = to_json_string(params)
  // 应包含字段名
  assert_true(json_str.contains("wm"))
  assert_true(json_str.contains("120"))
}

///|
test "XajRunRequest JSON往返" {
  let request : XajRunRequest = {
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: [
      { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
      { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    ],
    observed: [],
  }
  let json_str = to_json_string(request)
  let parsed = parse_xaj_request(json_str)
  assert_true((parsed.area - 100.0).abs() < 0.001)
  assert_true((parsed.dt - 1.0).abs() < 0.001)
  assert_eq(parsed.forcings.length(), 2)
  assert_true((parsed.forcings[0].rainfall - 10.0).abs() < 0.001)
  assert_eq(parsed.forcings[1].datetime, "t1")
}

///|
test "run_xaj 新安江仿真服务" {
  let request : XajRunRequest = {
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: mock_flood_rainfall(duration=5),
    observed: [],
  }
  let response = run_xaj(request)
  assert_true(response.runoff_series.length() > 0)
  assert_true(response.state_count > 0)
}

///|
test "xaj_json_endpoint 端到端JSON" {
  let request : XajRunRequest = {
    params: XinanjiangParams::default(),
    area: 50.0,
    dt: 1.0,
    forcings: [
      { rainfall: 15.0, evaporation: 2.0, datetime: "t0" },
      { rainfall: 25.0, evaporation: 1.0, datetime: "t1" },
    ],
    observed: [],
  }
  let request_json = to_json_string(request)
  let response_json = xaj_json_endpoint(request_json)
  // 响应应包含runoff_series字段
  assert_true(response_json.contains("runoff_series"))
  assert_true(response_json.contains("nse"))
  assert_true(response_json.contains("kge"))
}

///|
test "SweRunRequest JSON往返" {
  let grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=0.5)
  let config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 10,
    cfl: 0.4,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let request : SweRunRequest = { grid, config }
  let json_str = to_json_string(request)
  let parsed = parse_swe_request(json_str)
  assert_eq(parsed.grid.nx, 10)
  assert_true((parsed.grid.dx - 1.0).abs() < 0.001)
  assert_eq(parsed.config.n_steps, 10)
}

///|
test "run_swe SWE仿真服务" {
  let grid = SWEGrid1D::uniform(nx=20, dx=1.0, h0=1.0)
  let config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 20,
    cfl: 0.4,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let request : SweRunRequest = { grid, config }
  let response = run_swe(request)
  assert_eq(response.max_depth.length(), 20)
  assert_eq(response.final_h.length(), 20)
}

///|
test "swe_json_endpoint 端到端JSON" {
  let grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=1.0)
  let config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 5,
    cfl: 0.4,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let request : SweRunRequest = { grid, config }
  let request_json = to_json_string(request)
  let response_json = swe_json_endpoint(request_json)
  assert_true(response_json.contains("max_depth"))
  assert_true(response_json.contains("stable"))
}

///|
test "EvaluateRequest JSON往返" {
  let request : EvaluateRequest = {
    observed: [10.0, 50.0, 30.0, 20.0],
    simulated: [12.0, 48.0, 28.0, 18.0],
    forecast_type: ForecastType::FloodProcess,
  }
  let json_str = to_json_string(request)
  let parsed = parse_evaluate_request(json_str)
  assert_eq(parsed.observed.length(), 4)
  assert_eq(parsed.simulated.length(), 4)
  assert_true(parsed.forecast_type is ForecastType::FloodProcess)
}

///|
test "run_evaluate 评价服务" {
  let request : EvaluateRequest = {
    observed: [10.0, 50.0, 30.0, 20.0, 10.0],
    simulated: [10.0, 50.0, 30.0, 20.0, 10.0],
    forecast_type: ForecastType::FloodProcess,
  }
  let response = run_evaluate(request)
  // 完美匹配：NSE≈1
  assert_true(response.nse > 0.99)
  // 洪峰误差≈0
  assert_true(response.peak_error.abs() < 0.001)
}

///|
test "evaluate_json_endpoint 端到端JSON" {
  let request : EvaluateRequest = {
    observed: [10.0, 50.0, 30.0, 20.0],
    simulated: [12.0, 48.0, 28.0, 18.0],
    forecast_type: ForecastType::FloodPeak,
  }
  let request_json = to_json_string(request)
  let response_json = evaluate_json_endpoint(request_json)
  assert_true(response_json.contains("nse"))
  assert_true(response_json.contains("kge"))
  assert_true(response_json.contains("grade"))
}

///|
test "CalibrateRequest JSON往返" {
  let request : CalibrateRequest = {
    config: {
      max_iter: 10,
      r: 0.3,
      seed: 42,
      target_metric: "nse",
      params: default_calib_params(),
      max_no_improve: 100,
    },
    area: 100.0,
    dt: 1.0,
    forcings: mock_flood_rainfall(duration=5),
    observed: [1.0, 2.0, 3.0, 4.0, 5.0],
  }
  let json_str = to_json_string(request)
  let parsed = parse_calibrate_request(json_str)
  assert_eq(parsed.config.max_iter, 10)
  assert_true((parsed.area - 100.0).abs() < 0.001)
  assert_eq(parsed.observed.length(), 5)
}

///|
test "run_calibrate 率定服务" {
  let forcings = mock_flood_rainfall(duration=10)
  let true_params = XinanjiangParams::default()
  let model = XinanjiangModel::new(params=true_params, area=100.0, dt=1.0)
  let observed = model.run(forcings).runoff_series
  let request : CalibrateRequest = {
    config: {
      max_iter: 20,
      r: 0.3,
      seed: 42,
      target_metric: "nse",
      params: [
        { name: "wm", lower: 80.0, upper: 160.0, value: 100.0 },
        { name: "b", lower: 0.2, upper: 0.6, value: 0.25 },
      ],
      max_no_improve: 100,
    },
    area: 100.0,
    dt: 1.0,
    forcings,
    observed,
  }
  let response = run_calibrate(request)
  assert_true(response.best_metric > 0.0)
  assert_true(response.n_iter > 0)
}

///|
test "ApiResponse::ok 成功响应构造" {
  let response : ApiResponse[Int] = ApiResponse::ok(42)
  assert_true(response.success)
  assert_true(response.data is Some(42))
  assert_eq(response.error, "")
}

///|
test "ApiResponse::err 错误响应构造" {
  let response : ApiResponse[Int] = ApiResponse::err(error="参数错误")
  assert_false(response.success)
  assert_true(response.data is None)
  assert_eq(response.error, "参数错误")
}

///|
test "CoupleRunRequest JSON往返" {
  let request : CoupleRunRequest = {
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: mock_flood_rainfall(duration=3),
    swe_grid: SWEGrid1D::uniform(nx=20, dx=1.0, h0=0.5),
    coupling_params: CouplingParams::default(),
    swe_dt: 0.005,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let json_str = to_json_string(request)
  let parsed = parse_couple_request(json_str)
  assert_true((parsed.area - 100.0).abs() < 0.001)
  assert_eq(parsed.swe_grid.nx, 20)
  assert_true((parsed.swe_dt - 0.005).abs() < 0.0001)
}

///|
test "run_couple 耦合仿真服务" {
  let request : CoupleRunRequest = {
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: mock_flood_rainfall(duration=5),
    swe_grid: SWEGrid1D::uniform(nx=30, dx=1.0, h0=0.5),
    coupling_params: {
      lateral_inflow_coeff: 0.8,
      feedback_coeff: 0.01,
      cell_area: 100.0,
      river_cells: [10, 11, 12, 13, 14],
      base_flow_threshold: 0.3,
      n_river_cells: 5,
    },
    swe_dt: 0.005,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let response = run_couple(request)
  assert_true(response.lateral_inflow_series.length() > 0)
  assert_true(response.water_level_series.length() > 0)
}

///|
test "couple_json_endpoint 端到端JSON" {
  let request : CoupleRunRequest = {
    params: XinanjiangParams::default(),
    area: 50.0,
    dt: 1.0,
    forcings: mock_flood_rainfall(duration=3),
    swe_grid: SWEGrid1D::uniform(nx=10, dx=1.0, h0=0.5),
    coupling_params: CouplingParams::default(),
    swe_dt: 0.005,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let request_json = to_json_string(request)
  let response_json = couple_json_endpoint(request_json)
  assert_true(response_json.contains("lateral_inflow_series"))
  assert_true(response_json.contains("water_level_series"))
  assert_true(response_json.contains("stable"))
}
