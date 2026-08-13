///|
/// 计算Nash-Sutcliffe效率系数
///
/// NSE = 1 - Σ(obs - sim)² / Σ(obs - obs_mean)²
/// NSE=1完美匹配，NSE=0与观测均值等效，NSE<0不如观测均值
pub fn nse(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let obs_mean = observed.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  let mut sum_sq_err = 0.0
  let mut sum_sq_obs = 0.0
  for i in 0..<n {
    let diff_err = observed[i] - simulated[i]
    let diff_obs = observed[i] - obs_mean
    sum_sq_err = sum_sq_err + diff_err * diff_err
    sum_sq_obs = sum_sq_obs + diff_obs * diff_obs
  }
  if sum_sq_obs == 0.0 {
    return 0.0
  }
  1.0 - sum_sq_err / sum_sq_obs
}

///|
/// 计算Kling-Gupta效率系数
///
/// KGE = 1 - √((r-1)² + (α-1)² + (β-1)²)
/// r: 皮尔逊相关系数
/// α: sim_std / obs_std (变异系数比)
/// β: sim_mean / obs_mean (均值比)
pub fn kge(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let obs_mean = observed.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  let sim_mean = simulated.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  // 标准差
  let mut obs_var = 0.0
  let mut sim_var = 0.0
  let mut cov = 0.0
  for i in 0..<n {
    let obs_dev = observed[i] - obs_mean
    let sim_dev = simulated[i] - sim_mean
    obs_var = obs_var + obs_dev * obs_dev
    sim_var = sim_var + sim_dev * sim_dev
    cov = cov + obs_dev * sim_dev
  }
  let obs_std = @math.pow(obs_var / n.to_double(), 0.5)
  let sim_std = @math.pow(sim_var / n.to_double(), 0.5)
  // 相关系数
  let r = if obs_std > 0.0 && sim_std > 0.0 {
    cov / (n.to_double() * obs_std * sim_std)
  } else {
    0.0
  }
  // α和β
  let alpha = if obs_std > 0.0 { sim_std / obs_std } else { 0.0 }
  let beta = if obs_mean != 0.0 { sim_mean / obs_mean } else { 0.0 }
  // KGE
  let dr = r - 1.0
  let da = alpha - 1.0
  let db = beta - 1.0
  1.0 - @math.pow(dr * dr + da * da + db * db, 0.5)
}

///|
/// 计算偏差百分比
///
/// PBIAS = Σ(sim - obs) / Σ(obs) × 100%
/// PBIAS=0无偏差，正值表示高估，负值表示低估
pub fn pbias(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let mut sum_diff = 0.0
  let mut sum_obs = 0.0
  for i in 0..<n {
    sum_diff = sum_diff + (simulated[i] - observed[i])
    sum_obs = sum_obs + observed[i]
  }
  if sum_obs == 0.0 {
    return 0.0
  }
  sum_diff / sum_obs * 100.0
}

///|
/// 单位线卷积汇流
///
/// Q(t) = Σ UH(τ) * P(t-τ)  for τ=0..n
/// uh: 单位线纵坐标数组
/// p: 净雨过程序列
/// 返回汇流过程序列
pub fn unit_hydrograph_convolution(
  uh : Array[Double],
  p : Array[Double],
) -> Array[Double] {
  let n_uh = uh.length()
  let n_p = p.length()
  if n_uh == 0 || n_p == 0 {
    return []
  }
  let n_q = n_p + n_uh - 1
  let q : Array[Double] = []
  for t in 0..<n_q {
    let mut sum = 0.0
    for tau in 0..<n_uh {
      let idx = t - tau
      if idx >= 0 && idx < n_p {
        sum = sum + uh[tau] * p[idx]
      }
    }
    q.push(sum)
  }
  q
}

///|
/// 计算均方根误差RMSE
///
/// RMSE = √(Σ(obs-sim)²/n)
pub fn rmse(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let mut sum_sq = 0.0
  for i in 0..<n {
    let diff = observed[i] - simulated[i]
    sum_sq = sum_sq + diff * diff
  }
  @math.pow(sum_sq / n.to_double(), 0.5)
}

///|
/// 计算决定系数R²
///
/// R² = (Σ(obs-obs_mean)(sim-sim_mean))² / (Σ(obs-obs_mean)² × Σ(sim-sim_mean)²)
pub fn r_squared(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let obs_mean = observed.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  let sim_mean = simulated.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  let mut s_xy = 0.0
  let mut s_xx = 0.0
  let mut s_yy = 0.0
  for i in 0..<n {
    let obs_dev = observed[i] - obs_mean
    let sim_dev = simulated[i] - sim_mean
    s_xy = s_xy + obs_dev * sim_dev
    s_xx = s_xx + obs_dev * obs_dev
    s_yy = s_yy + sim_dev * sim_dev
  }
  if s_xx == 0.0 || s_yy == 0.0 {
    return 0.0
  }
  s_xy * s_xy / (s_xx * s_yy)
}
