///|
/// 沐澜水文 backend 入口 - V0.9
///
/// CLI子命令分发器。当前MoonBit标准库暂无argv/env模块，
/// 默认运行demo子命令。dispatch函数已就绪，待argv支持后接入。
///
/// 可用子命令(20个功能命令 + help): demo, sim, calibrate, dds, validate, batch,
///   ensemble, uncertainty, sensitivity, swe, coupling,
///   timeseries, metrics, json, bench, persistence, auth,
///   ai_forecast, gis, flood, help
fn main raise {
  // P1-1修复：子命令分发器已就绪，当前默认运行demo
  // 待MoonBit标准库提供argv后，改为 dispatch(argv[1])
  dispatch("demo")
}

///|
/// 子命令分发器：根据命令名调用对应子命令
fn dispatch(cmd : String) -> Unit raise {
  match cmd {
    "demo" => cli_demo()
    "sim" => print_cli_result(cli_sim())
    "calibrate" => print_cli_result(cli_calibrate())
    "dds" => print_cli_result(cli_dds())
    "validate" => print_cli_result(cli_validate())
    "batch" => print_cli_result(cli_batch())
    "ensemble" => print_cli_result(cli_ensemble())
    "uncertainty" => print_cli_result(cli_uncertainty())
    "sensitivity" => print_cli_result(cli_sensitivity())
    "swe" => print_cli_result(cli_swe())
    "coupling" => print_cli_result(cli_coupling())
    "timeseries" => print_cli_result(cli_timeseries())
    "metrics" => print_cli_result(cli_metrics())
    "json" => print_cli_result(cli_json())
    "bench" => print_cli_result(cli_bench())
    "persistence" => print_cli_result(cli_persistence())
    "auth" => print_cli_result(cli_auth())
    "ai_forecast" => print_cli_result(cli_ai_forecast())
    "gis" => print_cli_result(cli_gis())
    "flood" => print_cli_result(cli_flood())
    "help" => cli_help()
    _ => {
      println("未知子命令: \{cmd}")
      cli_help()
    }
  }
}
