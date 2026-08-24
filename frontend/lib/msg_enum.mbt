///|
/// 前端交互消息枚举定义(Msg)
///
/// TEA架构中的Msg：所有用户交互与系统事件统一建模为消息
/// update函数根据Msg类型更新Model

///|
/// 前端消息枚举
pub(all) enum Msg {
  // 页面导航
  NavigateTo(Page)
  // 仿真配置
  SetBasinName(String)
  SetArea(Double)
  SetDt(Double)
  SetParams(@shared.XinanjiangParams)
  SetForcings(Array[@shared.ForcingData])
  LoadBasinCase(String)
  // 仿真执行
  RunSimulation
  SimulationCompleted(@shared.SimResult)
  SimulationFailed(String)
  // 率定
  StartCalibration(String) // 算法名"dds"或"sceua"
  CalibrationCompleted(@shared.CalibResult)
  CalibrationFailed(String)
  // 评价
  RunEvaluation(Array[Double], Array[Double])
  EvaluationCompleted(@shared.EvaluationResult)
  EvaluationFailed(String)
  // 批量仿真
  RunBatchSim(Array[@shared.SimTask])
  BatchCompleted(@shared.BatchSimResult)
  BatchFailed(String)
  // UI控制
  ToggleParamsPanel
  ToggleChart
  SetChartType(ChartType)
  SetLoading(Bool)
  // 错误处理
  SetError(String)
  ClearError
  // 历史记录
  AddHistory(HistoryEntry)
  ClearHistory
  // 重置
  ResetToDefault
} derive(Debug, ToJson, FromJson)
