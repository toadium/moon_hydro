///|
/// 扩展评价指标模块
///
/// 补充水文预报中常用的扩展评价指标：
/// - LogNSE：对数Nash-Sutcliffe效率系数（低流敏感）
/// - KGE分解指标：r（相关系数）、alpha（变异系数比）、beta（均值比）
/// - MAE：平均绝对误差
/// - MSE：均方误差
/// - RSR：Root Mean Square Error Standard deviation Ratio
/// - PFC：Percent Forecast Correct
/// - Skill Score：相对于基准模型的技巧评分
/// - Persistence Index：持续性指数
/// - Index of Agreement：一致性指数（Willmott 1981）

///|
/// 计算对数Nash-Sutcliffe效率系数
///
/// LogNSE = 1 - Σ(ln(obs) - ln(sim))² / Σ(ln(obs) - ln(obs_mean))²
/// 对低流更敏感，避免洪峰主导评价
/// 注意：obs和sim必须为正值
pub fn log_nse(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  // 检查正值
  for i in 0..<n {
    if observed[i] <= 0.0 || simulated[i] <= 0.0 {
      return 0.0
    }
  }
  let log_obs : Array[Double] = []
  let log_sim : Array[Double] = []
  for i in 0..<n {
    log_obs.push(@math.ln(observed[i]))
    log_sim.push(@math.ln(simulated[i]))
  }
  nse(log_obs, log_sim)
}

///|
/// KGE分解指标
///
/// 返回(r, alpha, beta)
/// r: 皮尔逊相关系数
/// alpha: sim_std / obs_std (变异系数比)
/// beta: sim_mean / obs_mean (均值比)
pub fn kge_decomposition(
  observed : Array[Double],
  simulated : Array[Double],
) -> (Double, Double, Double) {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return (0.0, 0.0, 0.0)
  }
  let obs_mean = observed.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  let sim_mean = simulated.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
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
  let r = if obs_std > 0.0 && sim_std > 0.0 {
    cov / (n.to_double() * obs_std * sim_std)
  } else {
    0.0
  }
  let alpha = if obs_std > 0.0 { sim_std / obs_std } else { 0.0 }
  let beta = if obs_mean != 0.0 { sim_mean / obs_mean } else { 0.0 }
  (r, alpha, beta)
}

///|
/// 计算平均绝对误差MAE
///
/// MAE = Σ|obs - sim| / n
pub fn mae(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let mut sum_abs = 0.0
  for i in 0..<n {
    sum_abs = sum_abs + (observed[i] - simulated[i]).abs()
  }
  sum_abs / n.to_double()
}

///|
/// 计算均方误差MSE
///
/// MSE = Σ(obs - sim)² / n
pub fn mse(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let mut sum_sq = 0.0
  for i in 0..<n {
    let diff = observed[i] - simulated[i]
    sum_sq = sum_sq + diff * diff
  }
  sum_sq / n.to_double()
}

///|
/// 计算RSR(Root Mean Square Error Standard deviation Ratio)
///
/// RSR = RMSE / stddev(obs)
/// RSR=0完美，RSR>1不如观测均值
/// GB/T 22482中常用指标
pub fn rsr(observed : Array[Double], simulated : Array[Double]) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 1.0
  }
  let rmse_val = rmse(observed, simulated)
  let obs_mean = observed.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  let mut var_sum = 0.0
  for v in observed {
    let diff = v - obs_mean
    var_sum = var_sum + diff * diff
  }
  let obs_std = @math.pow(var_sum / n.to_double(), 0.5)
  if obs_std == 0.0 {
    return 1.0
  }
  rmse_val / obs_std
}

///|
/// 计算一致性指数(Index of Agreement, Willmott 1981)
///
/// d = 1 - Σ(obs - sim)² / Σ(|sim - obs_mean| + |obs - obs_mean|)²
/// d=1完美匹配，d=0完全不一致
pub fn index_of_agreement(
  observed : Array[Double],
  simulated : Array[Double],
) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let obs_mean = observed.fold(init=0.0, (acc, v) => acc + v) / n.to_double()
  let mut sum_sq_err = 0.0
  let mut sum_sq_pot = 0.0
  for i in 0..<n {
    let diff_err = observed[i] - simulated[i]
    sum_sq_err = sum_sq_err + diff_err * diff_err
    let pot = (simulated[i] - obs_mean).abs() + (observed[i] - obs_mean).abs()
    sum_sq_pot = sum_sq_pot + pot * pot
  }
  if sum_sq_pot == 0.0 {
    return 0.0
  }
  1.0 - sum_sq_err / sum_sq_pot
}

///|
/// 计算技巧评分(Skill Score)
///
/// SS = 1 - MSE(sim) / MSE(reference)
/// reference通常用持续性预报(上时刻观测值)
/// SS>0表示优于基准，SS=1完美
pub fn skill_score(
  observed : Array[Double],
  simulated : Array[Double],
  reference : Array[Double],
) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() || n != reference.length() {
    return 0.0
  }
  let mse_sim = mse(observed, simulated)
  let mse_ref = mse(observed, reference)
  if mse_ref == 0.0 {
    return 0.0
  }
  1.0 - mse_sim / mse_ref
}

///|
/// 计算持续性指数(Persistence Index)
///
/// PI = 1 - Σ(obs(t) - sim(t))² / Σ(obs(t) - obs(t-1))²
/// 评价相对于持续性预报的改进
pub fn persistence_index(
  observed : Array[Double],
  simulated : Array[Double],
) -> Double {
  let n = observed.length()
  if n < 2 || n != simulated.length() {
    return 0.0
  }
  let mut sum_sq_err = 0.0
  let mut sum_sq_persist = 0.0
  for i in 1..<n {
    let diff_err = observed[i] - simulated[i]
    sum_sq_err = sum_sq_err + diff_err * diff_err
  }
  for i in 1..<n {
    let diff_persist = observed[i] - observed[i - 1]
    sum_sq_persist = sum_sq_persist + diff_persist * diff_persist
  }
  if sum_sq_persist == 0.0 {
    return 0.0
  }
  1.0 - sum_sq_err / sum_sq_persist
}

///|
/// 计算百分率预报正确率(PFC)
///
/// PFC = #{|sim - obs| / obs < threshold} / n × 100%
/// threshold: 许可相对误差阈值(默认20%)
pub fn percent_forecast_correct(
  observed : Array[Double],
  simulated : Array[Double],
  threshold? : Double = 0.2,
) -> Double {
  let n = observed.length()
  if n == 0 || n != simulated.length() {
    return 0.0
  }
  let mut correct_count = 0
  for i in 0..<n {
    if observed[i].abs() > 0.000001 {
      let rel_error = (simulated[i] - observed[i]).abs() / observed[i].abs()
      if rel_error < threshold {
        correct_count = correct_count + 1
      }
    }
  }
  correct_count.to_double() / n.to_double() * 100.0
}

///|
/// 综合扩展评价指标
pub(all) struct ExtendedEvaluationResult {
  log_nse : Double // 对数NSE
  r : Double // 相关系数
  alpha : Double // 变异系数比
  beta : Double // 均值比
  mae : Double // 平均绝对误差
  mse : Double // 均方误差
  rsr : Double // RSR
  index_of_agreement : Double // 一致性指数
  persistence_index : Double // 持续性指数
  percent_forecast_correct : Double // 预报正确率(%)
} derive(Debug, ToJson, FromJson)

///|
/// 一次性计算所有扩展评价指标
pub fn evaluate_extended(
  observed : Array[Double],
  simulated : Array[Double],
) -> ExtendedEvaluationResult {
  let log_nse_val = log_nse(observed, simulated)
  let (r_val, alpha_val, beta_val) = kge_decomposition(observed, simulated)
  let mae_val = mae(observed, simulated)
  let mse_val = mse(observed, simulated)
  let rsr_val = rsr(observed, simulated)
  let d_val = index_of_agreement(observed, simulated)
  let pi_val = persistence_index(observed, simulated)
  let pfc_val = percent_forecast_correct(observed, simulated)
  {
    log_nse: log_nse_val,
    r: r_val,
    alpha: alpha_val,
    beta: beta_val,
    mae: mae_val,
    mse: mse_val,
    rsr: rsr_val,
    index_of_agreement: d_val,
    persistence_index: pi_val,
    percent_forecast_correct: pfc_val,
  }
}

///|
/// RSR预报等级判定（GB/T 22482）
///
/// RSR ≤ 0.5 优秀，≤ 0.6 良好，≤ 0.7 合格，否则不合格
pub fn forecast_grade_rsr(rsr_val : Double) -> ForecastGrade {
  if rsr_val <= 0.5 {
    Excellent
  } else if rsr_val <= 0.6 {
    Good
  } else if rsr_val <= 0.7 {
    Qualified
  } else {
    Unqualified
  }
}
