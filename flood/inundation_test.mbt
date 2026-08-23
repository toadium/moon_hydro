///|
/// 洪水淹没推演模块测试
test "InundationConfig::default" {
  let config = InundationConfig::default()
  assert_true(config.dt > 0.0)
  assert_true(config.n_steps > 0)
  assert_true(config.cfl > 0.0 && config.cfl < 1.0)
  assert_true(config.depth_threshold > 0.0)
}

///|
test "dem_to_swe_grid - 基本转换" {
  let dem = @gis.DEMGrid::uniform(nx=5, ny=4, dx=10.0, dy=10.0, h0=100.0)
  let grid = dem_to_swe_grid(dem, h0=0.0, manning=0.03)
  assert_eq(grid.nx, 5)
  assert_eq(grid.ny, 4)
  assert_eq(grid.dx, 10.0)
  assert_eq(grid.dy, 10.0)
  assert_eq(grid.h.length(), 20)
  assert_eq(grid.z.length(), 20)
  // 所有高程应为100.0
  for k in 0..<20 {
    assert_eq(grid.z[k], 100.0)
    assert_eq(grid.h[k], 0.0)
  }
}

///|
test "dem_to_swe_grid - 非方阵索引顺序验证" {
  // 构造 nx=3, ny=2 的非方阵DEM，每个位置高程唯一
  let dem = @gis.DEMGrid::uniform(nx=3, ny=2, dx=10.0, dy=10.0, h0=0.0)
  // elevations[row][col], row=0..1 (ny), col=0..2 (nx)
  dem.set_elevation(0, 0, 10.0) // (x=0, y=0)
  dem.set_elevation(0, 1, 20.0) // (x=1, y=0)
  dem.set_elevation(0, 2, 30.0) // (x=2, y=0)
  dem.set_elevation(1, 0, 40.0) // (x=0, y=1)
  dem.set_elevation(1, 1, 50.0) // (x=1, y=1)
  dem.set_elevation(1, 2, 60.0) // (x=2, y=1)
  let grid = dem_to_swe_grid(dem, h0=0.0, manning=0.03)
  // SWEGrid2D idx = x_idx * ny + y_idx
  // z[0*2+0]=z[0] should be 10.0 (x=0,y=0)
  assert_eq(grid.z[0], 10.0)
  // z[0*2+1]=z[1] should be 40.0 (x=0,y=1)
  assert_eq(grid.z[1], 40.0)
  // z[1*2+0]=z[2] should be 20.0 (x=1,y=0)
  assert_eq(grid.z[2], 20.0)
  // z[1*2+1]=z[3] should be 50.0 (x=1,y=1)
  assert_eq(grid.z[3], 50.0)
  // z[2*2+0]=z[4] should be 30.0 (x=2,y=0)
  assert_eq(grid.z[4], 30.0)
  // z[2*2+1]=z[5] should be 60.0 (x=2,y=1)
  assert_eq(grid.z[5], 60.0)
}

///|
test "set_inflow - 设置入流" {
  let dem = @gis.DEMGrid::uniform(nx=10, ny=10, dx=10.0, dy=10.0, h0=50.0)
  let grid = dem_to_swe_grid(dem, h0=0.0)
  let grid2 = set_inflow(
    grid,
    i0=0,
    i1=2,
    j0=0,
    j1=5,
    h_value=3.0,
    u_velocity=2.0,
  )
  // 检查入流区域
  let k = 0 * 10 + 0
  assert_eq(grid2.h[k], 3.0)
  assert_eq(grid2.hu[k], 6.0) // h*u = 3*2
  // 检查非入流区域
  let k2 = 5 * 10 + 5
  assert_eq(grid2.h[k2], 0.0)
}

///|
test "simulate_inundation - 基本仿真" {
  let dem = @gis.synthetic_dem(nx=15, ny=10, dx=20.0, dy=20.0)
  let grid = dem_to_swe_grid(dem, h0=0.0, manning=0.035)
  let grid2 = set_inflow(
    grid,
    i0=0,
    i1=2,
    j0=0,
    j1=5,
    h_value=1.5,
    u_velocity=1.0,
  )
  let config : InundationConfig = {
    dt: 0.05,
    n_steps: 50,
    cfl: 0.4,
    depth_threshold: 0.05,
  }
  let result = simulate_inundation(grid2, config)
  assert_eq(result.nx, 15)
  assert_eq(result.ny, 10)
  assert_eq(result.max_depth.length(), 150)
  // 入流区域应有水深
  assert_true(result.max_depth[0] > 0.0)
  // 仿真应稳定
  assert_true(result.stable)
}

///|
test "simulate_inundation - 到达时间" {
  let dem = @gis.synthetic_dem(nx=20, ny=15, dx=30.0, dy=30.0)
  let grid = dem_to_swe_grid(dem, h0=0.0)
  let grid2 = set_inflow(
    grid,
    i0=0,
    i1=2,
    j0=5,
    j1=10,
    h_value=2.0,
    u_velocity=1.5,
  )
  let config : InundationConfig = {
    dt: 0.02,
    n_steps: 100,
    cfl: 0.3,
    depth_threshold: 0.05,
  }
  let result = simulate_inundation(grid2, config)
  // 入流区域的到达时间应为0
  let k_inflow = 0 * 15 + 5
  assert_true(result.arrival_time[k_inflow] >= 0.0)
  // 淹没单元数应>0
  assert_true(result.total_inundated_cells > 0)
}

///|
test "extract_inundation_extent - 提取淹没范围" {
  let dem = @gis.synthetic_dem(nx=10, ny=8, dx=10.0, dy=10.0)
  let grid = dem_to_swe_grid(dem, h0=0.0)
  let grid2 = set_inflow(grid, i0=0, i1=3, j0=0, j1=4, h_value=1.0)
  let config : InundationConfig = {
    dt: 0.05,
    n_steps: 30,
    cfl: 0.4,
    depth_threshold: 0.05,
  }
  let result = simulate_inundation(grid2, config)
  let extent = extract_inundation_extent(result, threshold=0.05)
  assert_true(extent.length() > 0)
  assert_true(extent.length() <= 80)
}

///|
test "inundation_stats - 淹没统计" {
  let dem = @gis.synthetic_dem(nx=12, ny=10, dx=50.0, dy=50.0)
  let grid = dem_to_swe_grid(dem, h0=0.0)
  let grid2 = set_inflow(grid, i0=0, i1=3, j0=0, j1=5, h_value=2.0)
  let config : InundationConfig = {
    dt: 0.03,
    n_steps: 80,
    cfl: 0.4,
    depth_threshold: 0.05,
  }
  let result = simulate_inundation(grid2, config)
  let (count, area, max_h, mean_h) = inundation_stats(result)
  assert_true(count > 0)
  assert_true(area > 0.0)
  assert_true(max_h > 0.0)
  assert_true(mean_h > 0.0)
  assert_true(mean_h <= max_h)
}

///|
test "synthetic_flood_scenario - 合成场景" {
  let (grid, config) = synthetic_flood_scenario(nx=30, ny=20)
  assert_eq(grid.nx, 30)
  assert_eq(grid.ny, 20)
  assert_true(config.n_steps > 0)
  // 运行仿真
  let result = simulate_inundation(grid, config)
  assert_true(result.stable)
  assert_true(result.total_inundated_cells > 0)
}
