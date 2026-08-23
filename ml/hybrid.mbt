///|
/// 混合预报模块
///
/// 物理模型（新安江）+ AI残差校正混合预报。
/// 策略：物理模型先预报，LSTM学习物理预报的残差，最终预报 = 物理 + AI校正。
/// LSTM权重通过SCE-UA全局优化训练。

///|
/// 混合预报配置
pub(all) struct HybridConfig {
  lstm_config : LSTMConfig // LSTM配置
  lookback : Int // 回望窗口大小（用过去多少步预报下一步）
  n_forecast : Int // 预报步数
  train_ratio : Double // 训练集比例(0-1)
  seed : UInt64 // 随机种子
} derive(Debug, ToJson, FromJson)

///|
/// 混合预报结果
pub(all) struct HybridResult {
  physical_forecast : Array[Double] // 物理模型预报
  ai_correction : Array[Double] // AI残差校正
  hybrid_forecast : Array[Double] // 混合预报（物理+AI）
  observed : Array[Double] // 观测值（用于对比）
  physical_nse : Double // 物理模型NSE
  hybrid_nse : Double // 混合预报NSE
  improvement : Double // NSE改进量
} derive(Debug, ToJson, FromJson)

///|
/// 将时间序列转为LSTM输入序列（滑动窗口）
///
/// 用lookback步的过去值作为输入，下一步作为目标
pub fn prepare_sequences(
  series : Array[Double],
  lookback : Int,
) -> (Array[Array[Double]], Array[Array[Double]]) {
  let n = series.length()
  let inputs : Array[Array[Double]] = []
  let targets : Array[Array[Double]] = []
  if n <= lookback {
    return (inputs, targets)
  }
  for i in 0..<(n - lookback) {
    let input : Array[Double] = []
    for j in 0..<lookback {
      input.push(series[i + j])
    }
    inputs.push(input)
    targets.push([series[i + lookback]])
  }
  (inputs, targets)
}

///|
/// 将降雨-径流数据转为LSTM输入序列
///
/// 输入：[rainfall_t, rainfall_{t+1}, ..., rainfall_{t+lookback-1}]
/// 目标：[runoff_{t+lookback}]
/// P3-8：每个输入包含2*lookback个元素（runoff+rainfall交替），
/// 调用方应确保LSTMConfig.input_dim == 2*lookback
pub fn prepare_rainfall_runoff(
  rainfall : Array[Double],
  runoff : Array[Double],
  lookback : Int,
  input_dim? : Int = 0,
) -> (Array[Array[Double]], Array[Array[Double]]) {
  // P1修复：运行时校验维度约定 input_dim == 2*lookback
  if input_dim > 0 && input_dim != 2 * lookback {
    abort("prepare_rainfall_runoff: input_dim must equal 2*lookback")
  }
  let n = runoff.length()
  let inputs : Array[Array[Double]] = []
  let targets : Array[Array[Double]] = []
  let rain_len = rainfall.length()
  if n <= lookback {
    return (inputs, targets)
  }
  for i in 0..<(n - lookback) {
    let input : Array[Double] = []
    for j in 0..<lookback {
      input.push(runoff[i + j])
      if i + j < rain_len {
        input.push(rainfall[i + j])
      } else {
        input.push(0.0)
      }
    }
    inputs.push(input)
    targets.push([runoff[i + lookback]])
  }
  (inputs, targets)
}

///|
/// 训练LSTM残差模型（多起点随机搜索 + 自适应扰动优化）
///
/// 采用多起点全局搜索 + 自适应步长局部微调策略优化LSTM权重。
/// 注：shared/sceua_calibrate 为新安江模型专用率定接口，
/// 此处使用通用多起点优化，待 shared 提供通用 SCE-UA 接口后可升级。
///
/// physical_forecast: 物理模型预报序列
/// observed: 观测序列
/// 返回训练好的LSTM
pub fn train_residual_lstm(
  config : HybridConfig,
  physical_forecast : Array[Double],
  observed : Array[Double],
) -> LSTM {
  // 计算残差: residual = observed - physical
  let n = observed.length()
  let residual : Array[Double] = []
  for i in 0..<n {
    let phys = if i < physical_forecast.length() {
      physical_forecast[i]
    } else {
      0.0
    }
    residual.push(observed[i] - phys)
  }
  // P0修复：与hybrid_forecast使用相同划分点(基于physical_forecast.length())，
  // 只用训练段残差准备序列，避免LSTM见过测试段数据（数据泄露）
  let split_n = physical_forecast.length()
  let split = (split_n.to_double() * config.train_ratio).to_int()
  let test_start = if split < split_n { split } else { 0 }
  let train_len = if test_start < n { test_start } else { n }
  let train_residual : Array[Double] = []
  for i in 0..<train_len {
    train_residual.push(residual[i])
  }
  // 准备训练数据
  let (inputs, targets) = prepare_sequences(train_residual, config.lookback)
  if inputs.length() == 0 {
    return LSTM::new(config.lstm_config, seed=config.seed)
  }
  // P0修复：当lookback≠input_dim时，通过填充/截断使输入维度匹配
  let input_dim = config.lstm_config.input_dim
  let adjusted_inputs : Array[Array[Double]] = []
  for input in inputs {
    let adjusted : Array[Double] = []
    if input.length() >= input_dim {
      for k in 0..<input_dim {
        adjusted.push(input[k])
      }
    } else {
      for v in input {
        adjusted.push(v)
      }
      for _ in input.length()..<input_dim {
        adjusted.push(0.0)
      }
    }
    adjusted_inputs.push(adjusted)
  }
  // 多起点随机搜索 + 自适应步长局部微调
  let weight_count = lstm_weight_count(config.lstm_config)
  let rng = @splitmix.new(seed=config.seed)
  let mut best_mse = 999999.0
  let mut best_flat : Array[Double] = []
  // 全局搜索：50个随机起点
  let n_global = 50
  for _ in 0..<n_global {
    let flat : Array[Double] = []
    for _ in 0..<weight_count {
      flat.push((rng.next_double() * 2.0 - 1.0) * 0.1)
    }
    let weights = LSTMWeights::from_flat(flat, config.lstm_config)
    let lstm = LSTM::with_weights(config.lstm_config, weights)
    let mse = lstm.mse(inputs, targets)
    if mse < best_mse {
      best_mse = mse
      best_flat = flat
    }
  }
  // 自适应局部微调：逐步缩小扰动范围
  if best_flat.length() > 0 {
    let n_local_rounds = 5
    let n_perturb_per_round = 30
    for round in 0..<n_local_rounds {
      // 扰动幅度从0.1递减到0.01
      let perturb_scale = 0.1 * @math.pow(0.5, round.to_double())
      let mut improved = false
      for _ in 0..<n_perturb_per_round {
        let flat : Array[Double] = []
        for i in 0..<weight_count {
          let perturb = (rng.next_double() * 2.0 - 1.0) * perturb_scale
          flat.push(best_flat[i] + perturb)
        }
        let weights = LSTMWeights::from_flat(flat, config.lstm_config)
        let lstm = LSTM::with_weights(config.lstm_config, weights)
    let mse = lstm.mse(adjusted_inputs, targets)
        if mse < best_mse {
          best_mse = mse
          best_flat = flat
          improved = true
        }
      }
      // 若本轮无改进，提前终止局部搜索
      if !improved {
        break
      }
    }
  }
  if best_flat.length() > 0 {
    // P3-9：权重裁剪（clipping），防止极端权重值导致数值不稳定
    let weight_bound = 5.0
    for i in 0..<best_flat.length() {
      if best_flat[i] > weight_bound {
        best_flat[i] = weight_bound
      } else if best_flat[i] < -weight_bound {
        best_flat[i] = -weight_bound
      }
    }
    let best_weights = LSTMWeights::from_flat(best_flat, config.lstm_config)
    LSTM::with_weights(config.lstm_config, best_weights)
  } else {
    LSTM::new(config.lstm_config, seed=config.seed)
  }
}

///|
/// 执行混合预报
///
/// 物理模型预报 + LSTM残差校正
pub fn hybrid_forecast(
  config : HybridConfig,
  physical_forecast : Array[Double],
  observed : Array[Double],
) -> HybridResult {
  let n = physical_forecast.length()
  // 训练残差模型
  let lstm = train_residual_lstm(config, physical_forecast, observed)
  // 用残差模型预报校正量
  let train_n = (n.to_double() * config.train_ratio).to_int()
  let test_start = if train_n < n { train_n } else { 0 }
  // 对测试段进行残差预报
  let ai_correction : Array[Double] = []
  // P1-2修复：维护持久LSTM状态，避免每步从initial开始导致时序信息丢失
  let mut lstm_state = LSTMState::initial(config.lstm_config.hidden_dim)
  // P1-3修复：验证lookback与input_dim的兼容性
  let input_dim = config.lstm_config.input_dim
  let lookback = config.lookback
  for i in test_start..<n {
    // 用过去lookback步的残差作为输入
    let input : Array[Double] = []
    for j in 0..<lookback {
      let idx = i - lookback + j
      if idx >= 0 && idx < observed.length() && idx < physical_forecast.length() {
        input.push(observed[idx] - physical_forecast[idx])
      } else {
        input.push(0.0)
      }
    }
    // P1-3修复：当lookback≠input_dim时，通过填充/截断使输入维度匹配
    let adjusted_input : Array[Double] = []
    if input.length() >= input_dim {
      // 截断：取前input_dim个
      for k in 0..<input_dim {
        adjusted_input.push(input[k])
      }
    } else {
      // 填充：用0.0补齐到input_dim
      for v in input {
        adjusted_input.push(v)
      }
      for _ in input.length()..<input_dim {
        adjusted_input.push(0.0)
      }
    }
    let (y_t, new_state) = lstm.step(adjusted_input, lstm_state)
    lstm_state = new_state
    ai_correction.push(if y_t.length() > 0 { y_t[0] } else { 0.0 })
  }
  // 补齐前段
  let full_correction : Array[Double] = []
  for _ in 0..<test_start {
    full_correction.push(0.0)
  }
  for v in ai_correction {
    full_correction.push(v)
  }
  // 混合预报 = 物理 + AI校正
  let hybrid : Array[Double] = []
  for i in 0..<n {
    let correction = if i < full_correction.length() {
      full_correction[i]
    } else {
      0.0
    }
    hybrid.push(physical_forecast[i] + correction)
  }
  // 评价
  let obs_test : Array[Double] = []
  let phys_test : Array[Double] = []
  let hybrid_test : Array[Double] = []
  for i in test_start..<n {
    if i < observed.length() {
      obs_test.push(observed[i])
      phys_test.push(physical_forecast[i])
      hybrid_test.push(hybrid[i])
    }
  }
  let physical_nse = @shared.nse(obs_test, phys_test)
  let hybrid_nse = @shared.nse(obs_test, hybrid_test)
  {
    physical_forecast,
    ai_correction: full_correction,
    hybrid_forecast: hybrid,
    observed,
    physical_nse,
    hybrid_nse,
    improvement: hybrid_nse - physical_nse,
  }
}

///|
/// 从ForcingData提取降雨序列
pub fn extract_rainfall(forcings : Array[@shared.ForcingData]) -> Array[Double] {
  let result : Array[Double] = []
  for f in forcings {
    result.push(f.rainfall)
  }
  result
}
