///|
/// 扩展评价指标测试
///
/// 测试LogNSE、KGE分解、MAE、MSE、RSR、一致性指数等

///|
test "log_nse 对数NSE" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [1.0, 2.0, 3.0, 4.0, 5.0]
  // 完美匹配LogNSE=1
  assert_true((log_nse(observed, simulated) - 1.0).abs() < 0.001)
  // 偏离匹配
  let sim2 = [1.1, 2.1, 3.1, 4.1, 5.1]
  let lnse = log_nse(observed, sim2)
  assert_true(lnse < 1.0)
  assert_true(lnse > 0.0)
}

///|
test "log_nse 含非正值返回0" {
  let observed = [0.0, 2.0, 3.0]
  let simulated = [1.0, 2.0, 3.0]
  assert_true((log_nse(observed, simulated) - 0.0).abs() < 0.001)
  let observed2 = [1.0, 2.0, 3.0]
  let simulated2 = [1.0, 0.0, 3.0]
  assert_true((log_nse(observed2, simulated2) - 0.0).abs() < 0.001)
}

///|
test "kge_decomposition KGE分解" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [1.0, 2.0, 3.0, 4.0, 5.0]
  let (r, alpha, beta) = kge_decomposition(observed, simulated)
  // 完美匹配：r=1, alpha=1, beta=1
  assert_true((r - 1.0).abs() < 0.001)
  assert_true((alpha - 1.0).abs() < 0.001)
  assert_true((beta - 1.0).abs() < 0.001)
}

///|
test "kge_decomposition 偏离匹配" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [2.0, 4.0, 6.0, 8.0, 10.0] // 2倍放大
  let (r, alpha, beta) = kge_decomposition(observed, simulated)
  // r=1（完全相关）
  assert_true((r - 1.0).abs() < 0.001)
  // alpha=2（标准差比2）
  assert_true((alpha - 2.0).abs() < 0.001)
  // beta=2（均值比2）
  assert_true((beta - 2.0).abs() < 0.001)
}

///|
test "mae 平均绝对误差" {
  let observed = [1.0, 2.0, 3.0]
  let simulated = [1.0, 2.0, 3.0]
  assert_true((mae(observed, simulated) - 0.0).abs() < 0.001)
  let sim2 = [2.0, 3.0, 4.0]
  // MAE = (1+1+1)/3 = 1
  assert_true((mae(observed, sim2) - 1.0).abs() < 0.001)
}

///|
test "mse 均方误差" {
  let observed = [1.0, 2.0, 3.0]
  let simulated = [1.0, 2.0, 3.0]
  assert_true((mse(observed, simulated) - 0.0).abs() < 0.001)
  let sim2 = [2.0, 3.0, 4.0]
  // MSE = (1+1+1)/3 = 1
  assert_true((mse(observed, sim2) - 1.0).abs() < 0.001)
}

///|
test "rsr 标准化RMSE" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [1.0, 2.0, 3.0, 4.0, 5.0]
  // 完美匹配RSR=0
  assert_true((rsr(observed, simulated) - 0.0).abs() < 0.001)
  // 持续性预报（均值）RSR=1
  let mean_val = 3.0
  let sim_mean = [mean_val, mean_val, mean_val, mean_val, mean_val]
  assert_true((rsr(observed, sim_mean) - 1.0).abs() < 0.001)
}

///|
test "index_of_agreement 一致性指数" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [1.0, 2.0, 3.0, 4.0, 5.0]
  // 完美匹配d=1
  assert_true((index_of_agreement(observed, simulated) - 1.0).abs() < 0.001)
  let sim2 = [3.0, 3.0, 3.0, 3.0, 3.0] // 均值预报
  let d = index_of_agreement(observed, sim2)
  assert_true(d >= 0.0 && d <= 1.0)
}

///|
test "skill_score 技巧评分" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [1.0, 2.0, 3.0, 4.0, 5.0]
  let reference = [3.0, 3.0, 3.0, 3.0, 3.0]
  // 完美预报SS=1
  assert_true((skill_score(observed, simulated, reference) - 1.0).abs() < 0.001)
  // 等于参考SS=0
  let ss0 = skill_score(observed, reference, reference)
  assert_true(ss0.abs() < 0.001)
}

///|
test "persistence_index 持续性指数" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [1.0, 2.0, 3.0, 4.0, 5.0]
  // 完美匹配PI=1
  assert_true((persistence_index(observed, simulated) - 1.0).abs() < 0.001)
}

///|
test "percent_forecast_correct 预报正确率" {
  let observed = [10.0, 20.0, 30.0, 40.0, 50.0]
  let simulated = [10.5, 21.0, 30.0, 41.0, 50.0]
  // 误差都很小，正确率应高
  let pfc = percent_forecast_correct(observed, simulated, threshold=0.1)
  assert_true(pfc > 80.0)
  // 完美匹配100%
  let pfc_perfect = percent_forecast_correct(observed, observed)
  assert_true((pfc_perfect - 100.0).abs() < 0.001)
}

///|
test "evaluate_extended 综合扩展评价" {
  let observed = [1.0, 2.0, 3.0, 4.0, 5.0]
  let simulated = [1.1, 2.1, 2.9, 4.1, 4.9]
  let result = evaluate_extended(observed, simulated)
  // 各指标应在合理范围
  assert_true(result.log_nse > 0.0 && result.log_nse <= 1.0)
  assert_true(result.r > 0.0 && result.r <= 1.0)
  assert_true(result.mae > 0.0)
  assert_true(result.mse > 0.0)
  assert_true(result.rsr >= 0.0)
  assert_true(result.index_of_agreement > 0.0)
  assert_true(result.percent_forecast_correct >= 0.0)
}

///|
test "forecast_grade_rsr RSR等级判定" {
  assert_true(forecast_grade_rsr(0.3) is Excellent)
  assert_true(forecast_grade_rsr(0.5) is Excellent)
  assert_true(forecast_grade_rsr(0.55) is Good)
  assert_true(forecast_grade_rsr(0.6) is Good)
  assert_true(forecast_grade_rsr(0.65) is Qualified)
  assert_true(forecast_grade_rsr(0.8) is Unqualified)
}
