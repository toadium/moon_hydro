///|
/// 2D浅水方程求解器测试

///|
test "SWEGrid2D::uniform 均匀网格构造" {
  let grid = SWEGrid2D::uniform(nx=10, ny=10, dx=1.0, dy=1.0, h0=1.0)
  assert_eq(grid.nx, 10)
  assert_eq(grid.ny, 10)
  assert_eq(grid.h.length(), 100)
  assert_true((grid.h[0] - 1.0).abs() < 0.001)
  assert_true((grid.hu[50] - 0.0).abs() < 0.001)
}

///|
test "SWE2D 静水稳定性" {
  // 均匀水深、零流速 → 应保持稳定
  let grid = SWEGrid2D::uniform(nx=10, ny=10, dx=1.0, dy=1.0, h0=2.0)
  let config : SWE2DSolverConfig = {
    dt: 0.01,
    n_steps: 20,
    cfl: 0.4,
    boundary: SWE2DBoundary::SolidWall,
  }
  let result = grid.run(config)
  assert_true(result.stable)
  // 水深应基本不变
  for k in 0..<100 {
    assert_true((result.h_final[k] - 2.0).abs() < 0.1)
  }
}

///|
test "SWE2D dam-break初始条件" {
  let grid = SWEGrid2D::uniform(nx=20, ny=20, dx=1.0, dy=1.0, h0=0.1)
  // 左半部分水深=2.0（dam-break）
  ignore(grid.set_block(i0=0, i1=10, j0=0, j1=20, h_value=2.0))
  assert_true((grid.h[0] - 2.0).abs() < 0.001)
  assert_true((grid.h[10 * 20 + 0] - 0.1).abs() < 0.001)
}

///|
test "SWE2D dam-break仿真" {
  let grid = SWEGrid2D::uniform(nx=20, ny=20, dx=1.0, dy=1.0, h0=0.1)
  ignore(grid.set_block(i0=0, i1=10, j0=0, j1=20, h_value=2.0))
  let config : SWE2DSolverConfig = {
    dt: 0.005,
    n_steps: 20,
    cfl: 0.3,
    boundary: SWE2DBoundary::SolidWall,
  }
  let result = grid.run(config)
  assert_true(result.stable)
  // 水应从高水位区流向低水位区
  // 左侧平均水深应降低，右侧应升高
  let mut left_avg = 0.0
  let mut right_avg = 0.0
  for j in 0..<20 {
    for i in 0..<10 {
      left_avg = left_avg + result.h_final[i * 20 + j]
    }
    for i in 10..<20 {
      right_avg = right_avg + result.h_final[i * 20 + j]
    }
  }
  left_avg = left_avg / 200.0
  right_avg = right_avg / 200.0
  assert_true(left_avg < 2.0)
  assert_true(right_avg > 0.1)
}

///|
test "SWE2D set_elevation 设置高程" {
  let grid = SWEGrid2D::uniform(nx=10, ny=10, dx=1.0, dy=1.0, h0=1.0)
  ignore(grid.set_elevation(i0=5, i1=10, j0=0, j1=10, z_value=0.5))
  assert_true((grid.z[5 * 10 + 0] - 0.5).abs() < 0.001)
  assert_true((grid.z[0] - 0.0).abs() < 0.001)
}

///|
test "SWE2D 质量守恒（固壁边界）" {
  let grid = SWEGrid2D::uniform(nx=10, ny=10, dx=1.0, dy=1.0, h0=1.0)
  ignore(grid.set_block(i0=0, i1=5, j0=0, j1=10, h_value=1.5))
  // 初始总质量
  let mut initial_mass = 0.0
  for k in 0..<100 {
    initial_mass = initial_mass + grid.h[k]
  }
  let config : SWE2DSolverConfig = {
    dt: 0.005,
    n_steps: 10,
    cfl: 0.3,
    boundary: SWE2DBoundary::SolidWall,
  }
  let result = grid.run(config)
  // 最终总质量
  let mut final_mass = 0.0
  for k in 0..<100 {
    final_mass = final_mass + result.h_final[k]
  }
  // 质量应近似守恒（允许数值误差）
  let rel_error = (final_mass - initial_mass).abs() / initial_mass
  assert_true(rel_error < 0.05)
}

///|
test "SWE2D Transmissive边界" {
  let grid = SWEGrid2D::uniform(nx=10, ny=10, dx=1.0, dy=1.0, h0=1.0)
  let config : SWE2DSolverConfig = {
    dt: 0.01,
    n_steps: 10,
    cfl: 0.4,
    boundary: SWE2DBoundary::Transmissive,
  }
  let result = grid.run(config)
  assert_true(result.stable)
  assert_eq(result.n_steps_actual, 10)
}
