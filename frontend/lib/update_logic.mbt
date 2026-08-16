///|
/// TEA架构状态更新逻辑(Update)
///
/// update: (Model, Msg) -> Model
/// 纯函数式状态更新，无副作用

///|
/// TEA核心update函数
///
/// 根据消息更新模型状态，返回新模型
pub fn update(model : AppModel, msg : Msg) -> AppModel {
  match msg {
    // 页面导航
    NavigateTo(page) =>
      { ..model, ui_state: { ..model.ui_state, current_page: page } }
    // 仿真配置
    SetBasinName(name) =>
      {
        ..model,
        sim_params: { ..model.sim_params, basin_name: name },
        ui_state: { ..model.ui_state, selected_basin: name },
      }
    SetArea(area) => { ..model, sim_params: { ..model.sim_params, area, } }
    SetDt(dt) => { ..model, sim_params: { ..model.sim_params, dt, } }
    SetParams(params) =>
      { ..model, sim_params: { ..model.sim_params, params, } }
    SetForcings(forcings) =>
      { ..model, sim_params: { ..model.sim_params, forcings, } }
    LoadBasinCase(name) => load_basin_case(model, name)
    // 仿真执行
    RunSimulation =>
      {
        ..model,
        sim_result: { ..model.sim_result, is_running: true },
        ui_state: { ..model.ui_state, loading: true },
        error_message: "",
      }
    SimulationCompleted(result) => {
      let runoff = result.runoff_series
      let mut peak_flow = 0.0
      let mut peak_time = 0
      for i in 0..<runoff.length() {
        if runoff[i] > peak_flow {
          peak_flow = runoff[i]
          peak_time = i
        }
      }
      {
        ..model,
        sim_result: {
          runoff_series: runoff,
          peak_flow,
          peak_time,
          nse: result.nse,
          kge: result.kge,
          pbias: result.pbias,
          has_result: true,
          is_running: false,
        },
        ui_state: { ..model.ui_state, loading: false },
      }
    }
    SimulationFailed(err) =>
      {
        ..model,
        sim_result: { ..model.sim_result, is_running: false },
        ui_state: { ..model.ui_state, loading: false },
        error_message: err,
      }
    // 率定
    StartCalibration(_algo) =>
      {
        ..model,
        ui_state: { ..model.ui_state, loading: true },
        error_message: "",
      }
    CalibrationCompleted(_result) =>
      { ..model, ui_state: { ..model.ui_state, loading: false } }
    CalibrationFailed(err) =>
      {
        ..model,
        ui_state: { ..model.ui_state, loading: false },
        error_message: err,
      }
    // 评价
    RunEvaluation(_obs, _sim) => model
    EvaluationCompleted(_result) => model
    // 批量仿真
    RunBatchSim(_tasks) =>
      { ..model, ui_state: { ..model.ui_state, loading: true } }
    BatchCompleted(_result) =>
      { ..model, ui_state: { ..model.ui_state, loading: false } }
    // UI控制
    ToggleParamsPanel =>
      {
        ..model,
        ui_state: {
          ..model.ui_state,
          show_params_panel: not(model.ui_state.show_params_panel),
        },
      }
    ToggleChart =>
      {
        ..model,
        ui_state: {
          ..model.ui_state,
          show_chart: not(model.ui_state.show_chart),
        },
      }
    SetChartType(ct) =>
      { ..model, ui_state: { ..model.ui_state, chart_type: ct } }
    SetLoading(loading) => { ..model, ui_state: { ..model.ui_state, loading, } }
    // 错误处理
    SetError(err) => { ..model, error_message: err }
    ClearError => { ..model, error_message: "" }
    // 历史记录
    AddHistory(entry) => {
      let new_history : Array[HistoryEntry] = []
      for h in model.history {
        new_history.push(h)
      }
      new_history.push(entry)
      // 保留最近100条
      let start = if new_history.length() > 100 {
        new_history.length() - 100
      } else {
        0
      }
      let trimmed : Array[HistoryEntry] = []
      for i in start..<new_history.length() {
        trimmed.push(new_history[i])
      }
      { ..model, history: trimmed }
    }
    ClearHistory => { ..model, history: [] }
    // 重置
    ResetToDefault => AppModel::default()
  }
}

///|
/// 加载流域案例到模型
fn load_basin_case(model : AppModel, name : String) -> AppModel {
  let case = match name {
    "合成基准" => @shared.synthetic_benchmark_case()
    "闽江竹岐" => @shared.zhuyi_basin_case()
    "飞云江" => @shared.feiyunjiang_basin_case()
    "青弋江" => @shared.qingyijiang_basin_case()
    _ => @shared.synthetic_benchmark_case()
  }
  {
    ..model,
    sim_params: {
      basin_name: case.name,
      area: case.area,
      dt: case.dt,
      params: case.params,
      forcings: case.forcings,
    },
    ui_state: { ..model.ui_state, selected_basin: case.name },
  }
}

///|
/// 批量更新：应用多个消息
///
/// update_batch: (Model, Array[Msg]) -> Model
pub fn update_batch(model : AppModel, msgs : Array[Msg]) -> AppModel {
  let mut current = model
  for msg in msgs {
    current = update(current, msg)
  }
  current
}

///|
/// 辅助函数：布尔取反
fn not(b : Bool) -> Bool {
  if b {
    false
  } else {
    true
  }
}
