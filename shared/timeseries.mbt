///|
/// 水文时间序列分析工具
///
/// 提供常用水文时间序列分析方法：
/// - 滑动平均/累积和
/// - 洪峰检测
/// - 基流分离（递归数字滤波法）
/// - 流量历时曲线
/// - 重现期估计（Gumbel分布）

///|
/// 滑动平均
///
/// window: 窗口大小（时段数）
/// 注意：偶数窗口非对称（中心偏移），建议使用奇数窗口
pub fn moving_average(series : Array[Double], window~ : Int) -> Array[Double] {
  let n = series.length()
  if n == 0 || window <= 0 {
    return []
  }
  let result : Array[Double] = []
  let half = window / 2
  for i in 0..<n {
    let mut sum = 0.0
    let mut count = 0
    for k in -half..<=(window - half - 1) {
      let idx = i + k
      if idx >= 0 && idx < n {
        sum = sum + series[idx]
        count = count + 1
      }
    }
    if count > 0 {
      result.push(sum / count.to_double())
    } else {
      result.push(0.0)
    }
  }
  result
}

///|
/// 累积和
pub fn cumulative_sum(series : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  let mut acc = 0.0
  for v in series {
    acc = acc + v
    result.push(acc)
  }
  result
}

///|
/// 洪峰检测
///
/// 返回洪峰索引列表（局部极大值，且大于阈值）
pub fn detect_peaks(
  series : Array[Double],
  threshold? : Double = 0.0,
) -> Array[Int] {
  let n = series.length()
  let peaks : Array[Int] = []
  if n < 3 {
    return peaks
  }
  // P2-15修复：检查首点是否为洪峰（修复：>=与中间点后非严格一致）
  if series[0] >= series[1] && series[0] > threshold {
    peaks.push(0)
  }
  for i in 1..<(n - 1) {
    if series[i] > series[i - 1] &&
      series[i] >= series[i + 1] &&
      series[i] > threshold {
      peaks.push(i)
    }
  }
  // 检查最后一个点
  if n >= 2 && series[n - 1] > series[n - 2] && series[n - 1] > threshold {
    peaks.push(n - 1)
  }
  peaks
}

///|
/// 基流分离（递归数字滤波法，Lyne-Hollick算法）
///
/// alpha: 滤波参数（0.925为常用值）
/// passes: 前向/后向滤波次数（通常2-3次）
pub fn baseflow_separation(
  streamflow : Array[Double],
  alpha? : Double = 0.925,
  passes? : Int = 2,
) -> Array[Double] {
  let n = streamflow.length()
  if n == 0 {
    return []
  }
  // 初始基流 = 总流
  let baseflow : Array[Double] = []
  for v in streamflow {
    baseflow.push(v)
  }
  // 多次前向-后向滤波（每遍输入为上一遍的baseflow结果）
  for _ in 0..<passes {
    // 前向滤波（输入为当前baseflow）
    let quickflow : Array[Double] = Array::make(n, 0.0)
    quickflow[0] = 0.0
    for i in 1..<n {
      let q = alpha * quickflow[i - 1] +
        (1.0 + alpha) / 2.0 * (baseflow[i] - baseflow[i - 1])
      quickflow[i] = if q > 0.0 {
        q
      } else if q < baseflow[i] {
        q
      } else {
        baseflow[i]
      }
      if quickflow[i] > baseflow[i] {
        quickflow[i] = baseflow[i]
      }
      if quickflow[i] < 0.0 {
        quickflow[i] = 0.0
      }
    }
    // 后向滤波
    let quickflow_b : Array[Double] = Array::make(n, 0.0)
    quickflow_b[n - 1] = quickflow[n - 1]
    for i in 1..<n {
      let idx = n - 1 - i
      let q = alpha * quickflow_b[idx + 1] +
        (1.0 + alpha) / 2.0 * (quickflow[idx] - quickflow[idx + 1])
      quickflow_b[idx] = if q > 0.0 { q } else { 0.0 }
      if quickflow_b[idx] > baseflow[idx] {
        quickflow_b[idx] = baseflow[idx]
      }
    }
    // 基流 = 输入 - 快速流
    for i in 0..<n {
      baseflow[i] = baseflow[i] - quickflow_b[i]
      if baseflow[i] < 0.0 {
        baseflow[i] = 0.0
      }
    }
  }
  baseflow
}

///|
/// 流量历时曲线
///
/// 将流量序列降序排列，返回(超越概率%, 流量值)对
pub fn flow_duration_curve(series : Array[Double]) -> Array[(Double, Double)] {
  let n = series.length()
  if n == 0 {
    return []
  }
  // 复制并降序排序
  let sorted : Array[Double] = []
  for v in series {
    sorted.push(v)
  }
  sorted.sort_by(fn(a, b) { if a > b { -1 } else if a < b { 1 } else { 0 } })
  // 计算超越概率
  let result : Array[(Double, Double)] = []
  for i in 0..<n {
    let exceedance = (i + 1).to_double() / n.to_double() * 100.0
    result.push((exceedance, sorted[i]))
  }
  result
}

///|
/// Gumbel分布参数估计（矩法）
///
/// 返回(mu, beta)参数
/// mu = mean - 0.5772 * beta
/// beta = std * sqrt(6) / pi
pub fn gumbel_estimate(series : Array[Double]) -> (Double, Double) {
  let n = series.length()
  if n == 0 {
    return (0.0, 1.0)
  }
  let mut sum = 0.0
  for v in series {
    sum = sum + v
  }
  let mean = sum / n.to_double()
  let mut var_sum = 0.0
  for v in series {
    let diff = v - mean
    var_sum = var_sum + diff * diff
  }
  let variance = if n > 1 { var_sum / (n - 1).to_double() } else { 0.0 }
  let stddev = @math.pow(variance, 0.5)
  let beta = stddev * @math.pow(6.0, 0.5) / @math.PI
  let mu = mean - 0.5772156649 * beta
  (mu, beta)
}

///|
/// Gumbel分布重现期估计
///
/// 给定Gumbel参数和重现期T(年)，返回对应设计值
/// x_T = mu - beta * ln(-ln(1 - 1/T))
pub fn gumbel_return_value(
  mu : Double,
  beta : Double,
  return_period~ : Double,
) -> Double {
  if return_period <= 1.0 {
    return @double.not_a_number
  }
  let p = 1.0 / return_period
  let x = mu - beta * @math.ln(-@math.ln(1.0 - p))
  x
}

///|
/// 计算年最大值序列（AM系列）
///
/// 将连续序列按年分割（year_length为每年时段数），取各年最大值
pub fn annual_maxima(
  series : Array[Double],
  year_length~ : Int,
) -> Array[Double] {
  let n = series.length()
  if n == 0 || year_length <= 0 {
    return []
  }
  let result : Array[Double] = []
  let n_years = n / year_length
  for y in 0..<n_years {
    let mut max_val = series[y * year_length]
    for t in 0..<year_length {
      let idx = y * year_length + t
      if idx < n && series[idx] > max_val {
        max_val = series[idx]
      }
    }
    result.push(max_val)
  }
  // 处理剩余部分
  let remainder = n % year_length
  if remainder > 0 {
    let mut max_val = series[n_years * year_length]
    for t in 0..<remainder {
      let idx = n_years * year_length + t
      if series[idx] > max_val {
        max_val = series[idx]
      }
    }
    result.push(max_val)
  }
  result
}

///|
/// 时间序列统计摘要
pub(all) struct TimeSeriesStats {
  mean : Double
  stddev : Double
  min_val : Double
  max_val : Double
  range : Double
  sum : Double
  count : Int
  trend : Double // 线性趋势斜率(最小二乘)
} derive(Debug, ToJson, FromJson)

///|
/// 计算时间序列统计摘要
pub fn ts_stats(series : Array[Double]) -> TimeSeriesStats {
  let n = series.length()
  if n == 0 {
    return {
      mean: 0.0,
      stddev: 0.0,
      min_val: 0.0,
      max_val: 0.0,
      range: 0.0,
      sum: 0.0,
      count: 0,
      trend: 0.0,
    }
  }
  let mut sum = 0.0
  let mut min_val = series[0]
  let mut max_val = series[0]
  for v in series {
    sum = sum + v
    if v < min_val {
      min_val = v
    }
    if v > max_val {
      max_val = v
    }
  }
  let mean = sum / n.to_double()
  let mut var_sum = 0.0
  for v in series {
    let diff = v - mean
    var_sum = var_sum + diff * diff
  }
  let stddev = if n > 1 {
    @math.pow(var_sum / (n - 1).to_double(), 0.5)
  } else {
    0.0
  }
  // 线性趋势（最小二乘斜率）
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut sum_xy = 0.0
  let mut sum_xx = 0.0
  for i in 0..<n {
    let x = i.to_double()
    let y = series[i]
    sum_x = sum_x + x
    sum_y = sum_y + y
    sum_xy = sum_xy + x * y
    sum_xx = sum_xx + x * x
  }
  let nd = n.to_double()
  let denom = nd * sum_xx - sum_x * sum_x
  let trend = if denom.abs() > 0.000001 {
    (nd * sum_xy - sum_x * sum_y) / denom
  } else {
    0.0
  }
  {
    mean,
    stddev,
    min_val,
    max_val,
    range: max_val - min_val,
    sum,
    count: n,
    trend,
  }
}
