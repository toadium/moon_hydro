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
  // T62修复：使用StringBuilder避免O(n²)字符串拼接
  let buf = StringBuilder()
  for _ in 0..<n {
    buf.write_string(s)
  }
  buf.to_string()
}

///|
/// T61修复：按字符截断字符串，避免截断UTF-8多字节字符
fn safe_preview(s : String, max_bytes : Int) -> String {
  if s.length() <= max_bytes {
    return s
  }
  let buf = StringBuilder()
  let mut byte_count = 0
  for ch in s.iter() {
    let ch_len = ch.to_string().length()
    if byte_count + ch_len > max_bytes {
      break
    }
    buf.write_char(ch)
    byte_count = byte_count + ch_len
  }
  buf.to_string() + "..."
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
  println("沐澜水文 V0.9 - 命令行子命令")
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
  println("  persistence 持久化存储演示(方案/结果/参数集)")
  println("  auth        权限框架演示(用户/鉴权/方案隔离)")
  println("  ai_forecast AI混合预报演示(LSTM残差校正)")
  println("  gis         GIS接口演示(DEM流向/汇流累积/河网提取)")
  println("  flood       洪水淹没推演(2D水深/风险图/损失评估)")
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
    max_no_improve: 100,
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
  for k in 0..<result2d.max_depth.length() {
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
    observed: [],
  }
  let request_json = @shared.to_json_string(request)
  let response_json = @shared.xaj_json_endpoint(request_json)
  // T61修复：使用字符级安全截断，避免截断UTF-8多字节字符
  let req_preview = safe_preview(request_json, 100)
  let resp_preview = safe_preview(response_json, 100)
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
fn cli_demo() -> Unit {
  println("沐澜水文 V0.9 - 完整功能演示")
  println(repeat_str("=", 50))
  let commands : Array[String] = [
    "sim", "calibrate", "dds", "validate", "batch", "ensemble", "uncertainty",
    "sensitivity", "swe", "coupling", "timeseries", "metrics", "json", "bench",
    "persistence", "auth", "ai_forecast", "gis", "flood",
  ]
  for cmd in commands {
    try {
      dispatch(cmd)
    } catch {
      e => {
        println("[FAIL] [\{cmd}] 子命令异常: \{e}")
      }
    }
  }
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

///|
/// 子命令: persistence - 持久化存储演示
fn cli_persistence() -> CliResult raise {
  let store = @persistence.DataStore::new()
  let now = @env.now() // P2-54：@env.now()引入非确定性，测试时应注入固定时间戳
  // 保存仿真方案
  let scheme : @persistence.SimulationScheme = {
    id: @persistence.generate_id("scheme", now),
    name: "闽江竹岐基准方案",
    basin_name: "闽江竹岐",
    area: 54500.0,
    dt: 6.0,
    params: @shared.XinanjiangParams::default(),
    forcings: [
      { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
      { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    ],
    created_at: now,
    updated_at: now,
  }
  store.save_scheme(scheme)
  // 保存参数集
  let param_set : @persistence.ParameterSet = {
    id: @persistence.generate_id("param", now),
    name: "闽江默认参数",
    basin_name: "闽江竹岐",
    params: @shared.XinanjiangParams::default(),
    description: "闽江竹岐流域默认新安江参数",
    created_at: now,
  }
  store.save_param_set(param_set)
  // 运行仿真并保存结果
  let xaj_model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2" },
  ]
  let sim_result = xaj_model.run(forcings)
  // 计算洪峰
  let mut peak_flow = 0.0
  let mut peak_time = 0
  for i in 0..<sim_result.runoff_series.length() {
    if sim_result.runoff_series[i] > peak_flow {
      peak_flow = sim_result.runoff_series[i]
      peak_time = i
    }
  }
  let result_record : @persistence.ResultRecord = {
    id: @persistence.generate_id("result", now),
    scheme_id: scheme.id,
    basin_name: "闽江竹岐",
    peak_flow,
    peak_time,
    nse: sim_result.nse,
    kge: sim_result.kge,
    pbias: sim_result.pbias,
    runoff_series: sim_result.runoff_series,
    created_at: now,
  }
  store.save_result(result_record)
  // JSON序列化演示
  let json_str = store.to_json_string()
  // P1修复：使用字符级安全截断，避免截断UTF-8多字节字符
  let json_preview = safe_preview(json_str, 300)
  // 反序列化验证
  let store2 = @persistence.DataStore::from_json_string(json_str)
  let stats = store2.stats()
  {
    command: "persistence",
    success: true,
    message: "持久化存储演示完成",
    details: "统计: \{stats}\nJSON预览: \{json_preview}",
  }
}

///|
/// 子命令: auth - 权限框架演示
fn cli_auth() -> CliResult raise {
  println("沐澜水文 权限框架演示")
  println(repeat_str("=", 50))
  let now = @env.now() // P2-54：@env.now()引入非确定性，测试时应注入固定时间戳
  let auth = @shared.AuthManager::new()
  // 注册用户
  let admin_id = auth.register(
    username="admin",
    password="admin123",
    role=@shared.Role::Admin,
    timestamp=now,
  )
  let engineer_id = auth.register(
    username="engineer1",
    password="eng123",
    role=@shared.Role::Engineer,
    timestamp=now + 1UL,
  )
  let viewer_id = auth.register(
    username="viewer1",
    password="view123",
    role=@shared.Role::Viewer,
    timestamp=now + 2UL,
  )
  println(
    "注册用户: admin(管理员), engineer1(工程师), viewer1(查看者)",
  )
  // 登录
  let admin_token = auth.login(
    username="admin",
    password="admin123",
    timestamp=now + 100UL,
  )
  let eng_token = auth.login(
    username="engineer1",
    password="eng123",
    timestamp=now + 101UL,
  )
  let viewer_token = auth.login(
    username="viewer1",
    password="view123",
    timestamp=now + 102UL,
  )
  println("登录成功: 3个用户均获取Token")
  // 方案所有权
  auth.grant_scheme_ownership(user_id=engineer_id, scheme_id="scheme_A")
  auth.grant_scheme_ownership(
    user_id=engineer_id,
    scheme_id="scheme_B",
    is_public=true,
  )
  auth.grant_scheme_ownership(user_id=admin_id, scheme_id="scheme_C")
  println(
    "方案所有权: engineer1拥有scheme_A(私有)+scheme_B(公开), admin拥有scheme_C",
  )
  // 权限检查
  let admin_user = auth.users[admin_id]
  let eng_user = auth.users[engineer_id]
  let viewer_user = auth.users[viewer_id]
  println("\n--- 权限检查 ---")
  // Admin可以用户管理
  auth.check_permission(admin_user, @shared.Permission::UserManage)
  println("[OK] admin -> 用户管理权限")
  // Engineer不能用户管理
  let eng_perm = try {
    auth.check_permission(eng_user, @shared.Permission::UserManage)
    true
  } catch {
    _ => false
  }
  let eng_status = if eng_perm { "OK" } else { "DENY" }
  println("[\{eng_status}] engineer1 -> 用户管理权限")
  // 方案访问
  println("\n--- 方案隔离 ---")
  auth.check_scheme_access(eng_user, "scheme_A")
  println("[OK] engineer1 -> 访问自己的scheme_A")
  auth.check_scheme_access(viewer_user, "scheme_B")
  println("[OK] viewer1 -> 只读访问公开scheme_B")
  auth.check_scheme_access(admin_user, "scheme_A")
  println("[OK] admin -> 访问任何scheme_A")
  let viewer_access_private = try {
    auth.check_scheme_access(viewer_user, "scheme_A")
    true
  } catch {
    _ => false
  }
  let viewer_status = if viewer_access_private { "OK" } else { "DENY" }
  println("[\{viewer_status}] viewer1 -> 访问私有scheme_A")
  // 统计
  println("\n--- 统计 ---")
  println(auth.stats())
  // Token验证
  let verified = auth.verify_token(admin_token, current_time=now + 200UL)
  println(
    "Token验证: admin -> \{verified.username}(\{verified.role.to_string()})",
  )
  // 登出
  let mut logout_details = ""
  if !auth.logout(eng_token) {
    logout_details = logout_details + "engineer1登出失败; "
  }
  if !auth.logout(viewer_token) {
    logout_details = logout_details + "viewer1登出失败; "
  }
  println("登出: engineer1, viewer1 已登出")
  println(auth.stats())
  println("\n权限框架演示完成")
  let r : CliResult = {
    command: "auth",
    success: true,
    message: "权限框架演示完成",
    details: logout_details,
  }
  r
}

///|
/// 子命令: ai_forecast - AI混合预报演示
fn cli_ai_forecast() -> CliResult {
  println("沐澜水文 AI混合预报演示")
  println(repeat_str("=", 50))
  // 生成合成降雨-径流数据
  let forcings : Array[@shared.ForcingData] = []
  let observed : Array[Double] = []
  for i in 0..<50 {
    let r = if i < 10 {
      20.0 - i.to_double()
    } else if i < 30 {
      5.0 + 10.0 * @math.sin(i.to_double() * 0.3)
    } else {
      3.0
    }
    forcings.push({ rainfall: r, evaporation: 1.0, datetime: "t\{i}" })
    // 合成径流：非线性变换 + 噪声
    let q = r * 0.8 + r * r * 0.01 + 2.0
    observed.push(q)
  }
  println("生成合成数据: 50步降雨-径流序列")
  // 物理模型预报（新安江）
  let xaj_model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let sim_result = xaj_model.run(forcings)
  let physical = sim_result.runoff_series
  println("物理模型(新安江)预报完成: \{physical.length()}步")
  // AI混合预报
  let config : @ml.HybridConfig = {
    lstm_config: { input_dim: 5, hidden_dim: 8, output_dim: 1 },
    lookback: 5,
    n_forecast: 5,
    train_ratio: 0.6,
    seed: 42,
  }
  println("LSTM配置: input=5, hidden=8, output=1, lookback=5")
  let result = @ml.hybrid_forecast(config, physical, observed)
  // 输出结果
  println("\n--- 预报结果对比 ---")
  println("物理模型NSE: \{result.physical_nse}")
  println("混合预报NSE: \{result.hybrid_nse}")
  println("NSE改进: \{result.improvement}")
  // 显示部分预报值
  println("\n--- 预报序列(后10步) ---")
  let n = result.hybrid_forecast.length()
  let start = if n > 10 { n - 10 } else { 0 }
  println("步数  物理预报    AI校正    混合预报    观测值")
  for i in start..<n {
    let phys = result.physical_forecast[i]
    let corr = result.ai_correction[i]
    let hybrid = result.hybrid_forecast[i]
    let obs = result.observed[i]
    println("\{i}    \{phys}    \{corr}    \{hybrid}    \{obs}")
  }
  println("\nAI混合预报演示完成")
  let r : CliResult = {
    command: "ai_forecast",
    success: true,
    message: "AI混合预报演示完成",
    details: "",
  }
  r
}

///|
/// 子命令: gis - GIS接口演示
fn cli_gis() -> CliResult {
  println("沐澜水文 GIS接口演示")
  println(repeat_str("=", 50))
  // 1. 生成合成DEM
  println("\n--- 1. 生成合成DEM ---")
  let dem = @gis.synthetic_dem(nx=20, ny=15, dx=100.0, dy=100.0)
  let (min_h, max_h, mean_h, cell_count) = @gis.dem_stats(dem)
  println("DEM尺寸: \{dem.nx}x\{dem.ny}, 分辨率: \{dem.dx}m x \{dem.dy}m")
  println(
    "高程范围: \{min_h}m ~ \{max_h}m, 平均: \{mean_h}m, 单元数: \{cell_count}",
  )
  // 2. D8流向分析
  println("\n--- 2. D8流向分析 ---")
  let fd = @gis.compute_flow_direction(dem)
  let mut dir_counts = 0
  for i in 0..<fd.ny {
    for j in 0..<fd.nx {
      if fd.dirs[i][j] > 0 {
        dir_counts = dir_counts + 1
      }
    }
  }
  println(
    "流向计算完成: \{dir_counts}个单元有流向(共\{fd.nx * fd.ny}个)",
  )
  // 3. 汇流累积
  println("\n--- 3. 汇流累积 ---")
  let fa = @gis.compute_flow_accumulation(fd)
  let mut max_accum = 0
  let mut max_i = 0
  let mut max_j = 0
  for i in 0..<fa.ny {
    for j in 0..<fa.nx {
      if fa.accum[i][j] > max_accum {
        max_accum = fa.accum[i][j]
        max_i = i
        max_j = j
      }
    }
  }
  println(
    "汇流累积计算完成, 最大累积值: \{max_accum}(位于[\{max_i},\{max_j}])",
  )
  // 4. 流域delineation
  println("\n--- 4. 流域delineation ---")
  let watershed = @gis.delineate_watershed(fd, outlet_i=max_i, outlet_j=max_j)
  let ws_area = @gis.watershed_area(dem, watershed)
  println(
    "流域单元数: \{watershed.length()}, 流域面积: \{ws_area}km²",
  )
  // 5. 河网提取
  println("\n--- 5. 河网提取 ---")
  let threshold = max_accum / 5
  let river_cells = @gis.extract_river_network(fa, threshold~)
  println(
    "河网阈值: \{threshold}, 河道单元数: \{river_cells.length()}",
  )
  // 6. 河网拓扑分析
  println("\n--- 6. 河网拓扑分析 ---")
  let network = @gis.extract_network_from_dem(dem, fa, threshold~)
  println("河网统计: \{network.stats()}")
  // 拓扑排序
  let topo_order = network.topological_order()
  println("拓扑排序河段数: \{topo_order.length()}")
  // 追溯源头和出口
  if network.outlet_id >= 0 {
    let sources = network.trace_to_sources(network.outlet_id)
    let outlet_path = network.trace_to_outlet(network.outlet_id)
    println("从出口追溯源头数: \{sources.length()}")
    println("出口路径长度: \{outlet_path.length()}")
  }
  // 7. 流域边界多边形演示
  println("\n--- 7. 流域边界多边形 ---")
  let boundary_pts : Array[@gis.XYPoint] = [
    { x: 0.0, y: 1000.0 },
    { x: 5000.0, y: 1000.0 },
    { x: 5000.0, y: 0.0 },
    { x: 0.0, y: 0.0 },
  ]
  let polygon : @gis.Polygon = {
    exterior: boundary_pts,
    holes: [],
    name: "示例流域",
  }
  let basin = @gis.BasinBoundary::from_polygon(name="示例流域", polygon)
  println("流域名称: \{basin.name}")
  println("流域面积: \{basin.area}km²")
  println("流域形心: (\{basin.centroid.x}, \{basin.centroid.y})")
  println("\nGIS接口演示完成")
  let r : CliResult = {
    command: "gis",
    success: true,
    message: "GIS接口演示完成",
    details: "",
  }
  r
}

///|
/// 子命令: flood - 洪水淹没推演演示
fn cli_flood() -> CliResult {
  println("沐澜水文 洪水淹没推演演示")
  println(repeat_str("=", 50))
  // 1. 构造合成洪水场景
  println("\n--- 1. 构造洪水场景 ---")
  let (grid, config) = @flood.synthetic_flood_scenario(nx=40, ny=30)
  println("网格: \{grid.nx}x\{grid.ny}, 分辨率: \{grid.dx}m x \{grid.dy}m")
  println("时间步: \{config.n_steps}, dt=\{config.dt}s, CFL=\{config.cfl}")
  // 2. 运行淹没仿真
  println("\n--- 2. 运行淹没仿真 ---")
  let result = @flood.simulate_inundation(grid, config)
  println(
    "仿真完成: \{result.n_steps_actual}步, 稳定性: \{result.stable}",
  )
  let (count, area, max_h, mean_h) = @flood.inundation_stats(result)
  println(
    "淹没单元: \{count}, 淹没面积: \{area}km², 最大水深: \{max_h}m, 平均水深: \{mean_h}m",
  )
  // 3. 提取淹没范围
  println("\n--- 3. 淹没范围 ---")
  let extent = @flood.extract_inundation_extent(result, threshold=0.1)
  println("淹没范围(水深>0.1m): \{extent.length()}个单元")
  // 4. 生成风险图
  println("\n--- 4. 风险图 ---")
  let risk_map = @flood.generate_risk_map(
    result.max_depth,
    result.hu_final,
    result.hv_final,
    nx=result.nx,
    ny=result.ny,
  )
  let risk_stats = @flood.risk_statistics(risk_map)
  println(risk_stats.to_summary())
  // 5. ASCII风险图
  println("\n--- 5. ASCII风险图 ---")
  let ascii_map = @flood.to_ascii_map(risk_map, max_width=60)
  println(ascii_map)
  // 6. 损失评估
  println("\n--- 6. 损失评估 ---")
  let land_use = @flood.synthetic_land_use(nx=result.nx, ny=result.ny)
  let damage = @flood.estimate_damage(result.max_depth, land_use)
  println(damage.to_summary())
  println("\n洪水淹没推演演示完成")
  let r : CliResult = {
    command: "flood",
    success: true,
    message: "洪水淹没推演演示完成",
    details: "",
  }
  r
}
