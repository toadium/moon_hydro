///|
/// DEM 处理测试

///|
test "DEMGrid::uniform" {
  let dem = DEMGrid::uniform(nx=5, ny=4, dx=100.0, dy=100.0, h0=50.0)
  assert_eq(dem.nx, 5)
  assert_eq(dem.ny, 4)
  assert_eq(dem.get_elevation(0, 0), 50.0)
  assert_eq(dem.get_elevation(3, 4), 50.0)
}

///|
test "DEMGrid::set_elevation" {
  let dem = DEMGrid::uniform(nx=5, ny=5, dx=100.0, dy=100.0, h0=0.0)
  dem.set_elevation(2, 3, 100.0)
  assert_eq(dem.get_elevation(2, 3), 100.0)
  assert_eq(dem.get_elevation(0, 0), 0.0)
}

///|
test "DEMGrid::has_data" {
  let dem = DEMGrid::uniform(nx=3, ny=3, dx=100.0, dy=100.0, h0=50.0)
  assert_true(dem.has_data(0, 0))
  assert_false(dem.has_data(-1, 0))
  assert_false(dem.has_data(3, 0))
}

///|
test "compute_flow_direction - 均匀坡度" {
  // 从西北向东南倾斜的地形
  let dem = DEMGrid::uniform(nx=5, ny=5, dx=100.0, dy=100.0, h0=0.0)
  for i in 0..<5 {
    for j in 0..<5 {
      dem.set_elevation(
        i,
        j,
        100.0 - i.to_double() * 10.0 - j.to_double() * 10.0,
      )
    }
  }
  let fd = compute_flow_direction(dem)
  assert_eq(fd.nx, 5)
  assert_eq(fd.ny, 5)
  // 中心单元应流向东南（方向8）
  assert_eq(fd.dirs[2][2], 8)
}

///|
test "compute_flow_accumulation" {
  let dem = DEMGrid::uniform(nx=5, ny=5, dx=100.0, dy=100.0, h0=0.0)
  for i in 0..<5 {
    for j in 0..<5 {
      dem.set_elevation(
        i,
        j,
        100.0 - i.to_double() * 10.0 - j.to_double() * 10.0,
      )
    }
  }
  let fd = compute_flow_direction(dem)
  let fa = compute_flow_accumulation(fd)
  assert_eq(fa.nx, 5)
  assert_eq(fa.ny, 5)
  // 左上角单元汇流累积应为1（只有自身）
  assert_eq(fa.accum[0][0], 1)
  // 右下角单元应有最大汇流累积
  assert_true(fa.accum[4][4] > fa.accum[0][0])
}

///|
test "delineate_watershed" {
  let dem = DEMGrid::uniform(nx=5, ny=5, dx=100.0, dy=100.0, h0=0.0)
  for i in 0..<5 {
    for j in 0..<5 {
      dem.set_elevation(
        i,
        j,
        100.0 - i.to_double() * 10.0 - j.to_double() * 10.0,
      )
    }
  }
  let fd = compute_flow_direction(dem)
  // 出口在右下角
  let watershed = delineate_watershed(fd, outlet_i=4, outlet_j=4)
  // 流域应包含多个单元
  assert_true(watershed.length() > 1)
}

///|
test "watershed_area" {
  let dem = DEMGrid::uniform(nx=5, ny=5, dx=100.0, dy=100.0, h0=0.0)
  let cells : Array[(Int, Int)] = [(0, 0), (0, 1), (1, 0), (1, 1)]
  let area = watershed_area(dem, cells)
  // 4个单元 × 100m × 100m = 40000 m² = 0.04 km²
  assert_true(area - 0.04 < 0.001)
}

///|
test "extract_river_network" {
  let dem = DEMGrid::uniform(nx=5, ny=5, dx=100.0, dy=100.0, h0=0.0)
  for i in 0..<5 {
    for j in 0..<5 {
      dem.set_elevation(
        i,
        j,
        100.0 - i.to_double() * 10.0 - j.to_double() * 10.0,
      )
    }
  }
  let fd = compute_flow_direction(dem)
  let fa = compute_flow_accumulation(fd)
  let rivers = extract_river_network(fa, threshold=3)
  assert_true(rivers.length() > 0)
}

///|
test "dem_stats" {
  let dem = DEMGrid::uniform(nx=3, ny=3, dx=100.0, dy=100.0, h0=50.0)
  dem.set_elevation(0, 0, 100.0)
  dem.set_elevation(2, 2, 0.0)
  let (min_val, max_val, mean, count) = dem_stats(dem)
  assert_eq(min_val, 0.0)
  assert_eq(max_val, 100.0)
  assert_eq(count, 9.0)
  assert_true(mean > 0.0)
}

///|
test "synthetic_dem" {
  let dem = synthetic_dem(nx=10, ny=10, dx=100.0, dy=100.0)
  assert_eq(dem.nx, 10)
  assert_eq(dem.ny, 10)
  let (min_val, max_val, _, _) = dem_stats(dem)
  assert_true(min_val < max_val)
}
