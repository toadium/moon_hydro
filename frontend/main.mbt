///|
/// 沐澜水文 frontend 入口 - V0.9.1
///
/// TEA架构(Model/Msg/Update/View) + wasm_slim_model轻量化试算
/// 后续V1.0接入Rabbita+Rui时，View转换为Rui组件树

///|
/// P1修复：按字符截断字符串，避免截断UTF-8多字节字符
fn safe_preview(s : String, max_bytes : Int) -> String {
  if s.length() <= max_bytes {
    return s
  }
  let buf = StringBuilder()
  let mut byte_count = 0
  for ch in s.iter() {
    let ch_len = ch.to_string().length()
    if byte_count + ch_len > max_bytes {
      break
    }
    buf.write_char(ch)
    byte_count = byte_count + ch_len
  }
  buf.to_string() + "..."
}

///|
fn main {
  println("===== 沐澜水文 frontend V0.9.1 - TEA架构演示 =====")
  // 初始化Model
  let mut model = @lib.AppModel::initial()
  println(
    "初始状态: 页面=\{model.ui_state.current_page}, 流域=\{model.sim_params.basin_name}",
  )
  // TEA消息循环演示
  // 1. 导航到仿真页
  model = @lib.update(model, @lib.Msg::NavigateTo(@lib.Page::SimPage))
  println("导航后: 页面=\{model.ui_state.current_page}")
  // 2. 加载闽江竹岐流域
  model = @lib.update(model, @lib.Msg::LoadBasinCase("闽江竹岐"))
  println(
    "加载案例后: 流域=\{model.sim_params.basin_name}, 面积=\{model.sim_params.area} km²",
  )
  // 3. 运行仿真
  model = @lib.update(model, @lib.Msg::RunSimulation)
  println("启动仿真: is_running=\{model.sim_result.is_running}")
  // 4. 执行实际仿真（通过wasm_slim_model）
  let slim_request : @lib.SlimSimRequest = {
    area: model.sim_params.area,
    dt: model.sim_params.dt,
    rainfall: model.sim_params.forcings.map(fn(f) { f.rainfall }),
    evaporation: model.sim_params.forcings.map(fn(f) { f.evaporation }),
    params: Some(model.sim_params.params), // P2修复：使用实际加载的流域参数
  }
  let slim_result = @lib.slim_run(slim_request)
  println(
    "转内试算: 洪峰=\{slim_result.peak_flow}, 总量=\{slim_result.total_volume}",
  )
  // 5. 仿真完成，更新Model
  let xaj_model = @shared.XinanjiangModel::new(
    params=model.sim_params.params,
    area=model.sim_params.area,
    dt=model.sim_params.dt,
  )
  let xaj_result = xaj_model.run(model.sim_params.forcings)
  model = @lib.update(model, @lib.Msg::SimulationCompleted(xaj_result))
  println(
    "仿真完成: 洪峰=\{model.sim_result.peak_flow} m³/s, 时段=\{model.sim_result.peak_time}",
  )
  // 6. 生成视图并渲染为文本
  let view_node = @lib.view(model)
  let report = @lib.view_to_text(view_node)
  let report_preview = safe_preview(report, 500)
  println("\n===== 视图文本渲染 =====")
  println(report_preview)
  // 7. 轻量化试算演示
  println("\n===== wasm_slim_model 轻内试算 =====")
  let quick_result = @lib.quick_run([10.0, 20.0, 5.0, 0.0, 30.0])
  println(
    "快速试算: 洪峰=\{quick_result.peak_flow}, 总量=\{quick_result.total_volume}",
  )
  // 8. JSON端到端演示
  let json_request = ToJson::to_json(slim_request).stringify()
  let json_response = @lib.slim_json_endpoint(json_request)
  let resp_preview = safe_preview(json_response, 200)
  println("JSON响应: \{resp_preview}")
  // 9. 可用流域列表
  println("\n===== 可用流域 =====")
  let basins = @lib.available_basins()
  for name in basins {
    let config = @lib.load_basin_config(name)
    println("  \{name}: 面积=\{config.area} km², 时段=\{config.dt} h")
  }
}
