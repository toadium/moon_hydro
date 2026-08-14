///|
/// 沐澜水文 backend 入口 - V0.1
///
/// V0.1阶段：native后端编译验证（新安江+SWE+耦合）
/// 后续V0.2阶段将基于Proton搭建完整RESTful API
fn main {
  // ===== 新安江模型仿真 =====
  let xaj_model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "2026-09-01T00:00" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "2026-09-01T01:00" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "2026-09-01T02:00" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "2026-09-01T03:00" },
    { rainfall: 30.0, evaporation: 2.0, datetime: "2026-09-01T04:00" },
  ]
  let xaj_result = xaj_model.run(forcings)
  println("===== 沐澜水文 V0.1 - 新安江模型仿真 =====")
  println("流域面积: 100.0 km², 时段: 1.0 h")
  println("降雨序列: [10, 20, 5, 0, 30] mm")
  println("径流序列: \{to_repr(xaj_result.runoff_series)}")

  // ===== SWE浅水方程仿真 =====
  let swe_grid = @shared.SWEGrid1D::uniform(nx=50, dx=1.0, h0=1.0)
  let swe_config : @shared.SWESolverConfig = {
    dt: 0.01,
    n_steps: 50,
    cfl: 0.4,
    boundary: {
      left: @shared.SWEBoundaryType::SolidWall,
      right: @shared.SWEBoundaryType::Transmissive,
    },
  }
  let swe_result = swe_grid.run(swe_config)
  println("\n===== SWE浅水方程仿真 =====")
  println("网格: 50单元, dx=1.0m, 初始水深=1.0m")
  println("时间步: 50步, dt=0.01s, CFL=0.4")
  println("稳定性: \{swe_result.stable}")
  println("最大水深: \{to_repr(swe_result.max_depth[25])}")

  // ===== 新安江+SWE耦合仿真 =====
  let coupling_params : @shared.CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    base_flow_threshold: 0.3,
    n_river_cells: 10,
  }
  let swe_boundary : @shared.SWEBoundary = {
    left: @shared.SWEBoundaryType::SolidWall,
    right: @shared.SWEBoundaryType::Transmissive,
  }
  let coupling_grid = @shared.SWEGrid1D::uniform(nx=50, dx=1.0, h0=0.5)
  let coupling_result = @shared.couple_run(
    xaj_model, coupling_grid, coupling_params, swe_boundary, forcings, 0.005,
  )
  println("\n===== 新安江+SWE耦合仿真 =====")
  println("河道单元: [10..19], 侧向入流系数: 0.8, 反馈系数: 0.01")
  println("耦合稳定性: \{coupling_result.stable}")
  println(
    "侧向入流过程: \{to_repr(coupling_result.lateral_inflow_series)}",
  )
  println("河道水位过程: \{to_repr(coupling_result.water_level_series)}")
}
