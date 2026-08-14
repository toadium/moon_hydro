///|
/// 评价指标增强模块
///
/// 实现GB/T 22482-2008《水文情报预报规范》预报等级判定
/// 扩展NSE/KGE/PBIAS之外的专业评价指标

///|
/// 预报等级（GB/T 22482-2008）
pub(all) enum ForecastGrade {
  Excellent // 优秀（甲等）
  Good // 良好（乙等）
  Qualified // 合格（丙等）
  Unqualified // 不合格
} derive(Debug, ToJson, FromJson, Eq)

///|
/// 预报项目类型
pub(all) enum ForecastType {
  FloodPeak // 洪峰流量
  FloodVolume // 洪量
  FloodProcess // 洪水过程
  WaterLevel // 水位
  RunoffDepth // 径流深
} derive(Debug, ToJson, FromJson, Eq)

///|
/// 综合评价指标
pub(all) struct EvaluationResult {
  nse : Double // Nash-Sutcliffe效率系数
  kge : Double // Kling-Gupta效率系数
  pbias : Double // 偏差百分比
  rmse : Double // 均方根误差
  r_squared : Double // 决定系数
  peak_error : Double // 洪峰相对误差(%)
  peak_time_error : Int // 洪峰时间误差(时段数)
  volume_error : Double // 洪量相对误差(%)
  grade : ForecastGrade // 综合预报等级
  grade_nse : ForecastGrade // NSE单项等级
  grade_pbias : ForecastGrade // PBIAS单项等级
} derive(Debug, ToJson, FromJson)

///|
/// GB/T 22482预报等级判定标准
///
/// 根据预报类型和许可误差判定等级
/// 洪峰流量：许可误差20%
/// 洪量：许可误差10%
/// 洪水过程：NSE判定
pub fn forecast_grade_nse(nse_val : Double) -> ForecastGrade {
  // NSE等级标准
  if nse_val >= 0.9 {
    Excellent
  } else if nse_val >= 0.7 {
    Good
  } else if nse_val >= 0.5 {
    Qualified
  } else {
    Unqualified
  }
}

///|
/// PBIAS预报等级判定
///
/// 不同预报类型有不同的许可误差标准
pub fn forecast_grade_pbias(
  pbias_val : Double,
  forecast_type~ : ForecastType,
) -> ForecastGrade {
  let abs_bias = pbias_val.abs()
  // 许可误差标准（GB/T 22482-2008）
  let threshold_excellent : Double = match forecast_type {
    FloodPeak => 5.0
    FloodVolume => 5.0
    FloodProcess => 5.0
    WaterLevel => 3.0
    RunoffDepth => 5.0
  }
  let threshold_good : Double = match forecast_type {
    FloodPeak => 10.0
    FloodVolume => 10.0
    FloodProcess => 10.0
    WaterLevel => 8.0
    RunoffDepth => 10.0
  }
  let threshold_qualified : Double = match forecast_type {
    FloodPeak => 20.0
    FloodVolume => 10.0
    FloodProcess => 20.0
    WaterLevel => 15.0
    RunoffDepth => 20.0
  }
  if abs_bias <= threshold_excellent {
    Excellent
  } else if abs_bias <= threshold_good {
    Good
  } else if abs_bias <= threshold_qualified {
    Qualified
  } else {
    Unqualified
  }
}

///|
/// 综合预报等级判定
///
/// 取NSE和PBIAS中较低等级作为综合等级
pub fn comprehensive_grade(
  grade_nse~ : ForecastGrade,
  grade_pbias~ : ForecastGrade,
) -> ForecastGrade {
  // 等级排序：Excellent(0) > Good(1) > Qualified(2) > Unqualified(3)
  let rank = fn(g : ForecastGrade) -> Int {
    match g {
      Excellent => 0
      Good => 1
      Qualified => 2
      Unqualified => 3
    }
  }
  let r_nse = rank(grade_nse)
  let r_pbias = rank(grade_pbias)
  let r_worst = if r_nse > r_pbias { r_nse } else { r_pbias }
  match r_worst {
    0 => Excellent
    1 => Good
    2 => Qualified
    _ => Unqualified
  }
}

///|
/// 计算洪峰相对误差
///
/// peak_error = (sim_peak - obs_peak) / obs_peak × 100%
pub fn peak_relative_error(
  observed : Array[Double],
  simulated : Array[Double],
) -> Double {
  let mut obs_peak = 0.0
  let mut sim_peak = 0.0
  for v in observed {
    if v > obs_peak {
      obs_peak = v
    }
  }
  for v in simulated {
    if v > sim_peak {
      sim_peak = v
    }
  }
  if obs_peak == 0.0 {
    return 0.0
  }
  (sim_peak - obs_peak) / obs_peak * 100.0
}

///|
/// 计算洪峰时间误差
///
/// 返回模拟洪峰与观测洪峰的时段差（正：滞后，负：超前）
pub fn peak_time_error(
  observed : Array[Double],
  simulated : Array[Double],
) -> Int {
  let mut obs_peak_time = 0
  let mut obs_peak = 0.0
  let mut sim_peak_time = 0
  let mut sim_peak = 0.0
  for i in 0..<observed.length() {
    if observed[i] > obs_peak {
      obs_peak = observed[i]
      obs_peak_time = i
    }
  }
  for i in 0..<simulated.length() {
    if simulated[i] > sim_peak {
      sim_peak = simulated[i]
      sim_peak_time = i
    }
  }
  sim_peak_time - obs_peak_time
}

///|
/// 计算洪量相对误差
///
/// volume_error = (Σsim - Σobs) / Σobs × 100%
pub fn volume_relative_error(
  observed : Array[Double],
  simulated : Array[Double],
) -> Double {
  let mut sum_obs = 0.0
  let mut sum_sim = 0.0
  for i in 0..<observed.length() {
    sum_obs = sum_obs + observed[i]
    if i < simulated.length() {
      sum_sim = sum_sim + simulated[i]
    }
  }
  if sum_obs == 0.0 {
    return 0.0
  }
  (sum_sim - sum_obs) / sum_obs * 100.0
}

///|
/// 综合评价指标计算
///
/// 一次性计算所有评价指标并判定预报等级
pub fn evaluate(
  observed : Array[Double],
  simulated : Array[Double],
  forecast_type? : ForecastType = FloodProcess,
) -> EvaluationResult {
  let nse_val = nse(observed, simulated)
  let kge_val = kge(observed, simulated)
  let pbias_val = pbias(observed, simulated)
  let rmse_val = rmse(observed, simulated)
  let r2_val = r_squared(observed, simulated)
  let peak_err = peak_relative_error(observed, simulated)
  let peak_time_err = peak_time_error(observed, simulated)
  let vol_err = volume_relative_error(observed, simulated)
  let g_nse = forecast_grade_nse(nse_val)
  let g_pbias = forecast_grade_pbias(pbias_val, forecast_type~)
  let g_comprehensive = comprehensive_grade(
    grade_nse=g_nse,
    grade_pbias=g_pbias,
  )
  {
    nse: nse_val,
    kge: kge_val,
    pbias: pbias_val,
    rmse: rmse_val,
    r_squared: r2_val,
    peak_error: peak_err,
    peak_time_error: peak_time_err,
    volume_error: vol_err,
    grade: g_comprehensive,
    grade_nse: g_nse,
    grade_pbias: g_pbias,
  }
}

///|
/// 格式化预报等级为中文描述
pub fn ForecastGrade::to_chinese(self : ForecastGrade) -> String {
  match self {
    Excellent => "甲等（优秀）"
    Good => "乙等（良好）"
    Qualified => "丙等（合格）"
    Unqualified => "不合格"
  }
}
