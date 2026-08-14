///|
/// 水文时间序列分析测试

///|
test "moving_average 滑动平均" {
  let series = [1.0, 2.0, 3.0, 4.0, 5.0]
  let ma = moving_average(series, window=3)
  assert_eq(ma.length(), 5)
  // 中间点 (1+2+3)/3 = 2.0
  assert_true((ma[1] - 2.0).abs() < 0.001)
  // (2+3+4)/3 = 3.0
  assert_true((ma[2] - 3.0).abs() < 0.001)
}

///|
test "cumulative_sum 累积和" {
  let series = [1.0, 2.0, 3.0, 4.0]
  let cs = cumulative_sum(series)
  assert_true((cs[0] - 1.0).abs() < 0.001)
  assert_true((cs[1] - 3.0).abs() < 0.001)
  assert_true((cs[2] - 6.0).abs() < 0.001)
  assert_true((cs[3] - 10.0).abs() < 0.001)
}

///|
test "detect_peaks 洪峰检测" {
  let series = [1.0, 5.0, 2.0, 8.0, 3.0, 6.0, 1.0]
  let peaks = detect_peaks(series)
  // 峰值在t=1(5.0), t=3(8.0), t=5(6.0)
  assert_true(peaks.contains(1))
  assert_true(peaks.contains(3))
  assert_true(peaks.contains(5))
}

///|
test "detect_peaks 阈值过滤" {
  let series = [1.0, 3.0, 1.0, 10.0, 1.0]
  let peaks = detect_peaks(series, threshold=5.0)
  // 只有t=3(10.0)超过阈值5
  assert_eq(peaks.length(), 1)
  assert_true(peaks.contains(3))
}

///|
test "baseflow_separation 基流分离" {
  // 模拟一个洪水过程：基流+快速流
  let streamflow = [
    5.0, 5.0, 5.0, 10.0, 30.0, 50.0, 40.0, 20.0, 8.0, 5.0, 5.0, 5.0,
  ]
  let baseflow = baseflow_separation(streamflow)
  assert_eq(baseflow.length(), 12)
  // 基流应小于等于总流
  for i in 0..<12 {
    assert_true(baseflow[i] <= streamflow[i] + 0.001)
    assert_true(baseflow[i] >= 0.0)
  }
  // 洪峰附近基流应远小于总流
  assert_true(baseflow[5] < streamflow[5] * 0.5)
}

///|
test "flow_duration_curve 流量历时曲线" {
  let series = [10.0, 50.0, 30.0, 20.0, 40.0]
  let fdc = flow_duration_curve(series)
  assert_eq(fdc.length(), 5)
  // 第一个点应是最大值50.0，超越概率20%
  let (p1, q1) = fdc[0]
  assert_true((q1 - 50.0).abs() < 0.001)
  assert_true((p1 - 20.0).abs() < 0.001)
  // 最后一个点应是最小值10.0，超越概率100%
  let (p5, q5) = fdc[4]
  assert_true((q5 - 10.0).abs() < 0.001)
  assert_true((p5 - 100.0).abs() < 0.001)
}

///|
test "gumbel_estimate Gumbel参数估计" {
  // 模拟年最大值序列
  let am_series = [100.0, 120.0, 80.0, 150.0, 90.0, 110.0, 130.0, 70.0]
  let (mu, beta) = gumbel_estimate(am_series)
  // beta应为正
  assert_true(beta > 0.0)
  // mu应小于均值（因为mu = mean - 0.5772*beta）
  let mean = 100.0 + 120.0 + 80.0 + 150.0 + 90.0 + 110.0 + 130.0 + 70.0
  let mean_val = mean / 8.0
  assert_true(mu < mean_val)
}

///|
test "gumbel_return_value 重现期估计" {
  let (mu, beta) = gumbel_estimate([
    100.0, 120.0, 80.0, 150.0, 90.0, 110.0, 130.0, 70.0,
  ])
  // 10年一遇应大于2年一遇
  let q10 = gumbel_return_value(mu, beta, return_period=10.0)
  let q2 = gumbel_return_value(mu, beta, return_period=2.0)
  assert_true(q10 > q2)
  // 100年一遇应大于10年一遇
  let q100 = gumbel_return_value(mu, beta, return_period=100.0)
  assert_true(q100 > q10)
}

///|
test "annual_maxima 年最大值序列" {
  // 2年数据，每年4个时段
  let series = [5.0, 10.0, 3.0, 7.0, 8.0, 15.0, 2.0, 6.0]
  let am = annual_maxima(series, year_length=4)
  assert_eq(am.length(), 2)
  // 第一年最大=10.0
  assert_true((am[0] - 10.0).abs() < 0.001)
  // 第二年最大=15.0
  assert_true((am[1] - 15.0).abs() < 0.001)
}

///|
test "ts_stats 时间序列统计" {
  let series = [1.0, 2.0, 3.0, 4.0, 5.0]
  let stats = ts_stats(series)
  assert_eq(stats.count, 5)
  assert_true((stats.mean - 3.0).abs() < 0.001)
  assert_true((stats.sum - 15.0).abs() < 0.001)
  assert_true((stats.min_val - 1.0).abs() < 0.001)
  assert_true((stats.max_val - 5.0).abs() < 0.001)
  assert_true((stats.range - 4.0).abs() < 0.001)
  // 线性趋势斜率应为1.0（等差数列）
  assert_true((stats.trend - 1.0).abs() < 0.001)
}

///|
test "ts_stats 空序列" {
  let stats = ts_stats([])
  assert_eq(stats.count, 0)
  assert_true((stats.mean - 0.0).abs() < 0.001)
}

///|
test "moving_average 空序列" {
  let ma = moving_average([], window=3)
  assert_eq(ma.length(), 0)
}

///|
test "baseflow_separation 恒定流" {
  // 恒定流：基流应等于总流
  let streamflow = [10.0, 10.0, 10.0, 10.0, 10.0]
  let baseflow = baseflow_separation(streamflow)
  for i in 0..<5 {
    assert_true((baseflow[i] - 10.0).abs() < 1.0)
  }
}
