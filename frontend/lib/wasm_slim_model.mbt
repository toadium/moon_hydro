///|
/// 浏览器内轻量化仿真内核封装(wasm_slim_model)
///
/// 将shared层新安江内核子集封装为前端可用的轻量API
/// 编译为wasm-gc后可在浏览器内直接试算，无需后端
/// 与后端使用完全同一套算法，结果100%一致

///|
/// 轻内仿真请求
pub(all) struct SlimSimRequest {
  area : Double
  dt : Double
  rainfall : Array[Double] // 简化：仅降雨序列
  evaporation : Array[Double] // 蒸发序列
  params : @shared.XinanjiangParams? // P2-51修复：可选自定义参数，None时用默认
} derive(Debug, ToJson, FromJson, Default)

///|
/// 轻内仿真响应
pub(all) struct SlimSimResponse {
  runoff : Array[Double] // 径流过程
  peak_flow : Double // 洪峰
  peak_time : Int // 洪峰时段
  total_volume : Double // 总径流量
  success : Bool // 是否成功
  error : String // 错误信息
} derive(Debug, ToJson, FromJson, Default)

///|
/// 执行轻量化试算
///
/// 使用默认新安江参数，仅输入降雨蒸发序列
/// 适合浏览器内快速试算
pub fn slim_run(request : SlimSimRequest) -> SlimSimResponse {
  let n = request.rainfall.length()
  if n == 0 || n != request.evaporation.length() {
    return {
      runoff: [],
      peak_flow: 0.0,
      peak_time: 0,
      total_volume: 0.0,
      success: false,
      error: "降雨蒸发序列长度不匹配",
    }
  }
  if request.area <= 0.0 || request.dt <= 0.0 {
    return {
      runoff: [],
      peak_flow: 0.0,
      peak_time: 0,
      total_volume: 0.0,
      success: false,
      error: "area和dt必须为正数",
    }
  }
  // 构造forcings
  let forcings : Array[@shared.ForcingData] = []
  for i in 0..<n {
    forcings.push({
      rainfall: request.rainfall[i],
      evaporation: request.evaporation[i],
      datetime: "t\{i}",
    })
  }
  // P2-51修复：使用自定义参数（若提供），否则用默认参数
  let params = match request.params {
    Some(p) => p
    None => @shared.XinanjiangParams::default()
  }
  let model = @shared.XinanjiangModel::new(
    params~,
    area=request.area,
    dt=request.dt,
  )
  let result = model.run(forcings)
  let runoff = result.runoff_series
  // 计算洪峰
  let mut peak_flow = 0.0
  let mut peak_time = 0
  for i in 0..<runoff.length() {
    if runoff[i] > peak_flow {
      peak_flow = runoff[i]
      peak_time = i
    }
  }
  // 计算总量
  let mut total_volume = 0.0
  for v in runoff {
    total_volume = total_volume + v
  }
  { runoff, peak_flow, peak_time, total_volume, success: true, error: "" }
}

///|
/// JSON端到端接口：JSON请求 → JSON响应
///
/// 浏览器wasm-gc直接调用此函数完成试算
pub fn slim_json_endpoint(json_str : String) -> String {
  // P3修复：区分JSON格式错误与其他错误，返回不同消息
  let json = @json.parse(json_str) catch {
    _ => {
      let err_response : SlimSimResponse = {
        runoff: [],
        peak_flow: 0.0,
        peak_time: 0,
        total_volume: 0.0,
        success: false,
        error: "请求格式无效",
      }
      return ToJson::to_json(err_response).stringify()
    }
  }
  try {
    let request : SlimSimRequest = @json.from_json(json)
    let response = slim_run(request)
    let resp_json = ToJson::to_json(response)
    resp_json.stringify()
  } catch {
    _ => {
      let err_response : SlimSimResponse = {
        runoff: [],
        peak_flow: 0.0,
        peak_time: 0,
        total_volume: 0.0,
        success: false,
        error: "服务内部错误",
      }
      ToJson::to_json(err_response).stringify()
    }
  }
}

///|
/// 快速试算：仅降雨序列（蒸发默认）
pub fn quick_run(
  rainfall : Array[Double],
  area? : Double = 100.0,
  dt? : Double = 1.0,
  evap? : Double = 2.0,
) -> SlimSimResponse {
  let evaporation : Array[Double] = []
  for _ in rainfall {
    evaporation.push(evap)
  }
  let request : SlimSimRequest = {
    area,
    dt,
    rainfall,
    evaporation,
    params: None,
  }
  slim_run(request)
}

///|
/// 批量快速试算：多组降雨序列
pub fn quick_batch(
  rainfall_set : Array[Array[Double]],
  area? : Double = 100.0,
  dt? : Double = 1.0,
) -> Array[SlimSimResponse] {
  let results : Array[SlimSimResponse] = []
  for rainfall in rainfall_set {
    results.push(quick_run(rainfall, area~, dt~))
  }
  results
}

///|
/// 流域案例加载：返回流域名称列表
pub fn available_basins() -> Array[String] {
  ["合成基准", "闽江竹岐", "飞云江", "青弋江"]
}

///|
/// 加载指定流域案例的仿真配置
pub fn load_basin_config(name : String) -> SimConfig {
  let case = match name {
    "合成基准" => @shared.synthetic_benchmark_case()
    "闽江竹岐" => @shared.zhuyi_basin_case()
    "飞云江" => @shared.feiyunjiang_basin_case()
    "青弋江" => @shared.qingyijiang_basin_case()
    // 未知流域名回退到合成基准案例
    _ => @shared.synthetic_benchmark_case()
  }
  {
    basin_name: case.name,
    area: case.area,
    dt: case.dt,
    params: case.params,
    forcings: case.forcings,
  }
}
