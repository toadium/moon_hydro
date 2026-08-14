///|
/// 沐澜水文 backend 入口 - V0.3
///
/// CLI演示 + JSON仿真服务库 + 2D SWE + 时间序列分析
/// JSON端点函数在shared/serde_bind.mbt中定义，可被HTTP层直接调用
fn main raise {
  // ===== 新安江模型仿真 =====
  let xaj_model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "2026-09-01T00:00" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "2026-09-01T01:00" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "2026-09-01T02:00" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "2026-09-01T03:00" },
    { rainfall: 30.0, evaporation: 2.0, datetime: "2026-09-01T04:00" },
  ]
  let xaj_result = xaj_model.run(forcings)
  println("===== 沐澜水文 V0.3 - 新安江模型仿真 =====")
  println("流域面积: 100.0 km², 时段: 1.0 h")
  println("降雨序列: [10, 20, 5, 0, 30] mm")
  println("径流序列: \{Repr(xaj_result.runoff_series)}")

  // ===== JSON API 演示 =====
  println("\n===== JSON API 端到端演示 =====")
  let xaj_request : @shared.XajRunRequest = {
    params: @shared.XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings,
  }
  let request_json = @shared.to_json_string(xaj_request)
  let req_preview = if request_json.length() > 200 {
    request_json[0:200].to_owned() + "..."
  } else {
    request_json
  }
  println("请求JSON: \{req_preview}")
  let response_json = @shared.xaj_json_endpoint(request_json)
  let resp_preview = if response_json.length() > 200 {
    response_json[0:200].to_owned() + "..."
  } else {
    response_json
  }
  println("响应JSON: \{resp_preview}")

  // ===== SWE浅水方程仿真 =====
  let swe_grid = @shared.SWEGrid1D::uniform(nx=50, dx=1.0, h0=1.0)
  let swe_config : @shared.SWESolverConfig = {
    dt: 0.01,
    n_steps: 50,
    cfl: 0.4,
    boundary: {
      left: @shared.SWEBoundaryType::SolidWall,
      right: @shared.SWEBoundaryType::Transmissive,
    },
  }
  let swe_result = swe_grid.run(swe_config)
  println("\n===== SWE浅水方程仿真 =====")
  println("网格: 50单元, dx=1.0m, 初始水深=1.0m")
  println("稳定性: \{swe_result.stable}")
  println("最大水深[25]: \{Repr(swe_result.max_depth[25])}")

  // ===== SWE JSON API演示 =====
  let swe_request : @shared.SweRunRequest = {
    grid: swe_grid,
    config: swe_config,
  }
  let swe_response_json = @shared.swe_json_endpoint(
    @shared.to_json_string(swe_request),
  )
  let swe_resp_preview = if swe_response_json.length() > 200 {
    swe_response_json[0:200].to_owned() + "..."
  } else {
    swe_response_json
  }
  println("SWE响应JSON: \{swe_resp_preview}")

  // ===== 新安江+SWE耦合仿真 =====
  let coupling_params : @shared.CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    base_flow_threshold: 0.3,
    n_river_cells: 10,
  }
  let swe_boundary : @shared.SWEBoundary = {
    left: @shared.SWEBoundaryType::SolidWall,
    right: @shared.SWEBoundaryType::Transmissive,
  }
  let coupling_grid = @shared.SWEGrid1D::uniform(nx=50, dx=1.0, h0=0.5)
  let coupling_result = @shared.couple_run(
    xaj_model, coupling_grid, coupling_params, swe_boundary, forcings, 0.005,
  )
  println("\n===== 新安江+SWE耦合仿真 =====")
  println("耦合稳定性: \{coupling_result.stable}")
  println("侧向入流过程: \{Repr(coupling_result.lateral_inflow_series)}")
  println("河道水位过程: \{Repr(coupling_result.water_level_series)}")

  // ===== 评价API演示 =====
  println("\n===== 评价API演示 =====")
  let obs = xaj_result.runoff_series
  let sim = xaj_result.runoff_series
  let eval_request : @shared.EvaluateRequest = {
    observed: obs,
    simulated: sim,
    forecast_type: @shared.ForecastType::FloodProcess,
  }
  let eval_response_json = @shared.evaluate_json_endpoint(
    @shared.to_json_string(eval_request),
  )
  println("评价响应JSON: \{eval_response_json}")

  // ===== 2D SWE浅水方程仿真 =====
  println("\n===== 2D SWE浅水方程仿真 =====")
  let grid2d = @shared.SWEGrid2D::uniform(nx=20, ny=20, dx=1.0, dy=1.0, h0=0.1)
  // dam-break初始条件：左半水深2.0m
  ignore(grid2d.set_block(i0=0, i1=10, j0=0, j1=20, h_value=2.0))
  let config2d : @shared.SWE2DSolverConfig = {
    dt: 0.005,
    n_steps: 30,
    cfl: 0.3,
    boundary: @shared.SWE2DBoundary::SolidWall,
  }
  let result2d = grid2d.run(config2d)
  println("2D网格: 20×20, dam-break(左2.0m/右0.1m)")
  println(
    "稳定性: \{result2d.stable}, 实际步数: \{result2d.n_steps_actual}",
  )
  let mut max_h = 0.0
  for k in 0..<400 {
    if result2d.max_depth[k] > max_h {
      max_h = result2d.max_depth[k]
    }
  }
  println("全域最大水深: \{Repr(max_h)}")

  // ===== 时间序列分析演示 =====
  println("\n===== 时间序列分析演示 =====")
  let runoff = xaj_result.runoff_series
  let stats = @shared.ts_stats(runoff)
  println(
    "径流序列统计: 均值=\{Repr(stats.mean)}, 标准差=\{Repr(stats.stddev)}",
  )
  println(
    "  范围=[\{Repr(stats.min_val)}, \{Repr(stats.max_val)}], 趋势=\{Repr(stats.trend)}",
  )
  let peaks = @shared.detect_peaks(runoff)
  println("洪峰位置: \{Repr(peaks)}")
  let baseflow = @shared.baseflow_separation(runoff)
  let bf_preview = if baseflow.length() > 5 {
    "[\{Repr(baseflow[0])}, \{Repr(baseflow[1])}, ...] (共\{baseflow.length()}项)"
  } else {
    "\{Repr(baseflow)}"
  }
  println("基流分离: \{bf_preview}")
}
