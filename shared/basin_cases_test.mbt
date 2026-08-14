///|
/// 流域校验案例测试
///
/// 测试流域参数配置、校验流程、率定验证

///|
test "zhuyi_basin_params 闽江竹岐参数" {
  let p = zhuyi_basin_params()
  assert_true((p.wm - 120.0).abs() < 0.001)
  assert_true((p.b - 0.4).abs() < 0.001)
  // 三层蓄水容量满足约束
  assert_true((p.wm - (p.wum + p.wlm + p.wdm)).abs() < 0.001)
}

///|
test "feiyunjiang_basin_params 飞云江参数" {
  let p = feiyunjiang_basin_params()
  assert_true((p.wm - 100.0).abs() < 0.001)
  assert_true((p.b - 0.35).abs() < 0.001)
  assert_true((p.wm - (p.wum + p.wlm + p.wdm)).abs() < 0.001)
}

///|
test "qingyijiang_basin_params 青弋江参数" {
  let p = qingyijiang_basin_params()
  assert_true((p.wm - 110.0).abs() < 0.001)
  assert_true((p.b - 0.3).abs() < 0.001)
  assert_true((p.wm - (p.wum + p.wlm + p.wdm)).abs() < 0.001)
}

///|
test "synthetic_benchmark_case 合成基准案例" {
  let case = synthetic_benchmark_case()
  assert_eq(case.name, "合成基准")
  assert_true((case.area - 100.0).abs() < 0.001)
  assert_true((case.dt - 1.0).abs() < 0.001)
  assert_true(case.forcings.length() > 0)
  assert_true(case.observed.length() > 0)
  assert_eq(case.forcings.length(), case.observed.length())
}

///|
test "zhuyi_basin_case 闽江竹岐案例" {
  let case = zhuyi_basin_case()
  assert_eq(case.name, "闽江竹岐")
  assert_true((case.area - 54500.0).abs() < 0.001)
  assert_true((case.dt - 6.0).abs() < 0.001)
  assert_true(case.forcings.length() == 24)
  assert_true(case.observed.length() == 24)
}

///|
test "feiyunjiang_basin_case 飞云江案例" {
  let case = feiyunjiang_basin_case()
  assert_eq(case.name, "飞云江")
  assert_true((case.area - 1930.0).abs() < 0.001)
  assert_true(case.forcings.length() > 0)
}

///|
test "qingyijiang_basin_case 青弋江案例" {
  let case = qingyijiang_basin_case()
  assert_eq(case.name, "青弋江")
  assert_true((case.area - 715.0).abs() < 0.001)
  assert_true(case.forcings.length() > 0)
}

///|
test "all_basin_cases 全部案例" {
  let cases = all_basin_cases()
  assert_eq(cases.length(), 4)
  // 每个案例应有非空数据
  for case in cases {
    assert_true(case.forcings.length() > 0)
    assert_true(case.observed.length() > 0)
    assert_true(case.area > 0.0)
    assert_true(case.dt > 0.0)
  }
}

///|
test "validate_basin_case 合成基准校验" {
  let case = synthetic_benchmark_case()
  let result = validate_basin_case(case)
  // 自校准NSE应接近1
  assert_true((result.nse - 1.0).abs() < 0.001)
  assert_true((result.kge - 1.0).abs() < 0.001)
  assert_true(result.pbias.abs() < 0.1)
  assert_true(result.passed)
}

///|
test "validate_basin_case 闽江竹岐校验" {
  let case = zhuyi_basin_case()
  let result = validate_basin_case(case)
  // 自校准应通过
  assert_true(result.passed)
  assert_true(result.nse > 0.7)
}

///|
test "validate_all_basins 全部流域校验" {
  let results = validate_all_basins()
  assert_eq(results.length(), 4)
  // 全部应通过（自校准）
  for r in results {
    assert_true(r.passed)
  }
}

///|
test "generate_validation_report 校验报告" {
  let report = generate_validation_report()
  assert_eq(report.total_cases, 4)
  assert_eq(report.passed_count, 4)
  assert_eq(report.failed_count, 0)
  // 平均NSE应较高
  assert_true(report.mean_nse > 0.9)
  // min_nse <= mean_nse <= max_nse
  assert_true(report.min_nse <= report.mean_nse + 0.001)
  assert_true(report.mean_nse <= report.max_nse + 0.001)
}

///|
test "calibrate_basin_case DDS率定验证" {
  let case = synthetic_benchmark_case()
  let result = calibrate_basin_case(case)
  // 应找到11个参数
  assert_eq(result.best_params.length(), 11)
  // NSE应为正
  assert_true(result.best_metric > 0.0)
}

///|
test "BasinCase 序列化" {
  let case = synthetic_benchmark_case()
  let json = to_json_string(case)
  assert_true(json.length() > 0)
  // 应包含关键字段
  assert_true(json.contains("合成基准"))
}
