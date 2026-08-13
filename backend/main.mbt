///|
/// 沐澜水文 backend 入口 - V0.1
///
/// V0.1阶段：native后端编译验证
/// 后续V0.2阶段将基于Proton搭建完整RESTful API
fn main {
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[@shared.ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "2026-09-01T00:00" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "2026-09-01T01:00" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "2026-09-01T02:00" },
  ]
  let result = model.run(forcings)
  println("沐澜水文 V0.1 - 新安江模型仿真")
  println("流域面积: 100.0 km², 时段: 1.0 h")
  println("降雨序列: [10.0, 20.0, 5.0] mm")
  println("径流序列: \{result.runoff_series}")
  println("状态序列长度: \{result.state_series.length()}")
}
