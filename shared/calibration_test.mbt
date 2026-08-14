///|
/// 参数率定模块测试
///
/// 测试DDS算法、参数转换、端到端率定流程

///|
test "DDSConfig::default 默认配置" {
  let cfg = DDSConfig::default()
  assert_eq(cfg.max_iter, 1000)
  assert_true((cfg.r - 0.2).abs() < 0.001)
  assert_eq(cfg.seed, 42)
  assert_eq(cfg.target_metric, "nse")
  assert_eq(cfg.params.length(), 0)
}

///|
test "default_calib_params 默认率定参数集" {
  let params = default_calib_params()
  assert_eq(params.length(), 11)
  // 检查参数名
  assert_eq(params[0].name, "wm")
  assert_eq(params[1].name, "b")
  assert_eq(params[2].name, "im")
  assert_eq(params[6].name, "kg")
  assert_eq(params[10].name, "cs")
  // 检查边界约束
  for p in params {
    assert_true(p.lower < p.upper)
    assert_true(p.value >= p.lower)
    assert_true(p.value <= p.upper)
  }
}

///|
test "params_to_xaj 参数转换" {
  let params = default_calib_params()
  let xaj = params_to_xaj(params)
  // 应与默认值一致
  let default_p = XinanjiangParams::default()
  assert_true((xaj.wm - default_p.wm).abs() < 0.001)
  assert_true((xaj.b - default_p.b).abs() < 0.001)
  assert_true((xaj.kg - default_p.kg).abs() < 0.001)
  assert_true((xaj.cs - default_p.cs).abs() < 0.001)
}

///|
test "params_to_xaj 自定义参数转换" {
  let params : Array[CalibParam] = [
    { name: "wm", lower: 80.0, upper: 160.0, value: 140.0 },
    { name: "b", lower: 0.2, upper: 0.6, value: 0.4 },
    { name: "kg", lower: 0.2, upper: 0.5, value: 0.45 },
  ]
  let xaj = params_to_xaj(params)
  assert_true((xaj.wm - 140.0).abs() < 0.001)
  assert_true((xaj.b - 0.4).abs() < 0.001)
  assert_true((xaj.kg - 0.45).abs() < 0.001)
  // 未指定的参数应保持默认
  let default_p = XinanjiangParams::default()
  assert_true((xaj.sm - default_p.sm).abs() < 0.001)
}

///|
test "params_to_xaj 未知参数名忽略" {
  let params : Array[CalibParam] = [
    { name: "unknown", lower: 0.0, upper: 1.0, value: 0.5 },
  ]
  let xaj = params_to_xaj(params)
  let default_p = XinanjiangParams::default()
  assert_true((xaj.wm - default_p.wm).abs() < 0.001)
}

///|
test "dds_calibrate 小规模率定" {
  // 使用简单合成数据：已知参数生成观测，再率定看能否还原
  let forcings = mock_flood_rainfall(duration=20)
  // 用默认参数生成"观测"径流
  let true_params = XinanjiangParams::default()
  let model = XinanjiangModel::new(params=true_params, area=1000.0, dt=1.0)
  let obs_result = model.run(forcings)
  let observed = obs_result.runoff_series
  // 配置DDS：小规模快速率定
  let calib_params : Array[CalibParam] = [
    { name: "wm", lower: 80.0, upper: 160.0, value: 100.0 },
    { name: "b", lower: 0.2, upper: 0.6, value: 0.25 },
    { name: "kg", lower: 0.2, upper: 0.5, value: 0.3 },
  ]
  let cfg : DDSConfig = {
    max_iter: 50,
    r: 0.3,
    seed: 42,
    target_metric: "nse",
    params: calib_params,
  }
  let result = dds_calibrate(cfg, forcings, observed, area=1000.0, dt=1.0)
  // 率定后NSE应为正值（匹配较好）
  assert_true(result.best_metric > 0.0)
  // 应有迭代历史
  assert_true(result.metric_history.length() > 1)
  // 最优参数应在边界内
  for p in result.best_params {
    assert_true(p.value >= p.lower)
    assert_true(p.value <= p.upper)
  }
}

///|
test "dds_calibrate 收敛性检查" {
  let forcings = mock_flood_rainfall(duration=15, peak_rainfall=30.0)
  let true_params = XinanjiangParams::default()
  let model = XinanjiangModel::new(params=true_params, area=500.0, dt=1.0)
  let observed = model.run(forcings).runoff_series
  let cfg : DDSConfig = {
    max_iter: 200,
    r: 0.2,
    seed: 123,
    target_metric: "nse",
    params: default_calib_params(),
  }
  let result = dds_calibrate(cfg, forcings, observed, area=500.0, dt=1.0)
  // 指标历史应非递减（DDS只接受更优解）
  let n = result.metric_history.length()
  for i in 1..<n {
    assert_true(
      result.metric_history[i] >= result.metric_history[i - 1] - 0.0001,
    )
  }
  // n_iter应等于历史长度-1
  assert_eq(result.n_iter, result.metric_history.length() - 1)
}

///|
test "CalibParam 边界约束验证" {
  let params = default_calib_params()
  // wm: 80-160
  assert_true(params[0].lower >= 80.0)
  assert_true(params[0].upper <= 160.0)
  // b: 0.2-0.6
  assert_true(params[1].lower >= 0.2)
  assert_true(params[1].upper <= 0.6)
  // cg: 0.9-0.99
  assert_true(params[8].lower >= 0.9)
  assert_true(params[8].upper <= 0.99)
}
