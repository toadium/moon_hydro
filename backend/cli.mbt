///|
/// 沐澜水文 CLI 子命令模块
///
/// 提供率定、校验、批量仿真、不确定性分析等子命令函数。
/// 各子命令返回结构化结果，可序列化为JSON供外部调用。
/// 由于MoonBit标准库暂无argv模块，main函数作为分发器调用各子命令。

///|
/// CLI子命令结果
struct CliResult {
  command : String
  success : Bool
  message : String
  details : String
}

///|
/// 重复字符串n次
fn repeat_str(s : String, n : Int) -> String {
  let mut result = ""
  for _ in 0..<n {
    result = result + s
  }
  result
}

///|
/// 打印CLI结果
fn print_cli_result(result : CliResult) -> Unit {
  let status = if result.success { "[OK]" } else { "[FAIL]" }
  println("\{status} [\{result.command}] \{result.message}")
  if result.details.length() > 0 {
    println(result.details)
  }
}

///|
/// 子命令: help - 显示帮助信息
fn cli_help() -> Unit {
  println("沐澜水文 V0.4 - 命令行子命令")
  println(repeat_str("=", 50))
  println("可用子命令:")
  println("  demo        完整功能演示(默认)")
  println("  sim         单次新安江模型仿真")
  println("  calibrate   SCE-UA参数率定")
  println("  dds         DDS动态维度搜索率定")
  println("  validate    流域校验(闽江/飞云江/青弋江)")
  println("  batch       批量多流域仿真")
  println("  ensemble    集合仿真")
  println("  uncertainty 蒙特卡洛不确定性分析")
  println("  sensitivity 参数敏感性扫描")
  println("  swe         1D/2D浅水方程仿真")
  println("  coupling    新安江+SWE耦合仿真")
  println("  timeseries  时间序列分析")
  println("  metrics     扩展评价指标计算")
  println("  json        JSON API端到端演示")
  println("  bench       性能基准测试")
  println("  help        显示此帮助信息")
  println("")
  println("用法: moon run -- [subcommand]")
  println(
    "注意: 当前MoonBit标准库暂无argv模块，默认运行demo子命令",
  )
}

///|
/// 子命令: sim - 单次新安江模型仿真
fn cli_sim() -> CliResult {
  let model = @shared.XinanjiangModel::new(
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
  let result = model.run(forcings)
  let runoff_str = result.runoff_series.map(fn(x) { x.to_string() }).join(", ")
  {
    command: "sim",
    success: true,
    message: "新安江模型仿真完成(5步)",
    details: "径流序列: [\{runoff_str}]",
  }
}

///|
/// 子命令: calibrate - SCE-UA参数率定
fn cli_calibrate() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 15.0, evaporation: 1.5, datetime: "t2" },
    { rainfall: 5.0, evaporation: 2.0, datetime: "t3" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t4" },
  ]
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let observed = model.run(forcings).runoff_series
  let cfg : @shared.SCEUAConfig = {
    max_iter: 50,
    n_complexes: 4,
    complex_size: 0,
    cce_iterations: 0,
    seed: 42,
    target_metric: "nse",
    params: @shared.default_calib_params(),
    convergence_threshold: 0.000001,
    max_no_improve: 20,
  }
  let result = @shared.sceua_calibrate(
    cfg,
    area=100.0,
    dt=1.0,
    forcings,
    observed,
  )
  let detail = "最优NSE: \{result.best_metric}, 迭代: \{result.n_iter}, 函数调用: \{result.n_function_evals}, 收敛: \{result.converged}"
  {
    command: "calibrate",
    success: true,
    message: "SCE-UA率定完成(11参数)",
    details: detail,
  }
}

///|
/// 子命令: dds - DDS动态维度搜索率定
fn cli_dds() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 12.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 18.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 8.0, evaporation: 1.5, datetime: "t2" },
    { rainfall: 3.0, evaporation: 1.0, datetime: "t3" },
  ]
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=200.0,
    dt=1.0,
  )
  let observed = model.run(forcings).runoff_series
  let cfg : @shared.DDSConfig = {
    max_iter: 30,
    r: 0.2,
    seed: 123,
    target_metric: "nse",
    params: @shared.default_calib_params(),
  }
  let result = @shared.dds_calibrate(
    cfg,
    area=200.0,
    dt=1.0,
    forcings,
    observed,
  )
  let detail = "最优NSE: \{result.best_metric}, 迭代: \{result.n_iter}, 收敛: \{result.converged}"
  {
    command: "dds",
    success: true,
    message: "DDS率定完成(11参数)",
    details: detail,
  }
}

///|
/// 子命令: validate - 流域校验
fn cli_validate() -> CliResult {
  let report = @shared.generate_validation_report()
  let mut detail = "总案例: \{report.total_cases}, 通过: \{report.passed_count}, 失败: \{report.failed_count}\n"
  detail = detail +
    "平均NSE: \{report.mean_nse}, 范围: [\{report.min_nse}, \{report.max_nse}]\n"
  for r in report.results {
    let grade_str = match r.grade {
      @shared.ForecastGrade::Excellent => "甲等"
      @shared.ForecastGrade::Good => "乙等"
      @shared.ForecastGrade::Qualified => "丙等"
      @shared.ForecastGrade::Unqualified => "不合格"
    }
    detail = detail +
      "  \{r.case_name}: NSE=\{r.nse}, KGE=\{r.kge}, 等级=\{grade_str}\n"
  }
  {
    command: "validate",
    success: report.failed_count == 0,
    message: "流域校验完成(\{report.total_cases}个案例)",
    details: detail,
  }
}

///|
/// 子命令: batch - 批量多流域仿真
fn cli_batch() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t3" },
  ]
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let observed = model.run(forcings).runoff_series
  let tasks : Array[@shared.SimTask] = []
  let basin_names = [
    "闽江竹岐", "飞云江", "青弋江", "合成流域A", "合成流域B",
  ]
  for i in 0..<5 {
    tasks.push({
      task_id: "basin_\{i}",
      basin_name: basin_names[i],
      params: @shared.XinanjiangParams::default(),
      area: 100.0 + i.to_double() * 50.0,
      dt: 1.0,
      forcings,
      observed,
    })
  }
  let result = @shared.run_batch_sim(tasks)
  let detail = "总任务: \{result.total_tasks}, 成功: \{result.success_count}, 失败: \{result.failure_count}\n平均NSE: \{result.summary_stats.mean_nse}, 平均KGE: \{result.summary_stats.mean_kge}\n平均洪峰: \{result.summary_stats.mean_peak_flow}, 总体积: \{result.summary_stats.total_volume}"
  {
    command: "batch",
    success: result.failure_count == 0,
    message: "批量仿真完成(\{result.total_tasks}个流域)",
    details: detail,
  }
}

///|
/// 子命令: ensemble - 集合仿真
fn cli_ensemble() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 15.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 25.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 10.0, evaporation: 1.5, datetime: "t2" },
    { rainfall: 2.0, evaporation: 1.0, datetime: "t3" },
  ]
  let params_set : Array[@shared.XinanjiangParams] = []
  let base = @shared.XinanjiangParams::default()
  let wm_values = [10.0, 15.0, 20.0, 25.0, 30.0]
  for wm in wm_values {
    params_set.push({ ..base, wm, })
  }
  let result = @shared.run_ensemble_sim(
    basin_name="测试流域",
    params_set,
    area=150.0,
    dt=1.0,
    forcings,
  )
  let detail = "成员数: \{result.total_tasks}, 成功: \{result.success_count}\n平均NSE: \{result.summary_stats.mean_nse}, 平均KGE: \{result.summary_stats.mean_kge}\n平均洪峰: \{result.summary_stats.mean_peak_flow}"
  {
    command: "ensemble",
    success: result.failure_count == 0,
    message: "集合仿真完成(\{result.total_tasks}个成员)",
    details: detail,
  }
}

///|
/// 子命令: uncertainty - 蒙特卡洛不确定性分析
fn cli_uncertainty() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 12.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 22.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 8.0, evaporation: 1.5, datetime: "t2" },
    { rainfall: 1.0, evaporation: 1.0, datetime: "t3" },
    { rainfall: 0.0, evaporation: 0.5, datetime: "t4" },
  ]
  let result = @shared.monte_carlo_uncertainty(
    @shared.XinanjiangParams::default(),
    @shared.default_calib_params(),
    n_samples=50,
    area=120.0,
    dt=1.0,
    forcings,
    seed=42,
  )
  let detail = "采样数: \{result.n_samples}\n洪峰: 均值=\{result.peak_flow_mean}, 标准差=\{result.peak_flow_std}\n90%置信区间: [\{result.peak_flow_p5}, \{result.peak_flow_p95}]\n总量: 均值=\{result.volume_mean}, 标准差=\{result.volume_std}"
  {
    command: "uncertainty",
    success: true,
    message: "蒙特卡洛不确定性分析完成(50次采样)",
    details: detail,
  }
}

///|
/// 子命令: sensitivity - 参数敏感性扫描
fn cli_sensitivity() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 15.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 5.0, evaporation: 1.5, datetime: "t2" },
  ]
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let observed = model.run(forcings).runoff_series
  let results = @shared.param_sensitivity_scan(
    @shared.XinanjiangParams::default(),
    param_name="wm",
    lower=10.0,
    upper=30.0,
    n_samples=5,
    area=100.0,
    dt=1.0,
    forcings,
    observed,
  )
  let mut detail = "参数wm敏感性扫描:\n"
  for pair in results {
    let (wm_val, r) = pair
    detail = detail +
      "  wm=\{wm_val}: NSE=\{r.nse}, KGE=\{r.kge}, 峰值=\{r.peak_flow}\n"
  }
  {
    command: "sensitivity",
    success: true,
    message: "参数敏感性扫描完成(\{results.length()}个样本)",
    details: detail,
  }
}

///|
/// 子命令: swe - 浅水方程仿真
fn cli_swe() -> CliResult {
  let grid1d = @shared.SWEGrid1D::uniform(nx=50, dx=1.0, h0=1.0)
  let config1d : @shared.SWESolverConfig = {
    dt: 0.01,
    n_steps: 50,
    cfl: 0.4,
    boundary: {
      left: @shared.SWEBoundaryType::SolidWall,
      right: @shared.SWEBoundaryType::Transmissive,
    },
  }
  let result1d = grid1d.run(config1d)
  let grid2d = @shared.SWEGrid2D::uniform(nx=20, ny=20, dx=1.0, dy=1.0, h0=0.1)
  ignore(grid2d.set_block(i0=0, i1=10, j0=0, j1=20, h_value=2.0))
  let config2d : @shared.SWE2DSolverConfig = {
    dt: 0.005,
    n_steps: 30,
    cfl: 0.3,
    boundary: @shared.SWE2DBoundary::SolidWall,
  }
  let result2d = grid2d.run(config2d)
  let mut max_h = 0.0
  for k in 0..<400 {
    if result2d.max_depth[k] > max_h {
      max_h = result2d.max_depth[k]
    }
  }
  let detail = "1D SWE: 50单元, 稳定性=\{result1d.stable}\n2D SWE: 20x20网格(dam-break), 稳定性=\{result2d.stable}, 实际步数=\{result2d.n_steps_actual}\n2D全域最大水深: \{max_h}"
  {
    command: "swe",
    success: result1d.stable && result2d.stable,
    message: "浅水方程仿真完成(1D+2D)",
    details: detail,
  }
}

///|
/// 子命令: coupling - 新安江+SWE耦合仿真
fn cli_coupling() -> CliResult {
  let xaj_model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t3" },
    { rainfall: 30.0, evaporation: 2.0, datetime: "t4" },
  ]
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
  let grid = @shared.SWEGrid1D::uniform(nx=50, dx=1.0, h0=0.5)
  let result = @shared.couple_run(
    xaj_model, grid, coupling_params, swe_boundary, forcings, 0.005,
  )
  let detail = "耦合稳定性: \{result.stable}\n侧向入流过程: \{result.lateral_inflow_series.length()}步\n河道水位过程: \{result.water_level_series.length()}步"
  {
    command: "coupling",
    success: result.stable,
    message: "新安江+SWE耦合仿真完成",
    details: detail,
  }
}

///|
/// 子命令: timeseries - 时间序列分析
fn cli_timeseries() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t3" },
    { rainfall: 30.0, evaporation: 2.0, datetime: "t4" },
  ]
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let runoff = model.run(forcings).runoff_series
  let stats = @shared.ts_stats(runoff)
  let peaks = @shared.detect_peaks(runoff)
  let baseflow = @shared.baseflow_separation(runoff)
  let detail = "统计: 均值=\{stats.mean}, 标准差=\{stats.stddev}\n范围: [\{stats.min_val}, \{stats.max_val}], 趋势=\{stats.trend}\n洪峰位置: \{peaks.length()}个\n基流分离: \{baseflow.length()}步"
  {
    command: "timeseries",
    success: true,
    message: "时间序列分析完成",
    details: detail,
  }
}

///|
/// 子命令: metrics - 扩展评价指标
fn cli_metrics() -> CliResult {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t3" },
    { rainfall: 30.0, evaporation: 2.0, datetime: "t4" },
  ]
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let obs = model.run(forcings).runoff_series
  let sim = obs
  let ext = @shared.evaluate_extended(obs, sim)
  let detail = "LogNSE=\{ext.log_nse}, RSR=\{ext.rsr}, d=\{ext.index_of_agreement}\nKGE分解: r=\{ext.r}, alpha=\{ext.alpha}, beta=\{ext.beta}\nMAE=\{ext.mae}, MSE=\{ext.mse}\nPFC=\{ext.percent_forecast_correct}%, 持续性指数=\{ext.persistence_index}"
  {
    command: "metrics",
    success: true,
    message: "扩展评价指标计算完成",
    details: detail,
  }
}

///|
/// 子命令: json - JSON API端到端演示
fn cli_json() -> CliResult raise {
  let request : @shared.XajRunRequest = {
    params: @shared.XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: [
      { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
      { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    ],
  }
  let request_json = @shared.to_json_string(request)
  let response_json = @shared.xaj_json_endpoint(request_json)
  let req_preview = if request_json.length() > 100 {
    request_json[0:100].to_owned() + "..."
  } else {
    request_json
  }
  let resp_preview = if response_json.length() > 100 {
    response_json[0:100].to_owned() + "..."
  } else {
    response_json
  }
  let detail = "请求JSON: \{req_preview}\n响应JSON: \{resp_preview}"
  {
    command: "json",
    success: true,
    message: "JSON API端到端演示完成",
    details: detail,
  }
}

///|
/// 子命令: demo - 完整功能演示
fn cli_demo() -> Unit raise {
  println("沐澜水文 V0.4 - 完整功能演示")
  println(repeat_str("=", 50))
  print_cli_result(cli_sim())
  print_cli_result(cli_calibrate())
  print_cli_result(cli_dds())
  print_cli_result(cli_validate())
  print_cli_result(cli_batch())
  print_cli_result(cli_ensemble())
  print_cli_result(cli_uncertainty())
  print_cli_result(cli_sensitivity())
  print_cli_result(cli_swe())
  print_cli_result(cli_coupling())
  print_cli_result(cli_timeseries())
  print_cli_result(cli_metrics())
  print_cli_result(cli_json())
  print_cli_result(cli_bench())
  println("\n" + repeat_str("=", 50))
  println("所有子命令执行完毕")
  cli_help()
}

///|
/// 子命令: bench - 性能基准测试
fn cli_bench() -> CliResult {
  let report = @shared.run_all_benchmarks()
  {
    command: "bench",
    success: true,
    message: "性能基准测试完成",
    details: report,
  }
}
