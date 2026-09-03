///|
/// 浅水方程SWE求解器测试
///
/// 测试Lax-Friedrichs格式：静止水面、dam-break、边界条件、CFL步长

///|
test "SWEGrid1D::uniform 构造均匀网格" {
  let grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=2.0)
  inspect(grid.nx, content="10")
  inspect(grid.dx, content="1")
  inspect(grid.h.length(), content="10")
  inspect(grid.h[0], content="2")
  inspect(grid.h[5], content="2")
  inspect(grid.hu[0], content="0")
}

///|
test "SWEGrid1D::uniform 自定义糙率和高程" {
  let grid = SWEGrid1D::uniform(nx=5, dx=2.0, h0=1.5, z0=10.0, n0=0.025)
  inspect(grid.z[0], content="10")
  inspect(grid.n_manning[0], content="0.025")
  inspect(grid.dx, content="2")
}

///|
test "SWEGrid1D::step_lf 静止水面保持不变" {
  // 均匀水深、零流速、平底 → 应保持静止
  let grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=2.0)
  let boundary : SWEBoundary = { left: Transmissive, right: Transmissive, }
  let dt = 0.01
  let new_grid = grid.step_lf(dt, boundary)
  // 内部单元水深应保持2.0
  for i in 1..<9 {
    assert_true((new_grid.h[i] - 2.0).abs() < 0.001)
  }
  // 内部单元流速应保持0
  for i in 1..<9 {
    assert_true(new_grid.hu[i].abs() < 0.001)
  }
}

///|
test "SWEGrid1D::run 静止水面多步仿真" {
  let grid = SWEGrid1D::uniform(nx=20, dx=1.0, h0=3.0)
  let config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 10,
    cfl: 0.5,
    boundary: { left: Transmissive, right: Transmissive, },
  }
  let result = grid.run(config)
  inspect(result.h_series.length(), content="10")
  // 静止水面应保持稳定
  assert_true(result.stable)
  // 所有时刻水深应接近3.0
  for t in 0..<10 {
    for i in 1..<19 {
      assert_true((result.h_series[t][i] - 3.0).abs() < 0.01)
    }
  }
}

///|
test "SWEGrid1D::run dam-break初始条件" {
  // 经典dam-break：左高右低
  let nx = 50
  let grid = SWEGrid1D::uniform(nx~, dx=1.0, h0=0.0)
  // 设置初始条件：左半部分水深4.0，右半部分水深1.0
  for i in 0..<nx {
    if i < nx / 2 {
      grid.h[i] = 4.0
    } else {
      grid.h[i] = 1.0
    }
  }
  let config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 100,
    cfl: 0.4,
    boundary: { left: SolidWall, right: Transmissive, },
  }
  let result = grid.run(config)
  inspect(result.h_series.length(), content="100")
  // dam-break应保持稳定（无负水深）
  assert_true(result.stable)
  // 水应从左向右流动：左侧水深应减小，波前右侧水深应增大
  let h_final = result.h_series[99]
  assert_true(h_final[10] < 4.0) // 左侧水位下降
  // 波前传播约√(g*h)*t ≈ 6.26*1.0 ≈ 6个单元，检查位置28附近
  assert_true(h_final[28] > 1.0) // 波前右侧水位上升
}

///|
test "SWEGrid1D::max_stable_dt CFL时间步长" {
  let grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=2.0)
  // 静止水面：波速c=√(gh)=√(9.81*2)≈4.43
  // dt_max = CFL * dx / c = 0.5 * 1.0 / 4.43 ≈ 0.113
  let dt_max = grid.max_stable_dt(cfl=0.5)
  assert_true(dt_max > 0.0)
  assert_true(dt_max < 0.2)
  assert_true(dt_max > 0.05)
}

///|
test "SWEGrid1D::max_stable_dt 零水深" {
  let grid = SWEGrid1D::uniform(nx=5, dx=1.0, h0=0.0)
  // 零水深时波速为0，应返回默认值1.0
  let dt_max = grid.max_stable_dt(cfl=0.5)
  inspect(dt_max, content="1")
}

///|
test "SWEBoundary 固壁边界反射" {
  // 固壁边界应反射流速
  let grid = SWEGrid1D::uniform(nx=5, dx=1.0, h0=2.0)
  // 给左侧单元设置正流速
  grid.hu[1] = 1.0
  let boundary : SWEBoundary = { left: SolidWall, right: SolidWall, }
  let result = grid.step_lf(0.01, boundary)
  // 固壁边界后，边界单元流速应反射
  // hu[0] = -hu[1] = -1.0
  assert_true((result.hu[0] - -1.0).abs() < 0.001)
}

///|
test "SWEBoundary 透射边界" {
  let grid = SWEGrid1D::uniform(nx=5, dx=1.0, h0=2.0)
  grid.h[1] = 3.0
  grid.hu[1] = 0.5
  let boundary : SWEBoundary = { left: Transmissive, right: Transmissive, }
  let result = grid.step_lf(0.01, boundary)
  // 透射边界：h[0] = h[1], hu[0] = hu[1]
  assert_true((result.h[0] - 3.0).abs() < 0.001)
  assert_true((result.hu[0] - 0.5).abs() < 0.001)
}

///|
test "SWEBoundary Dirichlet边界" {
  let grid = SWEGrid1D::uniform(nx=5, dx=1.0, h0=2.0)
  let boundary : SWEBoundary = { left: Dirichlet(5.0), right: Dirichlet(1.0), }
  let result = grid.step_lf(0.01, boundary)
  // Dirichlet边界：固定水深值
  assert_true((result.h[0] - 5.0).abs() < 0.001)
  assert_true((result.h[4] - 1.0).abs() < 0.001)
  assert_true(result.hu[0].abs() < 0.001)
  assert_true(result.hu[4].abs() < 0.001)
}

///|
test "SWEGrid1D::run 带底坡的流动" {
  // 倾斜河底，水体应在重力作用下流动
  let nx = 20
  let grid = SWEGrid1D::uniform(nx~, dx=1.0, h0=1.0)
  // 设置底坡：从左到右递减
  for i in 0..<nx {
    grid.z[i] = (nx - i).to_double() * 0.1
  }
  let config : SWESolverConfig = {
    dt: 0.005,
    n_steps: 50,
    cfl: 0.3,
    boundary: { left: Dirichlet(1.0), right: Transmissive, },
  }
  let result = grid.run(config)
  assert_true(result.stable)
  // 在底坡作用下，应产生向下游的流动
  // 至少某些单元应有正流速（向右流）
  let mut has_flow = false
  for i in 1..<(nx - 1) {
    if result.hu_series[49][i] > 0.001 {
      has_flow = true
    }
  }
  assert_true(has_flow)
}
