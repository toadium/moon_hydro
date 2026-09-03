///|
/// 批量仿真模块测试
///
/// 测试多流域批量仿真、集合仿真、参数扫描、蒙特卡洛分析

///|
test "SimTask 基本结构" {
  let task : SimTask = {
    task_id: "test_001",
    basin_name: "测试流域",
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: [
      { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
      { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
    ],
    observed: [],
  }
  assert_eq(task.task_id, "test_001")
  assert_eq(task.basin_name, "测试流域")
  assert_eq(task.forcings.length(), 2)
}

///|
test "run_sim_task 单任务执行" {
  let task : SimTask = {
    task_id: "test_001",
    basin_name: "测试流域",
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: [
      { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
      { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
      { rainfall: 5.0, evaporation: 3.0, datetime: "t2", },
    ],
    observed: [],
  }
  let result = run_sim_task(task)
  assert_true(result.success)
  assert_eq(result.task_id, "test_001")
  assert_eq(result.runoff_series.length(), 3)
  // 洪峰应非负
  assert_true(result.peak_flow >= 0.0)
  // 总量应非负
  assert_true(result.total_volume >= 0.0)
}

///|
test "run_sim_task 带观测评价" {
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2", },
  ]
  // 先生成"观测"数据
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let obs_result = model.run(forcings)
  let task : SimTask = {
    task_id: "test_002",
    basin_name: "测试流域",
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings,
    observed: obs_result.runoff_series,
  }
  let result = run_sim_task(task)
  assert_true(result.success)
  // 自校准NSE应接近1
  assert_true((result.nse - 1.0).abs() < 0.001)
  assert_true((result.kge - 1.0).abs() < 0.001)
  assert_true(result.pbias.abs() < 0.1)
}

///|
test "run_batch_sim 批量执行" {
  let tasks : Array[SimTask] = []
  for i in 0..<3 {
    tasks.push({
      task_id: "batch_\{i}",
      basin_name: "流域\{i}",
      params: XinanjiangParams::default(),
      area: 100.0 + i.to_double() * 50.0,
      dt: 1.0,
      forcings: [
        { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
        { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
      ],
      observed: [],
    })
  }
  let result = run_batch_sim(tasks)
  assert_eq(result.total_tasks, 3)
  assert_eq(result.success_count, 3)
  assert_eq(result.failure_count, 0)
  assert_eq(result.results.length(), 3)
}

///|
test "run_ensemble_sim 集合仿真" {
  let params_set : Array[XinanjiangParams] = []
  for i in 0..<5 {
    let base = XinanjiangParams::default()
    params_set.push({ ..base, wm: 80.0 + i.to_double() * 20.0, })
  }
  let forcings : Array[ForcingData] = [
    { rainfall: 15.0, evaporation: 2.0, datetime: "t0", },
    { rainfall: 25.0, evaporation: 1.0, datetime: "t1", },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2", },
  ]
  let result = run_ensemble_sim(
    basin_name="测试",
    params_set,
    area=100.0,
    dt=1.0,
    forcings,
  )
  assert_eq(result.total_tasks, 5)
  assert_eq(result.success_count, 5)
}

///|
test "set_xaj_param 参数设置" {
  let base = XinanjiangParams::default()
  let p1 = set_xaj_param(base, "wm", 100.0)
  assert_true((p1.wm - 100.0).abs() < 0.001)
  let p2 = set_xaj_param(base, "b", 0.5)
  assert_true((p2.b - 0.5).abs() < 0.001)
  let p3 = set_xaj_param(base, "kg", 0.4)
  assert_true((p3.kg - 0.4).abs() < 0.001)
}

///|
test "param_sensitivity_scan 参数扫描" {
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2", },
  ]
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let obs = model.run(forcings).runoff_series
  let results = param_sensitivity_scan(
    XinanjiangParams::default(),
    param_name="wm",
    lower=80.0,
    upper=160.0,
    n_samples=5,
    area=100.0,
    dt=1.0,
    forcings,
    obs,
  )
  assert_eq(results.length(), 5)
  // 第一个参数值应接近80
  assert_true((results[0].0 - 80.0).abs() < 0.001)
  // 最后一个参数值应接近160
  assert_true((results[4].0 - 160.0).abs() < 0.001)
}

///|
test "monte_carlo_uncertainty 蒙特卡洛分析" {
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2", },
  ]
  let calib_params : Array[CalibParam] = [
    { name: "wm", lower: 80.0, upper: 160.0, value: 120.0, },
    { name: "b", lower: 0.2, upper: 0.6, value: 0.3, },
  ]
  let result = monte_carlo_uncertainty(
    XinanjiangParams::default(),
    calib_params,
    n_samples=10,
    area=100.0,
    dt=1.0,
    forcings,
    seed=42,
  )
  assert_eq(result.n_samples, 10)
  // 统计量应非负
  assert_true(result.peak_flow_mean >= 0.0)
  assert_true(result.peak_flow_std >= 0.0)
  assert_true(result.volume_mean >= 0.0)
  // 分位数过程长度应与forcings一致
  assert_eq(result.runoff_p5.length(), 3)
  assert_eq(result.runoff_p50.length(), 3)
  assert_eq(result.runoff_p95.length(), 3)
  // p5 <= p50 <= p95
  for t in 0..<3 {
    assert_true(result.runoff_p5[t] <= result.runoff_p50[t] + 0.001)
    assert_true(result.runoff_p50[t] <= result.runoff_p95[t] + 0.001)
  }
}
