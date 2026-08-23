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
          ..model.sim_result,
          runoff_series: runoff,
          peak_flow,
          peak_time,
          nse: result.nse,
          kge: result.kge,
          pbias: result.pbias,
          has_result: runoff.length() > 0, // P2-46修复：空序列时has_result为false
          is_running: false,
          batch_summary: "",
        },
        ui_state: { ..model.ui_state, loading: false },
      }
    }
    SimulationFailed(err) =>
      {
        ..model,
        sim_result: { ..model.sim_result, is_running: false, has_result: false }, // P2修复：失败时清除旧结果
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
    // P1-5修复：率定结果存入专用字段calib_metric/calib_value，避免语义错乱
    CalibrationCompleted(result) =>
      {
        ..model,
        sim_result: {
          ..model.sim_result,
          calib_metric: "nse",
          calib_value: result.best_metric,
        },
        ui_state: { ..model.ui_state, loading: false },
      }
    CalibrationFailed(err) =>
      {
        ..model,
        ui_state: { ..model.ui_state, loading: false },
        error_message: err,
      }
    // 评价
    // P1-4修复：RunEvaluation设置loading状态，不再为no-op
    RunEvaluation(_obs, _sim) =>
      {
        ..model,
        ui_state: { ..model.ui_state, loading: true },
        error_message: "",
      }
    // P1-4修复：EvaluationCompleted存入评价指标，不再为no-op
    EvaluationCompleted(result) =>
      {
        ..model,
        sim_result: {
          ..model.sim_result,
          nse: result.nse,
          kge: result.kge,
          pbias: result.pbias,
        },
        ui_state: { ..model.ui_state, loading: false },
      }
    // 批量仿真
    RunBatchSim(_tasks) =>
      { ..model, ui_state: { ..model.ui_state, loading: true } }
    BatchCompleted(result) =>
      {
        ..model,
        sim_result: {
          ..model.sim_result,
          batch_summary: "任务=\{result.total_tasks}, 成功=\{result.success_count}, 失败=\{result.failure_count}, 平均NSE=\{result.summary_stats.mean_nse}, 平均KGE=\{result.summary_stats.mean_kge}",
        },
        ui_state: { ..model.ui_state, loading: false },
      }
    // UI控制
    // P2-1修复：使用内置!操作符替代自定义not函数
    ToggleParamsPanel =>
      {
        ..model,
        ui_state: {
          ..model.ui_state,
          show_params_panel: !model.ui_state.show_params_panel,
        },
      }
    ToggleChart =>
      {
        ..model,
        ui_state: { ..model.ui_state, show_chart: !model.ui_state.show_chart },
      }
    SetChartType(ct) =>
      { ..model, ui_state: { ..model.ui_state, chart_type: ct } }
    SetLoading(loading) => { ..model, ui_state: { ..model.ui_state, loading, } }
    // 错误处理
    SetError(err) => { ..model, error_message: err }
    ClearError => { ..model, error_message: "" }
    // 历史记录
    // P1-3修复：使用+操作符函数式追加，仅截断时用循环
    AddHistory(entry) => {
      let new_history = model.history + [entry]
      // 保留最近100条
      let len = new_history.length()
      if len <= 100 {
        { ..model, history: new_history }
      } else {
        let start = len - 100
        let trimmed : Array[HistoryEntry] = []
        for i in start..<len {
          trimmed.push(new_history[i])
        }
        { ..model, history: trimmed }
      }
    }
    ClearHistory => { ..model, history: [] }
    // 重置
    ResetToDefault => AppModel::default()
  }
}

///|
/// 加载流域案例到模型（P2-2修复：复用load_basin_config消除重复逻辑）
fn load_basin_case(model : AppModel, name : String) -> AppModel {
  let config = load_basin_config(name)
  {
    ..model,
    sim_params: config,
    ui_state: { ..model.ui_state, selected_basin: config.basin_name },
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
