///|
/// LSTM模型测试

///|
test "LSTMState::initial" {
  let state = LSTMState::initial(5)
  assert_eq(state.h.length(), 5)
  assert_eq(state.c.length(), 5)
  for i in 0..<5 {
    assert_eq(state.h[i], 0.0)
    assert_eq(state.c[i], 0.0)
  }
}

///|
test "LSTMWeights::random_init" {
  let config : LSTMConfig = { input_dim: 2, hidden_dim: 3, output_dim: 1 }
  let weights = LSTMWeights::random_init(config, seed=42)
  assert_eq(weights.w_i.length(), 3) // hidden_dim
  assert_eq(weights.w_i[0].length(), 5) // input+hidden
  assert_eq(weights.b_i.length(), 3)
  assert_eq(weights.w_out.length(), 1) // output_dim
  assert_eq(weights.w_out[0].length(), 3) // hidden_dim
  assert_eq(weights.b_out.length(), 1)
}

///|
test "LSTM::new" {
  let config : LSTMConfig = { input_dim: 2, hidden_dim: 4, output_dim: 1 }
  let lstm = LSTM::new(config, seed=42)
  assert_eq(lstm.config.input_dim, 2)
  assert_eq(lstm.config.hidden_dim, 4)
  assert_eq(lstm.config.output_dim, 1)
}

///|
test "LSTM::step - 单步前向传播" {
  let config : LSTMConfig = { input_dim: 1, hidden_dim: 2, output_dim: 1 }
  let lstm = LSTM::new(config, seed=42)
  let x_t = [0.5]
  let state = LSTMState::initial(2)
  let (y_t, new_state) = lstm.step(x_t, state)
  assert_eq(y_t.length(), 1)
  assert_eq(new_state.h.length(), 2)
  assert_eq(new_state.c.length(), 2)
}

///|
test "LSTM::forward - 序列前向传播" {
  let config : LSTMConfig = { input_dim: 1, hidden_dim: 4, output_dim: 1 }
  let lstm = LSTM::new(config, seed=42)
  let inputs : Array[Array[Double]] = [[0.1], [0.2], [0.3], [0.4], [0.5]]
  let outputs = lstm.forward(inputs)
  assert_eq(outputs.length(), 5)
  for y in outputs {
    assert_eq(y.length(), 1)
  }
}

///|
test "LSTM::forward_with_state" {
  let config : LSTMConfig = { input_dim: 1, hidden_dim: 3, output_dim: 1 }
  let lstm = LSTM::new(config, seed=42)
  let inputs : Array[Array[Double]] = [[0.1], [0.2], [0.3]]
  let (outputs, final_state) = lstm.forward_with_state(inputs)
  assert_eq(outputs.length(), 3)
  assert_eq(final_state.h.length(), 3)
  assert_eq(final_state.c.length(), 3)
}

///|
test "LSTM::forecast - 多步预报" {
  let config : LSTMConfig = { input_dim: 1, hidden_dim: 4, output_dim: 1 }
  let lstm = LSTM::new(config, seed=42)
  let history : Array[Array[Double]] = [[0.1], [0.2], [0.3], [0.4], [0.5]]
  let forecasts = lstm.forecast(history, 3)
  assert_eq(forecasts.length(), 3)
  for f in forecasts {
    assert_eq(f.length(), 1)
  }
}

///|
test "LSTMWeights::flatten 和 from_flat" {
  let config : LSTMConfig = { input_dim: 1, hidden_dim: 2, output_dim: 1 }
  let weights = LSTMWeights::random_init(config, seed=42)
  let flat = weights.flatten()
  let count = lstm_weight_count(config)
  assert_eq(flat.length(), count)
  let restored = LSTMWeights::from_flat(flat, config)
  // 验证恢复后权重一致
  assert_eq(restored.w_i.length(), weights.w_i.length())
  assert_eq(restored.w_i[0].length(), weights.w_i[0].length())
  for i in 0..<weights.w_i.length() {
    for j in 0..<weights.w_i[i].length() {
      assert_eq(restored.w_i[i][j], weights.w_i[i][j])
    }
  }
}

///|
test "lstm_weight_count" {
  let config : LSTMConfig = { input_dim: 2, hidden_dim: 3, output_dim: 1 }
  // combined = 2+3 = 5
  // 4 * 3 * 5 + 4 * 3 + 1 * 3 + 1 = 60 + 12 + 3 + 1 = 76
  assert_eq(lstm_weight_count(config), 76)
}

///|
test "LSTM::mse" {
  let config : LSTMConfig = { input_dim: 1, hidden_dim: 4, output_dim: 1 }
  let lstm = LSTM::new(config, seed=42)
  let inputs : Array[Array[Double]] = [[0.1], [0.2], [0.3], [0.4], [0.5]]
  let targets : Array[Array[Double]] = [[0.2], [0.3], [0.4], [0.5], [0.6]]
  let mse = lstm.mse(inputs, targets)
  assert_true(mse >= 0.0)
}

///|
test "LSTM::mse - 空序列" {
  let config : LSTMConfig = { input_dim: 1, hidden_dim: 2, output_dim: 1 }
  let lstm = LSTM::new(config, seed=42)
  let inputs : Array[Array[Double]] = []
  let targets : Array[Array[Double]] = []
  let mse = lstm.mse(inputs, targets)
  assert_eq(mse, 999999.0)
}
