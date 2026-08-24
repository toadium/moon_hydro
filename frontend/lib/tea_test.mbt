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

///|
test "update SetArea/SetDt 设置参数" {
  let model = AppModel::initial()
  let m1 = update(model, SetArea(200.0))
  assert_true((m1.sim_params.area - 200.0).abs() < 0.001)
  let m2 = update(m1, SetDt(3.0))
  assert_true((m2.sim_params.dt - 3.0).abs() < 0.001)
}

///|
test "update SetParams/SetForcings 设置参数与驱动" {
  let model = AppModel::initial()
  let params = @shared.XinanjiangParams::default()
  let m1 = update(model, SetParams(params))
  assert_eq(m1.sim_params.params.wm, params.wm)
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 5.0, evaporation: 1.0, datetime: "t0" },
  ]
  let m2 = update(m1, SetForcings(forcings))
  assert_eq(m2.sim_params.forcings.length(), 1)
}

///|
test "update SimulationFailed 仿真失败" {
  let model = update(AppModel::initial(), RunSimulation)
  let m1 = update(model, SimulationFailed("参数错误"))
  assert_false(m1.sim_result.is_running)
  assert_false(m1.ui_state.loading)
  assert_eq(m1.error_message, "参数错误")
}

///|
test "update StartCalibration/CalibrationCompleted/CalibrationFailed 率定流程" {
  let model = AppModel::initial()
  let m1 = update(model, StartCalibration("sceua"))
  assert_true(m1.ui_state.loading)
  assert_eq(m1.error_message, "")
  let calib_result : @shared.CalibResult = {
    best_metric: 0.9,
    best_params: [],
    converged: true,
    metric_history: [],
    n_iter: 10,
  }
  let m2 = update(m1, CalibrationCompleted(calib_result))
  assert_false(m2.ui_state.loading)
  let m3 = update(m1, CalibrationFailed("率定失败"))
  assert_false(m3.ui_state.loading)
  assert_eq(m3.error_message, "率定失败")
}

///|
test "update RunEvaluation/EvaluationCompleted 评价流程" {
  let model = AppModel::initial()
  let m1 = update(model, RunEvaluation([1.0, 2.0], [1.1, 2.1]))
  assert_eq(m1.sim_params.basin_name, model.sim_params.basin_name)
  // P1-4修复验证：RunEvaluation应设置loading状态
  assert_true(m1.ui_state.loading)
  let eval_result : @shared.EvaluationResult = {
    grade: @shared.ForecastGrade::Excellent,
    grade_nse: @shared.ForecastGrade::Excellent,
    grade_pbias: @shared.ForecastGrade::Excellent,
    kge: 0.9,
    nse: 0.9,
    pbias: 1.0,
    peak_error: 0.5,
    peak_time_error: 0,
    r_squared: 0.9,
    rmse: 0.1,
    volume_error: 2.0,
  }
  let m2 = update(m1, EvaluationCompleted(eval_result))
  assert_eq(m2.sim_params.basin_name, model.sim_params.basin_name)
  // P1-4修复验证：EvaluationCompleted应存入评价指标并清除loading
  // P3修复验证：评价结果存入专用字段eval_nse/eval_kge/eval_pbias
  assert_false(m2.ui_state.loading)
  assert_true((m2.sim_result.eval_nse - 0.9).abs() < 0.001)
  assert_true((m2.sim_result.eval_kge - 0.9).abs() < 0.001)
  assert_true((m2.sim_result.eval_pbias - 1.0).abs() < 0.001)
}

///|
test "update RunBatchSim/BatchCompleted 批量流程" {
  let model = AppModel::initial()
  let m1 = update(model, RunBatchSim([]))
  assert_true(m1.ui_state.loading)
  let batch_result : @shared.BatchSimResult = {
    failure_count: 0,
    results: [],
    success_count: 1,
    summary_stats: {
      best_nse: 0.9,
      mean_kge: 0.85,
      mean_nse: 0.88,
      mean_pbias: 2.0,
      mean_peak_flow: 500.0,
      total_volume: 1000.0,
      worst_nse: 0.8,
    },
    total_tasks: 1,
    total_time_steps: 5,
  }
  let m2 = update(m1, BatchCompleted(batch_result))
  assert_false(m2.ui_state.loading)
}

///|
test "update ToggleChart/SetChartType/SetLoading UI控制" {
  let model = AppModel::initial()
  let m1 = update(model, ToggleChart)
  assert_false(m1.ui_state.show_chart)
  let m2 = update(m1, SetChartType(BarChart))
  assert_true(m2.ui_state.chart_type is BarChart)
  let m3 = update(m2, SetLoading(true))
  assert_true(m3.ui_state.loading)
}

///|
test "update AddHistory 超过100条截断" {
  let model = AppModel::initial()
  let mut m = model
  for i in 0..<105 {
    let entry : HistoryEntry = {
      timestamp: "t\{i}",
      action: "act",
      basin_name: "basin",
      success: true,
    }
    m = update(m, AddHistory(entry))
  }
  assert_eq(m.history.length(), 100)
}

///|
test "update LoadBasinCase 合成基准与青弋江" {
  let model = AppModel::initial()
  let m1 = update(model, LoadBasinCase("合成基准"))
  assert_eq(m1.sim_params.basin_name, "合成基准")
  let m2 = update(model, LoadBasinCase("青弋江"))
  assert_eq(m2.sim_params.basin_name, "青弋江")
}

///|
test "view 率定页视图" {
  let model = update(AppModel::initial(), NavigateTo(CalibPage))
  let v = view(model)
  let text = view_to_text(v)
  assert_true(text.contains("参数率定"))
}

///|
test "view 评价页视图" {
  let model = update(AppModel::initial(), NavigateTo(EvalPage))
  let v = view(model)
  let text = view_to_text(v)
  assert_true(text.contains("评价指标"))
}

///|
test "view 批量页视图" {
  let model = update(AppModel::initial(), NavigateTo(BatchPage))
  let v = view(model)
  let text = view_to_text(v)
  assert_true(text.contains("批量仿真"))
}

///|
test "view 设置页视图" {
  let model = update(AppModel::initial(), NavigateTo(SettingsPage))
  let v = view(model)
  let text = view_to_text(v)
  assert_true(text.contains("设置"))
}

///|
test "Page Show实现" {
  assert_eq(Page::HomePage.to_string(), "首页")
  assert_eq(Page::SimPage.to_string(), "仿真")
  assert_eq(Page::CalibPage.to_string(), "率定")
  assert_eq(Page::EvalPage.to_string(), "评价")
  assert_eq(Page::BatchPage.to_string(), "批量")
  assert_eq(Page::SettingsPage.to_string(), "设置")
}

///|
test "ChartType Show实现" {
  assert_eq(ChartType::LineChart.to_string(), "折线图")
  assert_eq(ChartType::BarChart.to_string(), "柱状图")
  assert_eq(ChartType::HeatMap.to_string(), "热力图")
  assert_eq(ChartType::ScatterPlot.to_string(), "散点图")
  assert_eq(ChartType::Hydrograph.to_string(), "流量过程线")
}

///|
test "Page/ChartType Default实现" {
  let p : Page = Page::default()
  assert_true(p is HomePage)
  let ct : ChartType = ChartType::default()
  assert_true(ct is Hydrograph)
}
