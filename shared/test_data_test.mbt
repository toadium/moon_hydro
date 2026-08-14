///|
/// 生产级测试数据全链路测试
///
/// 使用mock数据生成器驱动新安江+SWE+耦合全链路仿真验证

// ============ Mock数据生成器单元测试 ============

///|
test "BasinProfile 三种流域配置" {
  let small = BasinProfile::small_basin()
  let medium = BasinProfile::medium_basin()
  let large = BasinProfile::large_basin()
  debug_inspect(small.area, content="50")
  debug_inspect(medium.area, content="500")
  debug_inspect(large.area, content="2000")
  assert_true(small.area < medium.area)
  assert_true(medium.area < large.area)
}

///|
test "mock_flood_rainfall 暴雨事件生成" {
  let forcings = mock_flood_rainfall(duration=10, peak_rainfall=50.0)
  debug_inspect(forcings.length(), content="10")
  // 峰值应在中间时段
  let peak_idx = 5
  let mut max_rainfall = 0.0
  for f in forcings {
    if f.rainfall > max_rainfall {
      max_rainfall = f.rainfall
    }
  }
  assert_true(max_rainfall > 40.0) // 接近峰值50
  assert_true(forcings[peak_idx].rainfall > forcings[0].rainfall)
}

///|
test "mock_multi_peak_rainfall 多峰洪水生成" {
  let forcings = mock_multi_peak_rainfall(
    n_peaks=3,
    peak_interval=3,
    peak_duration=4,
  )
  // 3场暴雨 × (4时段暴雨 + 3时段间歇) = 21
  debug_inspect(forcings.length(), content="21")
  // 应有多个降雨峰值
  let mut peak_count = 0
  for i in 1..<(forcings.length() - 1) {
    if forcings[i].rainfall > forcings[i - 1].rainfall &&
      forcings[i].rainfall > forcings[i + 1].rainfall {
      peak_count = peak_count + 1
    }
  }
  assert_true(peak_count >= 3)
}

///|
test "mock_dry_period 干旱退水生成" {
  let forcings = mock_dry_period(duration=15, initial_rainfall=5.0, wet_days=3)
  debug_inspect(forcings.length(), content="15")
  // 前3天有雨
  assert_true(forcings[0].rainfall > 0.0)
  assert_true(forcings[2].rainfall > 0.0)
  // 后期无雨
  debug_inspect(forcings[3].rainfall, content="0")
  debug_inspect(forcings[14].rainfall, content="0")
}

///|
test "mock_long_term_forcings 长期随机气象" {
  let forcings = mock_long_term_forcings(n_days=30, seed=42)
  debug_inspect(forcings.length(), content="30")
  // 所有降雨量应非负
  for f in forcings {
    assert_true(f.rainfall >= 0.0)
    assert_true(f.evaporation > 0.0)
  }
  // 不同种子应产生不同序列
  let forcings2 = mock_long_term_forcings(n_days=30, seed=999)
  assert_true(
    forcings[0].rainfall != forcings2[0].rainfall ||
    forcings[5].rainfall != forcings2[5].rainfall,
  )
}

///|
test "mock_xaj_params 随机参数生成" {
  let params1 = mock_xaj_params(seed=42)
  let params2 = mock_xaj_params(seed=999)
  // 参数应在合理范围内
  assert_true(params1.wm >= 80.0 && params1.wm <= 160.0)
  assert_true(params1.b >= 0.2 && params1.b <= 0.6)
  assert_true(params1.kg >= 0.2 && params1.kg <= 0.5)
  // 不同种子应产生不同参数
  assert_true(params1.wm != params2.wm || params1.b != params2.b)
}

///|
test "mock_extreme_flood_params 极端工况参数" {
  let params = mock_extreme_flood_params()
  debug_inspect(params.wm, content="80")
  debug_inspect(params.cs, content="0.1")
  // 极端参数：小蓄水容量+快速汇流
  assert_true(params.wm <= 100.0)
  assert_true(params.cs <= 0.2)
}

///|
test "mock_dam_break_grid 溃坝初始网格" {
  let grid = mock_dam_break_grid(nx=50, dx=1.0, h_left=4.0, h_right=1.0)
  debug_inspect(grid.nx, content="50")
  // 左半部分水深4.0
  debug_inspect(grid.h[0], content="4")
  debug_inspect(grid.h[24], content="4")
  // 右半部分水深1.0
  debug_inspect(grid.h[25], content="1")
  debug_inspect(grid.h[49], content="1")
}

///|
test "mock_sloped_river_grid 带底坡河道" {
  let grid = mock_sloped_river_grid(nx=20, dx=1.0, h0=1.0, slope=0.01)
  // 底坡应线性递减
  assert_true(grid.z[0] > grid.z[19])
  assert_true(grid.z[0] > 0.0)
}

///|
test "mock_tidal_wave_grid 潮波初始网格" {
  let grid = mock_tidal_wave_grid(
    nx=50,
    dx=1.0,
    h_mean=2.0,
    amplitude=0.5,
    wavelength=10.0,
  )
  // 水深应在[1.5, 2.5]范围内
  for i in 0..<50 {
    assert_true(grid.h[i] >= 1.5)
    assert_true(grid.h[i] <= 2.5)
  }
}

// ============ 全链路Mock场景测试 ============

///|
test "mock_scenario FloodEvent 暴雨洪水全链路" {
  let (xaj_model, forcings, swe_grid, coupling_params, boundary) = mock_scenario(
    scenario=FloodEvent,
    basin=BasinProfile::medium_basin(),
  )
  // 新安江仿真
  let xaj_result = xaj_model.run(forcings)
  assert_true(xaj_result.runoff_series.length() == forcings.length())
  // 所有径流应非负
  for q in xaj_result.runoff_series {
    assert_true(q >= 0.0)
  }
  // SWE仿真
  let swe_config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 20,
    cfl: 0.4,
    boundary,
  }
  let swe_result = swe_grid.run(swe_config)
  assert_true(swe_result.stable)
  // 耦合仿真
  let coupling_result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
  )
  assert_true(coupling_result.stable)
  assert_true(coupling_result.xaj_states.length() == forcings.length())
}

///|
test "mock_scenario DamBreak 溃坝耦合全链路" {
  let (xaj_model, forcings, swe_grid, coupling_params, boundary) = mock_scenario(
    scenario=DamBreak,
    basin=BasinProfile::small_basin(),
  )
  let coupling_result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
  )
  assert_true(coupling_result.stable)
  // 溃坝应有显著侧向入流
  let mut has_inflow = false
  for inflow in coupling_result.lateral_inflow_series {
    if inflow > 0.1 {
      has_inflow = true
    }
  }
  assert_true(has_inflow)
}

///|
test "mock_scenario MultiPeakFlood 多峰洪水耦合" {
  let (xaj_model, forcings, swe_grid, coupling_params, boundary) = mock_scenario(
    scenario=MultiPeakFlood,
    basin=BasinProfile::medium_basin(),
  )
  let coupling_result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
  )
  assert_true(coupling_result.stable)
  // 多峰洪水应有多个侧向入流峰值
  let mut inflow_peaks = 0
  let inflows = coupling_result.lateral_inflow_series
  for i in 1..<(inflows.length() - 1) {
    if inflows[i] > inflows[i - 1] &&
      inflows[i] > inflows[i + 1] &&
      inflows[i] > 1.0 {
      inflow_peaks = inflow_peaks + 1
    }
  }
  assert_true(inflow_peaks >= 1)
}

///|
test "mock_scenario LongTermSimulation 长期仿真稳定性" {
  let (xaj_model, forcings, swe_grid, coupling_params, boundary) = mock_scenario(
    scenario=LongTermSimulation,
    basin=BasinProfile::large_basin(),
  )
  let coupling_result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
  )
  // 长期仿真应保持稳定
  assert_true(coupling_result.stable)
  // 所有新安江状态蓄量应非负
  for state in coupling_result.xaj_states {
    assert_true(state.w >= 0.0)
    assert_true(state.s >= 0.0)
  }
}

///|
test "mock_scenario DryPeriod 干旱退水耦合" {
  let (xaj_model, forcings, swe_grid, coupling_params, boundary) = mock_scenario(
    scenario=DryPeriod,
    basin=BasinProfile::small_basin(),
  )
  let coupling_result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
  )
  assert_true(coupling_result.stable)
  // 干旱期侧向入流应逐渐减小
  let inflows = coupling_result.lateral_inflow_series
  if inflows.length() >= 10 {
    // 后期入流应小于前期
    let early_sum = inflows[0] + inflows[1] + inflows[2]
    let late_sum = inflows[inflows.length() - 1] +
      inflows[inflows.length() - 2] +
      inflows[inflows.length() - 3]
    assert_true(late_sum <= early_sum + 1.0)
  }
}

///|
test "全场景批量验证 所有场景稳定性" {
  let scenarios : Array[TestScenario] = [
    FloodEvent,
    DryPeriod,
    DamBreak,
    TidalWave,
    MultiPeakFlood,
    LongTermSimulation,
  ]
  for scenario in scenarios {
    let (xaj_model, forcings, swe_grid, coupling_params, boundary) = mock_scenario(
      scenario~,
      basin=BasinProfile::small_basin(),
    )
    let coupling_result = couple_run(
      xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
    )
    assert_true(coupling_result.stable)
  }
}
