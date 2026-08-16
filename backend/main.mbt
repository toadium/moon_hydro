///|
/// 沐澜水文 backend 入口 - V0.5
///
/// CLI子命令分发器。由于MoonBit标准库暂无argv模块，
/// 默认运行demo子命令。各子命令函数在cli.mbt中定义。
///
/// 可用子命令: demo, sim, calibrate, dds, validate, batch,
///   ensemble, uncertainty, sensitivity, swe, coupling,
///   timeseries, metrics, json, bench, persistence, auth, help
fn main raise {
  cli_demo()
}
