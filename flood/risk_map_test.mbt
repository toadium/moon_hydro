///|
/// 风险图模块测试
test "classify_risk - 安全(无水)" {
  let level = classify_risk(0.0, 0.0)
  assert_true(level is Safe)
}

///|
test "classify_risk - 极浅水" {
  let level = classify_risk(0.06, 0.0)
  assert_true(level is LowRisk)
}

///|
test "classify_risk - 浅水低流速" {
  let level = classify_risk(0.2, 0.1)
  // danger = 0.2 * (0.1+0.5) = 0.12 < 0.15 => LowRisk
  assert_true(level is LowRisk)
}

///|
test "classify_risk - 浅水中流速" {
  let level = classify_risk(0.2, 1.0)
  // danger = 0.2 * (1.0+0.5) = 0.3 => ModerateRisk
  assert_true(level is ModerateRisk)
}

///|
test "classify_risk - 中水深" {
  let level = classify_risk(0.5, 0.5)
  // depth in [0.3, 0.8], danger = 0.5*1.0 = 0.5 < 0.6 => ModerateRisk
  assert_true(level is ModerateRisk)
}

///|
test "classify_risk - 中水深高流速" {
  let level = classify_risk(0.5, 2.0)
  // danger = 0.5 * 2.5 = 1.25 > 0.6 => HighRisk
  assert_true(level is HighRisk)
}

///|
test "classify_risk - 深水" {
  let level = classify_risk(1.0, 0.5)
  // depth in [0.8, 1.5], danger = 1.0*1.0 = 1.0 < 1.2 => HighRisk
  assert_true(level is HighRisk)
}

///|
test "classify_risk - 极深水" {
  let level = classify_risk(2.0, 0.0)
  // depth > 1.5 => ExtremeRisk
  assert_true(level is ExtremeRisk)
}

///|
test "classify_risk - 深水高流速" {
  let level = classify_risk(1.0, 2.0)
  // depth in [0.8, 1.5], danger = 1.0*2.5 = 2.5 > 1.2 => ExtremeRisk
  assert_true(level is ExtremeRisk)
}

///|
test "generate_risk_map - 基本生成" {
  let max_depth = [0.0, 0.1, 0.5, 1.0, 2.0, 0.0]
  let hu = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  let hv = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  let risk_map = generate_risk_map(max_depth, hu, hv, nx=3, ny=2)
  assert_eq(risk_map.nx, 3)
  assert_eq(risk_map.ny, 2)
  assert_eq(risk_map.levels.length(), 6)
  // 第0个单元无水 => Safe
  assert_true(risk_map.levels[0] is Safe)
  // 第4个单元水深2.0 => ExtremeRisk
  assert_true(risk_map.levels[4] is ExtremeRisk)
}

///|
test "generate_risk_map_depth_only - 仅水深版" {
  let max_depth = [0.0, 0.3, 1.0, 2.0]
  let risk_map = generate_risk_map_depth_only(max_depth, nx=2, ny=2)
  assert_eq(risk_map.nx, 2)
  assert_eq(risk_map.ny, 2)
  assert_true(risk_map.levels[0] is Safe)
  assert_true(risk_map.levels[3] is ExtremeRisk)
}

///|
test "risk_statistics - 统计" {
  let max_depth = [0.0, 0.1, 0.5, 1.0, 2.0, 0.0]
  let risk_map = generate_risk_map_depth_only(max_depth, nx=3, ny=2)
  let stats = risk_statistics(risk_map)
  assert_eq(stats.total_cells, 6)
  assert_eq(stats.safe_count, 2)
  assert_true(stats.inundated_ratio > 0.0)
  assert_true(stats.safe_ratio + stats.inundated_ratio - 1.0 < 0.001)
}

///|
test "to_ascii_map - ASCII图" {
  let max_depth = [0.0, 0.1, 0.5, 1.0, 2.0, 0.0]
  let risk_map = generate_risk_map_depth_only(max_depth, nx=3, ny=2)
  let ascii = to_ascii_map(risk_map, max_width=80)
  assert_true(ascii.length() > 0)
  // 应包含图例
  assert_true(ascii.contains("图例"))
}

///|
test "RiskStatistics::to_summary - 摘要" {
  let max_depth = [0.0, 0.1, 0.5, 1.0]
  let risk_map = generate_risk_map_depth_only(max_depth, nx=2, ny=2)
  let stats = risk_statistics(risk_map)
  let summary = stats.to_summary()
  assert_true(summary.length() > 0)
  assert_true(summary.contains("总单元"))
}
