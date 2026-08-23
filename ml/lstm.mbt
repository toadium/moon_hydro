///|
/// LSTM（长短期记忆网络）模型
///
/// 轻量级LSTM实现，用于水文时间序列预报。
/// 权重可通过flatten/unflatten与SCE-UA优化框架配合训练。
/// 前向传播：输入序列 → LSTM单元 → 输出序列

///|
/// LSTM配置
pub(all) struct LSTMConfig {
  input_dim : Int // 输入维度
  hidden_dim : Int // 隐藏层维度
  output_dim : Int // 输出维度
} derive(Debug, ToJson, FromJson)

///|
/// LSTM权重
pub(all) struct LSTMWeights {
  w_i : Array[Array[Double]] // 输入门权重 [hidden, input+hidden]
  w_f : Array[Array[Double]] // 遗忘门权重
  w_g : Array[Array[Double]] // 候选门权重
  w_o : Array[Array[Double]] // 输出门权重
  b_i : Array[Double] // 输入门偏置 [hidden]
  b_f : Array[Double] // 遗忘门偏置
  b_g : Array[Double] // 候选门偏置
  b_o : Array[Double] // 输出门偏置
  w_out : Array[Array[Double]] // 输出层权重 [output, hidden]
  b_out : Array[Double] // 输出层偏置 [output]
} derive(Debug, ToJson, FromJson)

///|
/// LSTM隐藏状态
pub(all) struct LSTMState {
  h : Array[Double] // 隐藏状态 [hidden]
  c : Array[Double] // 单元状态 [hidden]
} derive(Debug, ToJson, FromJson)

///|
/// LSTM模型
pub(all) struct LSTM {
  config : LSTMConfig
  weights : LSTMWeights
} derive(Debug, ToJson, FromJson)

///|
/// 构造初始隐藏状态（全零）
pub fn LSTMState::initial(hidden_dim : Int) -> LSTMState {
  { h: vec_zeros(hidden_dim), c: vec_zeros(hidden_dim) }
}

///|
/// 随机初始化LSTM权重
pub fn LSTMWeights::random_init(
  config : LSTMConfig,
  seed? : UInt64 = 42,
) -> LSTMWeights {
  let rng = @splitmix.new(seed~)
  let combined = config.input_dim + config.hidden_dim
  {
    w_i: mat_random(config.hidden_dim, combined, rng),
    w_f: mat_random(config.hidden_dim, combined, rng),
    w_g: mat_random(config.hidden_dim, combined, rng),
    w_o: mat_random(config.hidden_dim, combined, rng),
    b_i: vec_random(config.hidden_dim, rng),
    b_f: vec_random(config.hidden_dim, rng),
    b_g: vec_random(config.hidden_dim, rng),
    b_o: vec_random(config.hidden_dim, rng),
    w_out: mat_random(config.output_dim, config.hidden_dim, rng),
    b_out: vec_random(config.output_dim, rng),
  }
}

///|
/// 构造LSTM模型（随机初始化）
pub fn LSTM::new(config : LSTMConfig, seed? : UInt64 = 42) -> LSTM {
  { config, weights: LSTMWeights::random_init(config, seed~) }
}

///|
/// 用指定权重构造LSTM模型
pub fn LSTM::with_weights(config : LSTMConfig, weights : LSTMWeights) -> LSTM {
  { config, weights }
}

///|
/// 单步前向传播
///
/// 输入x_t和上一时刻状态，返回输出y_t和新状态
pub fn LSTM::step(
  self : LSTM,
  x_t : Array[Double],
  prev_state : LSTMState,
) -> (Array[Double], LSTMState) {
  let w = self.weights
  let combined = vec_concat(x_t, prev_state.h)
  // 输入门
  let i_t = vec_sigmoid(vec_add(mat_vec_mul(w.w_i, combined), w.b_i))
  // 遗忘门
  let f_t = vec_sigmoid(vec_add(mat_vec_mul(w.w_f, combined), w.b_f))
  // 候选门
  let g_t = vec_tanh(vec_add(mat_vec_mul(w.w_g, combined), w.b_g))
  // 输出门
  let o_t = vec_sigmoid(vec_add(mat_vec_mul(w.w_o, combined), w.b_o))
  // 单元状态: c_t = f_t ⊙ c_{t-1} + i_t ⊙ g_t
  let c_t = vec_add(vec_mul(f_t, prev_state.c), vec_mul(i_t, g_t))
  // 隐藏状态: h_t = o_t ⊙ tanh(c_t)
  let h_t = vec_mul(o_t, vec_tanh(c_t))
  // 输出: y_t = w_out * h_t + b_out
  let y_t = vec_add(mat_vec_mul(w.w_out, h_t), w.b_out)
  (y_t, { h: h_t, c: c_t })
}

///|
/// 序列前向传播
///
/// 输入序列，返回输出序列（每个时间步的输出）
pub fn LSTM::forward(
  self : LSTM,
  inputs : Array[Array[Double]],
) -> Array[Array[Double]] {
  let mut state = LSTMState::initial(self.config.hidden_dim)
  let outputs : Array[Array[Double]] = []
  for x_t in inputs {
    let (y_t, new_state) = self.step(x_t, state)
    outputs.push(y_t)
    state = new_state
  }
  outputs
}

///|
/// 序列前向传播（返回最终隐藏状态）
pub fn LSTM::forward_with_state(
  self : LSTM,
  inputs : Array[Array[Double]],
) -> (Array[Array[Double]], LSTMState) {
  let mut state = LSTMState::initial(self.config.hidden_dim)
  let outputs : Array[Array[Double]] = []
  for x_t in inputs {
    let (y_t, new_state) = self.step(x_t, state)
    outputs.push(y_t)
    state = new_state
  }
  (outputs, state)
}

///|
/// 多步预报
///
/// 给定历史输入序列，预报未来n_forecast步
/// 每步将上一步输出作为下一步输入（自回归）
/// 注：P2-9：当output_dim < input_dim时，输入将部分用0填充；
/// 当output_dim > input_dim时，输出截断为input_dim长度。
/// 建议设置output_dim == input_dim以获得最佳自回归效果。
pub fn LSTM::forecast(
  self : LSTM,
  history : Array[Array[Double]],
  n_forecast : Int,
) -> Array[Array[Double]] {
  let (_, state_init) = self.forward_with_state(history)
  let mut state = state_init
  let forecasts : Array[Array[Double]] = []
  // 用最后一个输入作为预报起点
  let mut last_input = if history.length() > 0 {
    history[history.length() - 1]
  } else {
    vec_zeros(self.config.input_dim)
  }
  for _ in 0..<n_forecast {
    let (y_t, new_state) = self.step(last_input, state)
    forecasts.push(y_t)
    state = new_state
    // 自回归：将输出反馈为输入（取前input_dim个）
    let next_input = vec_zeros(self.config.input_dim)
    for i in 0..<self.config.input_dim {
      if i < y_t.length() {
        next_input[i] = y_t[i]
      }
    }
    last_input = next_input
  }
  forecasts
}

///|
/// 权重展平为一维数组（用于SCE-UA优化）
pub fn LSTMWeights::flatten(self : LSTMWeights) -> Array[Double] {
  let result : Array[Double] = []
  for row in self.w_i {
    for v in row {
      result.push(v)
    }
  }
  for row in self.w_f {
    for v in row {
      result.push(v)
    }
  }
  for row in self.w_g {
    for v in row {
      result.push(v)
    }
  }
  for row in self.w_o {
    for v in row {
      result.push(v)
    }
  }
  for v in self.b_i {
    result.push(v)
  }
  for v in self.b_f {
    result.push(v)
  }
  for v in self.b_g {
    result.push(v)
  }
  for v in self.b_o {
    result.push(v)
  }
  for row in self.w_out {
    for v in row {
      result.push(v)
    }
  }
  for v in self.b_out {
    result.push(v)
  }
  result
}

///|
/// 计算权重总数
pub fn lstm_weight_count(config : LSTMConfig) -> Int {
  let combined = config.input_dim + config.hidden_dim
  4 * config.hidden_dim * combined + // w_i, w_f, w_g, w_o
  4 * config.hidden_dim + // b_i, b_f, b_g, b_o
  config.output_dim * config.hidden_dim + // w_out
  config.output_dim // b_out
}

///|
/// 从一维数组恢复权重
pub fn LSTMWeights::from_flat(
  flat : Array[Double],
  config : LSTMConfig,
) -> LSTMWeights {
  // P0修复：校验flat长度，避免越界访问产生错误权重
  let expected = lstm_weight_count(config)
  if flat.length() < expected {
    abort("from_flat: expected \{expected} weights, got \{flat.length()}")
  }
  let combined = config.input_dim + config.hidden_dim
  let mut idx = 0
  let w_i = mat_zeros(config.hidden_dim, combined)
  for i in 0..<config.hidden_dim {
    for j in 0..<combined {
      w_i[i][j] = flat[idx]
      idx = idx + 1
    }
  }
  let w_f = mat_zeros(config.hidden_dim, combined)
  for i in 0..<config.hidden_dim {
    for j in 0..<combined {
      w_f[i][j] = flat[idx]
      idx = idx + 1
    }
  }
  let w_g = mat_zeros(config.hidden_dim, combined)
  for i in 0..<config.hidden_dim {
    for j in 0..<combined {
      w_g[i][j] = flat[idx]
      idx = idx + 1
    }
  }
  let w_o = mat_zeros(config.hidden_dim, combined)
  for i in 0..<config.hidden_dim {
    for j in 0..<combined {
      w_o[i][j] = flat[idx]
      idx = idx + 1
    }
  }
  let b_i = vec_zeros(config.hidden_dim)
  for i in 0..<config.hidden_dim {
    b_i[i] = flat[idx]
    idx = idx + 1
  }
  let b_f = vec_zeros(config.hidden_dim)
  for i in 0..<config.hidden_dim {
    b_f[i] = flat[idx]
    idx = idx + 1
  }
  let b_g = vec_zeros(config.hidden_dim)
  for i in 0..<config.hidden_dim {
    b_g[i] = flat[idx]
    idx = idx + 1
  }
  let b_o = vec_zeros(config.hidden_dim)
  for i in 0..<config.hidden_dim {
    b_o[i] = flat[idx]
    idx = idx + 1
  }
  let w_out = mat_zeros(config.output_dim, config.hidden_dim)
  for i in 0..<config.output_dim {
    for j in 0..<config.hidden_dim {
      w_out[i][j] = flat[idx]
      idx = idx + 1
    }
  }
  let b_out = vec_zeros(config.output_dim)
  for i in 0..<config.output_dim {
    b_out[i] = flat[idx]
    idx = idx + 1
  }
  { w_i, w_f, w_g, w_o, b_i, b_f, b_g, b_o, w_out, b_out }
}

///|
/// 计算LSTM预报的MSE（用于SCE-UA目标函数）
///
/// inputs: 输入序列, targets: 目标序列
/// P3-3：错误情况返回999999.0哨兵值，调用方应检查此值
pub fn LSTM::mse(
  self : LSTM,
  inputs : Array[Array[Double]],
  targets : Array[Array[Double]],
) -> Double {
  let outputs = self.forward(inputs)
  let n = outputs.length()
  if n == 0 || n != targets.length() {
    return 999999.0
  }
  let mut sum_sq = 0.0
  let mut count = 0
  for t in 0..<n {
    let y = outputs[t]
    let target = targets[t]
    let m = y.length()
    for i in 0..<m {
      if i < target.length() {
        let diff = y[i] - target[i]
        sum_sq = sum_sq + diff * diff
        count = count + 1
      }
    }
  }
  if count == 0 {
    return 999999.0
  }
  sum_sq / count.to_double()
}
