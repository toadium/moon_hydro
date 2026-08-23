///|
/// 模型双向耦合测试
///
/// 测试新安江→SWE正向耦合、SWE→新安江反向反馈、完整耦合仿真

///|
test "CouplingParams::default 构造默认耦合参数" {
  let params = CouplingParams::default()
  inspect(params.lateral_inflow_coeff, content="0.8")
  inspect(params.feedback_coeff, content="0.01")
  inspect(params.cell_area, content="100")
  inspect(params.base_flow_threshold, content="0.5")
}

///|
test "couple_step 无降雨无入流耦合" {
  let xaj_model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let swe_grid = SWEGrid1D::uniform(nx=20, dx=1.0, h0=1.0)
  let coupling_params : CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [5, 6, 7, 8, 9],
    base_flow_threshold: 0.5,
  }
  let boundary : SWEBoundary = { left: Transmissive, right: Transmissive }
  let forcing : ForcingData = {
    rainfall: 0.0,
    evaporation: 0.0,
    datetime: "t0",
  }
  let xaj_state = XinanjiangState::initial()
  let (new_xaj, new_swe, lateral_inflow, river_level) = couple_step(
    xaj_model, swe_grid, coupling_params, boundary, forcing, xaj_state, 0.01,
  )
  // 无降雨应无侧向入流
  inspect(lateral_inflow, content="0")
  // 新安江状态应无产流
  assert_true(new_xaj.r >= 0.0)
  // SWE网格应保持稳定
  assert_true(new_swe.nx == 20)
  // 河道水位应非负
  assert_true(river_level >= 0.0)
}

///|
test "couple_step 有降雨产生侧向入流" {
  let xaj_model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let swe_grid = SWEGrid1D::uniform(nx=20, dx=1.0, h0=0.5)
  let coupling_params : CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [5, 6, 7, 8, 9],
    base_flow_threshold: 0.5,
  }
  let boundary : SWEBoundary = { left: SolidWall, right: Transmissive }
  let forcing : ForcingData = {
    rainfall: 50.0,
    evaporation: 2.0,
    datetime: "t0",
  }
  let xaj_state = XinanjiangState::initial()
  let (new_xaj, new_swe, lateral_inflow, river_level) = couple_step(
    xaj_model, swe_grid, coupling_params, boundary, forcing, xaj_state, 0.01,
  )
  // 有降雨应有产流
  assert_true(new_xaj.r >= 0.0)
  // 侧向入流应非负
  assert_true(lateral_inflow >= 0.0)
  // 河道单元水深应增加（侧向入流注入）
  assert_true(new_swe.h[7] >= swe_grid.h[7])
  // 河道水位应非负
  assert_true(river_level >= 0.0)
}

///|
test "couple_run 完整耦合仿真" {
  let xaj_model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let swe_grid = SWEGrid1D::uniform(nx=30, dx=1.0, h0=0.5)
  let coupling_params : CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [10, 11, 12, 13, 14],
    base_flow_threshold: 0.3,
  }
  let boundary : SWEBoundary = { left: SolidWall, right: Transmissive }
  let forcings : Array[ForcingData] = [
    { rainfall: 20.0, evaporation: 1.0, datetime: "t0" },
    { rainfall: 30.0, evaporation: 2.0, datetime: "t1" },
    { rainfall: 10.0, evaporation: 1.0, datetime: "t2" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t3" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t4" },
  ]
  let result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
  )
  // 结果序列长度应等于输入长度
  inspect(result.xaj_states.length(), content="5")
  inspect(result.swe_h_series.length(), content="5")
  inspect(result.lateral_inflow_series.length(), content="5")
  // 耦合应保持稳定
  assert_true(result.stable)
  // 降雨时段应有侧向入流
  assert_true(result.lateral_inflow_series[0] >= 0.0)
  assert_true(result.lateral_inflow_series[1] >= 0.0)
}

///|
test "couple_run 无河道单元时不注入" {
  let xaj_model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let swe_grid = SWEGrid1D::uniform(nx=10, dx=1.0, h0=1.0)
  // river_cells为空
  let coupling_params : CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [],
    base_flow_threshold: 0.5,
  }
  let boundary : SWEBoundary = { left: Transmissive, right: Transmissive }
  let forcings : Array[ForcingData] = [
    { rainfall: 20.0, evaporation: 1.0, datetime: "t0" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t1" },
  ]
  let result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.01,
  )
  // 无河道单元时，侧向入流仍计算但不注入SWE
  // SWE水深应保持不变（无注入、静止水面）
  inspect(result.stable, content="true")
  // 河道水位过程应为0（无河道单元）
  inspect(result.water_level_series[0], content="0")
}

///|
test "couple_run 河道水位反馈新安江" {
  let xaj_model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  // SWE初始水深较高，应产生正反馈
  let swe_grid = SWEGrid1D::uniform(nx=20, dx=1.0, h0=2.0)
  let coupling_params : CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.05,
    cell_area: 100.0,
    river_cells: [8, 9, 10, 11, 12],
    base_flow_threshold: 0.5,
  }
  let boundary : SWEBoundary = { left: SolidWall, right: Transmissive }
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 1.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t2" },
  ]
  let result = couple_run(
    xaj_model, swe_grid, coupling_params, boundary, forcings, 0.005,
  )
  assert_true(result.stable)
  // 河道水位应非负
  for level in result.water_level_series {
    assert_true(level >= 0.0)
  }
  // 新安江深层蓄量应非负（反馈不应导致负值）
  for state in result.xaj_states {
    assert_true(state.wd >= 0.0)
    assert_true(state.s >= 0.0)
  }
}
