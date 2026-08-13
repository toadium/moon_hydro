///|
/// 沐澜水文 frontend 入口 - V0.1
///
/// V0.1阶段：空壳占位
/// 后续V0.3阶段将基于Rabbita+Rui搭建完整TEA架构可视化平台
fn main {
  let model = @shared.XinanjiangModel::new(
    params=@shared.XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  ignore(model)
  println("沐澜水文 frontend - V0.1 (占位)")
  println(
    "后续V0.3阶段将基于Rabbita+Rui搭建完整TEA架构可视化平台",
  )
}
