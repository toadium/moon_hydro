///|
/// 洪水损失评估模块测试
test "LandUseType::to_string" {
  assert_eq(LandUseType::Residential.to_string(), "住宅")
  assert_eq(LandUseType::Commercial.to_string(), "商业")
  assert_eq(LandUseType::Industrial.to_string(), "工业")
  assert_eq(LandUseType::Agricultural.to_string(), "农业")
  assert_eq(LandUseType::Forest.to_string(), "林地")
  assert_eq(LandUseType::Water.to_string(), "水体")
}

///|
test "LandUseMap::uniform - 均匀构造" {
  let map = LandUseMap::uniform(
    nx=5,
    ny=4,
    land_type=Residential,
    unit_value=200.0,
  )
  assert_eq(map.nx, 5)
  assert_eq(map.ny, 4)
  assert_eq(map.types.length(), 20)
  for k in 0..<20 {
    assert_true(map.types[k] is Residential)
    assert_eq(map.unit_value[k], 200.0)
  }
}

///|
test "LandUseMap::set_region - 区域设置" {
  let map = LandUseMap::uniform(nx=10, ny=10, land_type=Forest, unit_value=10.0)
  map.set_region(i0=2, i1=5, j0=3, j1=7, land_type=Commercial, unit_value=500.0)
  // 检查设置区域
  let k = 3 * 10 + 5
  assert_true(map.types[k] is Commercial)
  assert_eq(map.unit_value[k], 500.0)
  // 检查未设置区域
  let k2 = 0 * 10 + 0
  assert_true(map.types[k2] is Forest)
  assert_eq(map.unit_value[k2], 10.0)
}

///|
test "damage_ratio - 无水无损" {
  assert_eq(damage_ratio(0.0, Residential), 0.0)
  assert_eq(damage_ratio(0.0, Commercial), 0.0)
  assert_eq(damage_ratio(-0.5, Industrial), 0.0)
}

///|
test "damage_ratio - 住宅曲线" {
  // 水深0.25m: 0.25*0.2 = 0.05
  let r1 = damage_ratio(0.25, Residential)
  assert_true(r1 > 0.0)
  assert_true(r1 < 0.1)
  // 水深1.0m: 0.1 + 0.5*0.3 = 0.25
  let r2 = damage_ratio(1.0, Residential)
  assert_true(r2 > 0.2)
  // 水深4.0m: 0.7 (上限)
  let r3 = damage_ratio(4.0, Residential)
  assert_eq(r3, 0.7)
}

///|
test "damage_ratio - 商业曲线" {
  let r = damage_ratio(4.0, Commercial)
  assert_eq(r, 0.85)
  // 商业损失率应高于住宅
  let r_res = damage_ratio(1.0, Residential)
  let r_com = damage_ratio(1.0, Commercial)
  assert_true(r_com > r_res)
}

///|
test "damage_ratio - 农业曲线" {
  // 农业在2m以上达到100%
  let r = damage_ratio(3.0, Agricultural)
  assert_eq(r, 1.0)
  // 农业在浅水损失率较高
  let r_shallow = damage_ratio(0.25, Agricultural)
  assert_true(r_shallow > 0.0)
}

///|
test "damage_ratio - 林地曲线" {
  let r = damage_ratio(0.5, Forest)
  assert_true(r > 0.0)
  assert_true(r < 0.1) // 林地损失较小
  let r2 = damage_ratio(2.0, Forest)
  assert_eq(r2, 0.1) // 上限
}

///|
test "damage_ratio - 水体无损" {
  let r = damage_ratio(5.0, Water)
  assert_eq(r, 0.0)
}

///|
test "estimate_damage - 基本损失评估" {
  let max_depth = [0.0, 1.0, 2.0, 0.5]
  let map = LandUseMap::uniform(
    nx=2,
    ny=2,
    land_type=Residential,
    unit_value=100.0,
  )
  let result = estimate_damage(max_depth, map)
  // 第0单元无水 => 无损
  // 第1单元水深1.0m => ratio≈0.25, dmg≈25
  // 第2单元水深2.0m => ratio≈0.45, dmg≈45
  // 第3单元水深0.5m => ratio≈0.1, dmg≈10
  assert_true(result.total_damage > 0.0)
  assert_true(result.damaged_cells == 3)
  assert_true(result.residential_damage > 0.0)
}

///|
test "estimate_damage - 多类型损失" {
  let max_depth = [1.0, 1.0, 1.0, 1.0]
  let map = LandUseMap::uniform(
    nx=2,
    ny=2,
    land_type=Residential,
    unit_value=100.0,
  )
  map.set_region(i0=0, i1=1, j0=0, j1=1, land_type=Commercial, unit_value=200.0)
  map.set_region(
    i0=1,
    i1=2,
    j0=0,
    j1=1,
    land_type=Agricultural,
    unit_value=50.0,
  )
  let result = estimate_damage(max_depth, map)
  assert_true(result.total_damage > 0.0)
  assert_true(result.commercial_damage > 0.0)
  assert_true(result.agricultural_damage > 0.0)
  assert_true(result.residential_damage > 0.0)
}

///|
test "synthetic_land_use - 合成土地利用" {
  let map = synthetic_land_use(nx=30, ny=20)
  assert_eq(map.nx, 30)
  assert_eq(map.ny, 20)
  // 上游应为林地
  assert_true(map.types[0] is Forest)
  // 下游应为商业或工业
  let k_down = 25 * 20 + 5
  assert_true(map.types[k_down] is Commercial)
  let k_down2 = 25 * 20 + 15
  assert_true(map.types[k_down2] is Industrial)
}

///|
test "DamageResult::to_summary - 摘要" {
  let max_depth = [0.0, 1.0, 2.0]
  let map = LandUseMap::uniform(
    nx=3,
    ny=1,
    land_type=Residential,
    unit_value=100.0,
  )
  let result = estimate_damage(max_depth, map)
  let summary = result.to_summary()
  assert_true(summary.length() > 0)
  assert_true(summary.contains("总损失"))
}
