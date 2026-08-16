///|
/// wasm_slim_model 轻量化试算测试

///|
test "slim_run 基本试算" {
  let request : SlimSimRequest = {
    area: 100.0,
    dt: 1.0,
    rainfall: [10.0, 20.0, 5.0, 0.0, 30.0],
    evaporation: [2.0, 1.0, 3.0, 1.0, 2.0],
  }
  let response = slim_run(request)
  assert_true(response.success)
  assert_eq(response.runoff.length(), 5)
  assert_true(response.peak_flow > 0.0)
  assert_true(response.total_volume > 0.0)
}

///|
test "slim_run 长度不匹配" {
  let request : SlimSimRequest = {
    area: 100.0,
    dt: 1.0,
    rainfall: [10.0, 20.0],
    evaporation: [2.0],
  }
  let response = slim_run(request)
  assert_false(response.success)
  assert_true(response.error.length() > 0)
}

///|
test "slim_run 空序列" {
  let request : SlimSimRequest = {
    area: 100.0,
    dt: 1.0,
    rainfall: [],
    evaporation: [],
  }
  let response = slim_run(request)
  assert_false(response.success)
}

///|
test "quick_run 快速试算" {
  let result = quick_run([10.0, 20.0, 5.0])
  assert_true(result.success)
  assert_eq(result.runoff.length(), 3)
}

///|
test "quick_run 自定义参数" {
  let result = quick_run([15.0, 25.0], area=200.0, dt=2.0, evap=1.5)
  assert_true(result.success)
  assert_eq(result.runoff.length(), 2)
}

///|
test "quick_batch 批量快速试算" {
  let rainfall_set : Array[Array[Double]] = [
    [10.0, 20.0],
    [15.0, 25.0],
    [5.0, 30.0],
  ]
  let results = quick_batch(rainfall_set)
  assert_eq(results.length(), 3)
  for r in results {
    assert_true(r.success)
  }
}

///|
test "slim_json_endpoint JSON端到端" {
  let request : SlimSimRequest = {
    area: 100.0,
    dt: 1.0,
    rainfall: [10.0, 20.0],
    evaporation: [2.0, 1.0],
  }
  let json = request.to_json().stringify()
  let response = slim_json_endpoint(json)
  assert_true(response.contains("runoff"))
  assert_true(response.contains("success"))
}

///|
test "available_basins 流域列表" {
  let basins = available_basins()
  assert_eq(basins.length(), 4)
  assert_eq(basins[0], "合成基准")
  assert_eq(basins[1], "闽江竹岐")
  assert_eq(basins[2], "飞云江")
  assert_eq(basins[3], "青弋江")
}

///|
test "load_basin_config 加载配置" {
  let config = load_basin_config("闽江竹岐")
  assert_eq(config.basin_name, "闽江竹岐")
  assert_true((config.area - 54500.0).abs() < 0.001)
  let config2 = load_basin_config("未知流域")
  assert_eq(config2.basin_name, "合成基准")
}

///|
test "slim_run 与shared结果一致" {
  // 轻内试算
  let request : SlimSimRequest = {
    area: 100.0,
    dt: 1.0,
    rainfall: [10.0, 20.0, 5.0, 0.0, 30.0],
    evaporation: [2.0, 1.0, 3.0, 1.0, 2.0],
  }
  let slim_result = slim_run(request)
  // shared层仿真
  let forcings : Array[@shared.ForcingData] = []
  for i in 0..<5 {
    forcings.push({
      rainfall: request.rainfall[i],
      evaporation: request.evaporation[i],
      datetime: "t\{i}",
    })
  }
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let shared_result = model.run(forcings)
  // 两者应完全一致
  assert_eq(slim_result.runoff.length(), shared_result.runoff_series.length())
  for i in 0..<slim_result.runoff.length() {
    assert_true(
      (slim_result.runoff[i] - shared_result.runoff_series[i]).abs() < 0.0001,
    )
  }
}
