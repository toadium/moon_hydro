///|
/// 混合预报测试

///|
test "prepare_sequences" {
  let series = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
  let (inputs, targets) = prepare_sequences(series, 3)
  assert_eq(inputs.length(), 3) // 6-3=3
  assert_eq(targets.length(), 3)
  assert_eq(inputs[0].length(), 3)
  assert_eq(inputs[0][0], 1.0)
  assert_eq(inputs[0][2], 3.0)
  assert_eq(targets[0][0], 4.0)
  assert_eq(targets[2][0], 6.0)
}

///|
test "prepare_sequences - 序列太短" {
  let series = [1.0, 2.0]
  let (inputs, targets) = prepare_sequences(series, 3)
  assert_eq(inputs.length(), 0)
  assert_eq(targets.length(), 0)
}

///|
test "prepare_rainfall_runoff" {
  let rainfall = [10.0, 20.0, 30.0, 40.0, 50.0]
  let runoff = [1.0, 2.0, 3.0, 4.0, 5.0]
  let (inputs, targets) = prepare_rainfall_runoff(rainfall, runoff, 2)
  assert_eq(inputs.length(), 3) // 5-2=3
  assert_eq(targets.length(), 3)
  // 每个输入有 lookback*2 = 4 个元素（runoff+rainfall交替）
  assert_eq(inputs[0].length(), 4)
  assert_eq(targets[0][0], 3.0) // runoff[2]
}

///|
test "HybridConfig 默认值" {
  let config : HybridConfig = {
    lstm_config: { input_dim: 2, hidden_dim: 4, output_dim: 1, },
    lookback: 3,
    n_forecast: 5,
    train_ratio: 0.7,
    seed: 42,
  }
  assert_eq(config.lookback, 3)
  assert_eq(config.lstm_config.hidden_dim, 4)
}

///|
test "hybrid_forecast - 基本功能" {
  let config : HybridConfig = {
    lstm_config: { input_dim: 3, hidden_dim: 4, output_dim: 1, },
    lookback: 3,
    n_forecast: 5,
    train_ratio: 0.6,
    seed: 42,
  }
  // 模拟物理预报和观测
  let physical = [10.0, 12.0, 15.0, 18.0, 20.0, 22.0, 25.0, 28.0, 30.0, 32.0]
  let observed = [11.0, 13.0, 14.0, 19.0, 21.0, 23.0, 24.0, 29.0, 31.0, 33.0]
  let result = hybrid_forecast(config, physical, observed)
  assert_eq(result.physical_forecast.length(), 10)
  assert_eq(result.hybrid_forecast.length(), 10)
  assert_eq(result.observed.length(), 10)
}

///|
test "extract_rainfall" {
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 1.0, datetime: "t0", },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
    { rainfall: 30.0, evaporation: 1.0, datetime: "t2", },
  ]
  let rainfall = extract_rainfall(forcings)
  assert_eq(rainfall.length(), 3)
  assert_eq(rainfall[0], 10.0)
  assert_eq(rainfall[2], 30.0)
}

///|
test "hybrid_forecast - NSE改进" {
  let config : HybridConfig = {
    lstm_config: { input_dim: 5, hidden_dim: 8, output_dim: 1, },
    lookback: 5,
    n_forecast: 3,
    train_ratio: 0.5,
    seed: 42,
  }
  // 构造有系统偏差的物理预报
  let observed : Array[Double] = []
  let physical : Array[Double] = []
  for i in 0..<20 {
    let v = 10.0 + i.to_double() * 0.5
    observed.push(v)
    physical.push(v - 2.0) // 物理预报系统性偏低2.0
  }
  let result = hybrid_forecast(config, physical, observed)
  // 混合预报应包含物理+校正
  assert_eq(result.hybrid_forecast.length(), 20)
}
