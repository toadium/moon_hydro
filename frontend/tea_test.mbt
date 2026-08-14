///|
/// TEA架构测试
///
/// 测试Model/Msg/Update/View核心流程

///|
test "AppModel::initial 初始状态" {
  let model = AppModel::initial()
  assert_true(model.ui_state.current_page is HomePage)
  assert_eq(model.sim_params.basin_name, "合成基准")
  assert_true((model.sim_params.area - 100.0).abs() < 0.001)
  assert_eq(model.sim_params.forcings.length(), 5)
  assert_eq(model.history.length(), 0)
  assert_eq(model.error_message, "")
}

///|
test "update NavigateTo 页面导航" {
  let model = AppModel::initial()
  let m1 = update(model, NavigateTo(SimPage))
  assert_true(m1.ui_state.current_page is SimPage)
  let m2 = update(m1, NavigateTo(CalibPage))
  assert_true(m2.ui_state.current_page is CalibPage)
}

///|
test "update SetBasinName 设置流域" {
  let model = AppModel::initial()
  let m1 = update(model, SetBasinName("闽江竹岐"))
  assert_eq(m1.sim_params.basin_name, "闽江竹岐")
  assert_eq(m1.ui_state.selected_basin, "闽江竹岐")
}

///|
test "update LoadBasinCase 加载流域案例" {
  let model = AppModel::initial()
  let m1 = update(model, LoadBasinCase("闽江竹岐"))
  assert_eq(m1.sim_params.basin_name, "闽江竹岐")
  assert_true((m1.sim_params.area - 54500.0).abs() < 0.001)
  assert_true((m1.sim_params.dt - 6.0).abs() < 0.001)
  assert_true(m1.sim_params.forcings.length() > 0)
}

///|
test "update LoadBasinCase 飞云江" {
  let model = AppModel::initial()
  let m1 = update(model, LoadBasinCase("飞云江"))
  assert_eq(m1.sim_params.basin_name, "飞云江")
  assert_true((m1.sim_params.area - 1930.0).abs() < 0.001)
}

///|
test "update RunSimulation 启动仿真" {
  let model = AppModel::initial()
  let m1 = update(model, RunSimulation)
  assert_true(m1.sim_result.is_running)
  assert_true(m1.ui_state.loading)
}

///|
test "update SimulationCompleted 仿真完成" {
  let model = update(AppModel::initial(), RunSimulation)
  // 构造仿真结果
  let xaj_model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
  ]
  let result = xaj_model.run(forcings)
  let m1 = update(model, SimulationCompleted(result))
  assert_true(!m1.sim_result.is_running)
  assert_true(m1.sim_result.has_result)
  assert_true(m1.sim_result.runoff_series.length() == 2)
  assert_true(m1.sim_result.peak_flow > 0.0)
}

///|
test "update ToggleParamsPanel 切换参数面板" {
  let model = AppModel::initial()
  assert_false(model.ui_state.show_params_panel)
  let m1 = update(model, ToggleParamsPanel)
  assert_true(m1.ui_state.show_params_panel)
  let m2 = update(m1, ToggleParamsPanel)
  assert_false(m2.ui_state.show_params_panel)
}

///|
test "update SetError/ClearError 错误处理" {
  let model = AppModel::initial()
  let m1 = update(model, SetError("测试错误"))
  assert_eq(m1.error_message, "测试错误")
  let m2 = update(m1, ClearError)
  assert_eq(m2.error_message, "")
}

///|
test "update AddHistory 历史记录" {
  let model = AppModel::initial()
  let entry : HistoryEntry = {
    timestamp: "2026-09-01",
    action: "运行仿真",
    basin_name: "测试流域",
    success: true,
  }
  let m1 = update(model, AddHistory(entry))
  assert_eq(m1.history.length(), 1)
  let m2 = update(m1, AddHistory(entry))
  assert_eq(m2.history.length(), 2)
  let m3 = update(m2, ClearHistory)
  assert_eq(m3.history.length(), 0)
}

///|
test "update ResetToDefault 重置" {
  let model = AppModel::initial()
  let m1 = update(model, NavigateTo(SimPage))
  let m2 = update(m1, SetError("错误"))
  let m3 = update(m2, ResetToDefault)
  assert_true(m3.ui_state.current_page is HomePage)
  assert_eq(m3.error_message, "")
}

///|
test "update_batch 批量更新" {
  let model = AppModel::initial()
  let msgs : Array[Msg] = [
    NavigateTo(SimPage),
    SetBasinName("测试"),
    ToggleParamsPanel,
  ]
  let m1 = update_batch(model, msgs)
  assert_true(m1.ui_state.current_page is SimPage)
  assert_eq(m1.sim_params.basin_name, "测试")
  assert_true(m1.ui_state.show_params_panel)
}

///|
test "view 首页视图" {
  let model = AppModel::initial()
  let v = view(model)
  let text = view_to_text(v)
  assert_true(text.contains("沐澜水文"))
  assert_true(text.contains("系统概览"))
}

///|
test "view 仿真页视图" {
  let model = update(AppModel::initial(), NavigateTo(SimPage))
  let v = view(model)
  let text = view_to_text(v)
  assert_true(text.contains("新安江模型仿真"))
}

///|
test "view_to_text 表格渲染" {
  let node : ViewNode = VTable(["A", "B"], [["1", "2"], ["3", "4"]])
  let text = view_to_text(node)
  assert_true(text.contains("A"))
  assert_true(text.contains("B"))
  assert_true(text.contains("1"))
  assert_true(text.contains("4"))
}
