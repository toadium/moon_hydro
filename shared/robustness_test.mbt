///|
/// 边界容错与异常输入鲁棒性测试
///
/// 测试模型在极端工况、异常输入下的稳定性
/// V0.4安全措施：输入校验、异常捕获、边界容错

///|
test "新安江模型-零降雨仿真" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = [
    { rainfall: 0.0, evaporation: 5.0, datetime: "t0" },
    { rainfall: 0.0, evaporation: 5.0, datetime: "t1" },
    { rainfall: 0.0, evaporation: 5.0, datetime: "t2" },
  ]
  let result = model.run(forcings)
  for v in result.runoff_series {
    assert_true(v >= 0.0)
  }
}

///|
test "新安江模型-极端暴雨仿真" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = [
    { rainfall: 500.0, evaporation: 0.0, datetime: "t0" },
    { rainfall: 1000.0, evaporation: 0.0, datetime: "t1" },
    { rainfall: 800.0, evaporation: 0.0, datetime: "t2" },
  ]
  let result = model.run(forcings)
  assert_eq(result.runoff_series.length(), 3)
  for v in result.runoff_series {
    assert_true(v >= 0.0)
    assert_true(v < 1000000000000000.0)
  }
}

///|
test "新安江模型-负降雨容错" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = [
    { rainfall: -10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: -5.0, datetime: "t1" },
  ]
  let result = model.run(forcings)
  assert_eq(result.runoff_series.length(), 2)
  for v in result.runoff_series {
    assert_true(v >= 0.0)
  }
}

///|
test "新安江模型-零面积容错" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=0.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
  ]
  let result = model.run(forcings)
  assert_eq(result.runoff_series.length(), 1)
}

///|
test "新安江模型-极小时段容错" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=0.1,
  )
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
  ]
  let result = model.run(forcings)
  assert_eq(result.runoff_series.length(), 2)
}

///|
test "新安江模型-空forcings序列" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = []
  let result = model.run(forcings)
  assert_eq(result.runoff_series.length(), 0)
  assert_eq(result.state_series.length(), 0)
}

///|
test "评价指标-空序列容错" {
  let empty : Array[Double] = []
  assert_true((nse(empty, empty) - 0.0).abs() < 0.001)
  assert_true((kge(empty, empty) - 0.0).abs() < 0.001)
  assert_true((pbias(empty, empty) - 0.0).abs() < 0.001)
  assert_true((rmse(empty, empty) - 0.0).abs() < 0.001)
}

///|
test "评价指标-长度不匹配容错" {
  let obs = [1.0, 2.0, 3.0]
  let sim = [1.0, 2.0]
  assert_true((nse(obs, sim) - 0.0).abs() < 0.001)
  assert_true((kge(obs, sim) - 0.0).abs() < 0.001)
}

///|
test "SWE-零初始水深容错" {
  let grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=0.0)
  let config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 10,
    cfl: 0.4,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let result = grid.run(config)
  ignore(result.stable)
}

///|
test "SWE-极大水深容错" {
  let grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=10000.0)
  let config : SWESolverConfig = {
    dt: 0.001,
    n_steps: 5,
    cfl: 0.1,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let result = grid.run(config)
  assert_eq(result.max_depth.length(), 10)
}

///|
test "DDS率定-空参数容错" {
  let config : DDSConfig = {
    max_iter: 10,
    r: 0.2,
    seed: 42,
    target_metric: "nse",
    params: [],
    max_no_improve: 100,
  }
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
  ]
  let result = dds_calibrate(config, area=100.0, dt=1.0, forcings, [10.0])
  assert_eq(result.best_params.length(), 0)
}

///|
test "SCE-UA率定-空参数容错" {
  let config : SCEUAConfig = {
    max_iter: 10,
    n_complexes: 2,
    complex_size: 0,
    cce_iterations: 0,
    seed: 42,
    target_metric: "nse",
    params: [],
    convergence_threshold: 0.000001,
    max_no_improve: 5,
  }
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
  ]
  let result = sceua_calibrate(config, area=100.0, dt=1.0, forcings, [10.0])
  assert_eq(result.best_params.length(), 0)
}

///|
test "批量仿真-空任务列表" {
  let tasks : Array[SimTask] = []
  let result = run_batch_sim(tasks)
  assert_eq(result.total_tasks, 0)
  assert_eq(result.success_count, 0)
  assert_eq(result.failure_count, 0)
}

///|
test "蒙特卡洛-零采样容错" {
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
  ]
  let calib_params : Array[CalibParam] = [
    { name: "wm", lower: 80.0, upper: 160.0, value: 120.0 },
  ]
  let result = monte_carlo_uncertainty(
    XinanjiangParams::default(),
    calib_params,
    n_samples=0,
    area=100.0,
    dt=1.0,
    forcings,
  )
  assert_eq(result.n_samples, 0)
}

///|
test "JSON端点-无效JSON容错" {
  try {
    let _ = xaj_json_endpoint("invalid json")
    (fail("应抛出解析错误") : Unit)
  } catch {
    _ => assert_true(true)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "参数设置-未知参数名容错" {
  let base = XinanjiangParams::default()
  let p = set_xaj_param(base, "nonexistent", 999.0)
  assert_true((p.wm - base.wm).abs() < 0.001)
  assert_true((p.b - base.b).abs() < 0.001)
}

///|
test "长期仿真稳定性-100时段" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=500.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = []
  let rng = @splitmix.new(seed=42)
  for i in 0..<100 {
    let rainfall = rng.next_double() * 50.0
    forcings.push({ rainfall, evaporation: 2.0, datetime: "t\{i}" })
  }
  let result = model.run(forcings)
  assert_eq(result.runoff_series.length(), 100)
  for v in result.runoff_series {
    assert_true(v >= 0.0)
    assert_true(v < 1000000000000000.0)
  }
}

///|
test "长期仿真稳定性-含干旱期" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = []
  for i in 0..<10 {
    forcings.push({ rainfall: 20.0, evaporation: 2.0, datetime: "flood1_\{i}" })
  }
  for i in 0..<20 {
    forcings.push({ rainfall: 0.0, evaporation: 5.0, datetime: "dry_\{i}" })
  }
  for i in 0..<10 {
    forcings.push({ rainfall: 15.0, evaporation: 2.0, datetime: "flood2_\{i}" })
  }
  let result = model.run(forcings)
  assert_eq(result.runoff_series.length(), 40)
  let dry_start = 10
  let dry_end = 30
  for i in dry_start..<(dry_end - 1) {
    assert_true(result.runoff_series[i] >= result.runoff_series[i + 1] - 0.001)
  }
}
