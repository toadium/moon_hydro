///|
/// HydroModel通用模型特征接口
///
/// 统一全部水文模型（含未来AI模型）的步进仿真调用规范
/// 支持扩展LSTM、PINN等模块
///
/// P1-5修复说明：当前trait签名绑定XinanjiangState/SimResult，
/// 这是MoonBit类型系统限制下的务实选择。未来泛化方案：
/// 1. 引入ModelState trait，让各模型State实现统一接口
/// 2. 或使用MoonBit的泛型trait（若后续版本支持关联类型）
/// 3. 或为不同模型族定义独立trait（HydroXajModel/HydroLstmModel）
/// 当前保持XinanjiangState绑定，通过run()返回SimResult保证输出一致性
pub trait HydroModel {
  /// 单步仿真：输入气象驱动与当前状态，输出更新后状态
  fn step(self : Self, forcing : ForcingData, state : XinanjiangState) -> XinanjiangState

  /// 完整仿真：输入气象驱动序列，输出仿真结果
  fn run(self : Self, forcings : Array[ForcingData]) -> SimResult
}
