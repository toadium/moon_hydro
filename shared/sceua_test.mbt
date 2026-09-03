///|
/// SCE-UA算法测试
///
/// 测试SCE-UA全局优化算法的正确性、收敛性、端到端率定

///|
test "SCEUAConfig::default 默认配置" {
  let cfg = SCEUAConfig::default()
  assert_eq(cfg.max_iter, 1000)
  assert_eq(cfg.n_complexes, 5)
  assert_eq(cfg.complex_size, 0)
  assert_eq(cfg.cce_iterations, 0)
  assert_eq(cfg.seed, 42)
  assert_eq(cfg.target_metric, "nse")
  assert_eq(cfg.params.length(), 0)
  assert_true((cfg.convergence_threshold - 0.000001).abs() < 0.0000001)
  assert_eq(cfg.max_no_improve, 200)
}

///|
test "sceua_default_calib_params 默认参数集" {
  let params = sceua_default_calib_params()
  assert_eq(params.length(), 11)
  assert_eq(params[0].name, "wm")
  assert_eq(params[10].name, "cs")
}

///|
test "sceua_calibrate 空参数" {
  let cfg = SCEUAConfig::default()
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
  ]
  let result = sceua_calibrate(cfg, area=100.0, dt=1.0, forcings, [10.0])
  assert_eq(result.best_params.length(), 0)
  assert_true(result.converged)
  assert_eq(result.n_function_evals, 0)
}

///|
test "sceua_calibrate 小规模率定" {
  // 使用合成基准案例
  let case = synthetic_benchmark_case()
  // 只率定2个参数，减少迭代次数以加速测试
  let calib_params : Array[CalibParam] = [
    { name: "wm", lower: 80.0, upper: 160.0, value: 120.0, },
    { name: "b", lower: 0.2, upper: 0.6, value: 0.3, },
  ]
  let cfg : SCEUAConfig = {
    max_iter: 30,
    n_complexes: 3,
    complex_size: 0,
    cce_iterations: 0,
    seed: 42,
    target_metric: "nse",
    params: calib_params,
    convergence_threshold: 0.000001,
    max_no_improve: 20,
  }
  let result = sceua_calibrate(
    cfg,
    area=case.area,
    dt=case.dt,
    case.forcings,
    case.observed,
  )
  // 应该有结果
  assert_true(result.best_params.length() == 2)
  assert_true(result.n_iter > 0)
  assert_true(result.n_function_evals > 0)
  // 由于用自身参数生成的观测，NSE应该较高
  assert_true(result.best_metric > 0.5)
}

///|
test "sceua_calibrate KGE目标" {
  let case = synthetic_benchmark_case()
  let calib_params : Array[CalibParam] = [
    { name: "kg", lower: 0.2, upper: 0.5, value: 0.35, },
  ]
  let cfg : SCEUAConfig = {
    max_iter: 20,
    n_complexes: 2,
    complex_size: 0,
    cce_iterations: 0,
    seed: 42,
    target_metric: "kge",
    params: calib_params,
    convergence_threshold: 0.000001,
    max_no_improve: 10,
  }
  let result = sceua_calibrate(
    cfg,
    area=case.area,
    dt=case.dt,
    case.forcings,
    case.observed,
  )
  assert_true(result.best_params.length() == 1)
  // KGE应该在合理范围
  assert_true(result.best_metric > -1.0)
  assert_true(result.best_metric <= 1.0)
}

///|
test "sceua_calibrate 收敛性" {
  let case = synthetic_benchmark_case()
  let calib_params : Array[CalibParam] = [
    { name: "cs", lower: 0.1, upper: 0.4, value: 0.2, },
  ]
  let cfg : SCEUAConfig = {
    max_iter: 50,
    n_complexes: 3,
    complex_size: 0,
    cce_iterations: 0,
    seed: 42,
    target_metric: "nse",
    params: calib_params,
    convergence_threshold: 0.000001,
    max_no_improve: 30,
  }
  let result = sceua_calibrate(
    cfg,
    area=case.area,
    dt=case.dt,
    case.forcings,
    case.observed,
  )
  // 指标历史应该非空
  assert_true(result.metric_history.length() > 0)
  // 指标历史应该非递减（求最大化）
  for i in 1..<result.metric_history.length() {
    assert_true(
      result.metric_history[i] >= result.metric_history[i - 1] - 0.0001,
    )
  }
}

///|
test "sceua_calibrate_basin_case 流域率定" {
  let case = synthetic_benchmark_case()
  let result = sceua_calibrate_basin_case(case, max_iter=20)
  assert_true(result.best_params.length() == 11)
  assert_true(result.n_function_evals > 0)
}
