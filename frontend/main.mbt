///|
/// 沐澜水文 frontend 入口 - V0.4
///
/// TEA架构(Model/Msg/Update/View) + wasm_slim_model轻量化试算
/// 后续V1.0接入Rabbita+Rui时，View转换为Rui组件树
fn main raise {
  println("===== 沐澜水文 frontend V0.4 - TEA架构演示 =====")
  // 初始化Model
  let mut model = AppModel::initial()
  println(
    "初始状态: 页面=\{model.ui_state.current_page}, 流域=\{model.sim_params.basin_name}",
  )
  // TEA消息循环演示
  // 1. 导航到仿真页
  model = update(model, NavigateTo(SimPage))
  println("导航后: 页面=\{model.ui_state.current_page}")
  // 2. 加载闽江竹岐流域
  model = update(model, LoadBasinCase("闽江竹岐"))
  println(
    "加载案例后: 流域=\{model.sim_params.basin_name}, 面积=\{model.sim_params.area} km²",
  )
  // 3. 运行仿真
  model = update(model, RunSimulation)
  println("启动仿真: is_running=\{model.sim_result.is_running}")
  // 4. 执行实际仿真（通过wasm_slim_model）
  let slim_request : SlimSimRequest = {
    area: model.sim_params.area,
    dt: model.sim_params.dt,
    rainfall: [
      model.sim_params.forcings[0].rainfall,
      model.sim_params.forcings[1].rainfall,
      model.sim_params.forcings[2].rainfall,
      model.sim_params.forcings[3].rainfall,
      model.sim_params.forcings[4].rainfall,
    ],
    evaporation: [
      model.sim_params.forcings[0].evaporation,
      model.sim_params.forcings[1].evaporation,
      model.sim_params.forcings[2].evaporation,
      model.sim_params.forcings[3].evaporation,
      model.sim_params.forcings[4].evaporation,
    ],
  }
  let slim_result = slim_run(slim_request)
  println(
    "转内试算: 洪峰=\{Repr(slim_result.peak_flow)}, 总量=\{Repr(slim_result.total_volume)}",
  )
  // 5. 仿真完成，更新Model
  let xaj_model = @shared.XinanjiangModel::new(
    params=model.sim_params.params,
    area=model.sim_params.area,
    dt=model.sim_params.dt,
  )
  let xaj_result = xaj_model.run(model.sim_params.forcings)
  model = update(model, SimulationCompleted(xaj_result))
  println(
    "仿真完成: 洪峰=\{Repr(model.sim_result.peak_flow)} m³/s, 时段=\{model.sim_result.peak_time}",
  )
  // 6. 生成视图并渲染为文本
  let view_node = view(model)
  let report = view_to_text(view_node)
  let report_preview = if report.length() > 500 {
    report[0:500].to_owned() + "..."
  } else {
    report
  }
  println("\n===== 视图文本渲染 =====")
  println(report_preview)
  // 7. 轻量化试算演示
  println("\n===== wasm_slim_model 轻内试算 =====")
  let quick_result = quick_run([10.0, 20.0, 5.0, 0.0, 30.0])
  println(
    "快速试算: 洪峰=\{Repr(quick_result.peak_flow)}, 总量=\{Repr(quick_result.total_volume)}",
  )
  // 8. JSON端到端演示
  let json_request = @json.to_json(slim_request).stringify()
  let json_response = slim_json_endpoint(json_request)
  let resp_preview = if json_response.length() > 200 {
    json_response[0:200].to_owned() + "..."
  } else {
    json_response
  }
  println("JSON响应: \{resp_preview}")
  // 9. 可用流域列表
  println("\n===== 可用流域 =====")
  let basins = available_basins()
  for name in basins {
    let config = load_basin_config(name)
    println("  \{name}: 面积=\{config.area} km², 时段=\{config.dt} h")
  }
}
