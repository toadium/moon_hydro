///|
/// HydroModel通用模型特征接口
///
/// 统一全部水文模型（含未来AI模型）的步进仿真调用规范
/// 支持扩展LSTM、PINN等模块
pub trait HydroModel {
  /// 单步仿真：输入气象驱动与当前状态，输出更新后状态
  fn step(self : Self, forcing : ForcingData, state : XinanjiangState) -> XinanjiangState

  /// 完整仿真：输入气象驱动序列，输出仿真结果
  fn run(self : Self, forcings : Array[ForcingData]) -> SimResult
}
