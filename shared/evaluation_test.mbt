///|
/// 评价指标增强模块测试
///
/// 测试GB/T 22482预报等级判定、洪峰误差、综合评价

///|
test "forecast_grade_nse NSE等级判定" {
  debug_inspect(forecast_grade_nse(0.95), content="Excellent")
  debug_inspect(forecast_grade_nse(0.85), content="Good")
  debug_inspect(forecast_grade_nse(0.6), content="Qualified")
  debug_inspect(forecast_grade_nse(0.3), content="Unqualified")
}

///|
test "forecast_grade_pbias PBIAS等级判定" {
  // 洪峰流量：5%内优秀，10%内良好，20%内合格
  debug_inspect(
    forecast_grade_pbias(3.0, forecast_type=FloodPeak),
    content="Excellent",
  )
  debug_inspect(
    forecast_grade_pbias(8.0, forecast_type=FloodPeak),
    content="Good",
  )
  debug_inspect(
    forecast_grade_pbias(15.0, forecast_type=FloodPeak),
    content="Qualified",
  )
  debug_inspect(
    forecast_grade_pbias(25.0, forecast_type=FloodPeak),
    content="Unqualified",
  )
}

///|
test "forecast_grade_pbias 水位预报判定" {
  // 水位：3%内优秀，8%内良好，15%内合格
  debug_inspect(
    forecast_grade_pbias(2.0, forecast_type=WaterLevel),
    content="Excellent",
  )
  debug_inspect(
    forecast_grade_pbias(5.0, forecast_type=WaterLevel),
    content="Good",
  )
  debug_inspect(
    forecast_grade_pbias(12.0, forecast_type=WaterLevel),
    content="Qualified",
  )
  debug_inspect(
    forecast_grade_pbias(20.0, forecast_type=WaterLevel),
    content="Unqualified",
  )
}

///|
test "comprehensive_grade 综合等级判定" {
  // NSE优秀 + PBIAS良好 = 综合
  let g = comprehensive_grade(grade_nse=Excellent, grade_pbias=Good)
  debug_inspect(g, content="Good")
  // NSE良好 + PBIAS优秀 = 良好
  let g2 = comprehensive_grade(grade_nse=Good, grade_pbias=Excellent)
  debug_inspect(g2, content="Good")
  // NSE合格 + PBIAS不合格 = 不合格
  let g3 = comprehensive_grade(grade_nse=Qualified, grade_pbias=Unqualified)
  debug_inspect(g3, content="Unqualified")
}

///|
test "peak_relative_error 洪峰相对误差" {
  let obs = [10.0, 50.0, 30.0, 20.0]
  let sim = [12.0, 48.0, 28.0, 18.0]
  // obs_peak=50, sim_peak=48, error=(48-50)/50*100=-4%
  let err = peak_relative_error(obs, sim)
  assert_true((err - -4.0).abs() < 0.001)
}

///|
test "peak_time_error 洪峰时间误差" {
  let obs = [10.0, 50.0, 30.0, 20.0] // 峰值在t=1
  let sim = [10.0, 30.0, 50.0, 20.0] // 峰值在t=2
  // 时间误差=2-1=1（滞后1个时段）
  debug_inspect(peak_time_error(obs, sim), content="1")
}

///|
test "volume_relative_error 洪量相对误差" {
  let obs = [10.0, 20.0, 30.0] // 总量60
  let sim = [12.0, 22.0, 32.0] // 总量66
  // error=(66-60)/60*100=10%
  let err = volume_relative_error(obs, sim)
  assert_true((err - 10.0).abs() < 0.001)
}

///|
test "evaluate 综合评价" {
  let obs = [10.0, 50.0, 30.0, 20.0, 10.0]
  let sim = [12.0, 48.0, 28.0, 18.0, 8.0]
  let result = evaluate(obs, sim, forecast_type=FloodProcess)
  // NSE应非负（匹配较好）
  assert_true(result.nse > 0.0)
  // 应有等级判定
  assert_true(
    result.grade is Excellent ||
    result.grade is Good ||
    result.grade is Qualified ||
    result.grade is Unqualified,
  )
  // 洪峰误差应非零
  assert_true(result.peak_error != 0.0)
}

///|
test "ForecastGrade::to_chinese 中文等级" {
  assert_eq(ForecastGrade::Excellent.to_chinese(), "甲等（优秀）")
  assert_eq(ForecastGrade::Good.to_chinese(), "乙等（良好）")
  assert_eq(ForecastGrade::Qualified.to_chinese(), "丙等（合格）")
  assert_eq(ForecastGrade::Unqualified.to_chinese(), "不合格")
}

///|
test "evaluate 完美匹配=甲等" {
  let obs = [10.0, 50.0, 30.0, 20.0, 10.0]
  let sim = [10.0, 50.0, 30.0, 20.0, 10.0]
  let result = evaluate(obs, sim, forecast_type=FloodProcess)
  debug_inspect(result.grade, content="Excellent")
  assert_true(result.nse > 0.99)
  assert_true(result.peak_error.abs() < 0.001)
  debug_inspect(result.peak_time_error, content="0")
}
