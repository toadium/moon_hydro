///|
/// 重力加速度(m/s²)
let g_gravity : Double = 9.81

///|
/// 新安江模型参数组合（17+项）
///
/// 三层蓄水容量满足 wm = wum + wlm + wdm
/// wum上层、wlm下层、wdm深层
pub(all) struct XinanjiangParams {
  wm : Double // 流域平均张力水蓄水容量(mm)
  wum : Double // 上层张力水蓄水容量(mm)
  wlm : Double // 下层张力水蓄水容量(mm)
  wdm : Double // 深层张力水蓄水容量(mm)
  b : Double // 蓄水容量曲线指数
  im : Double // 不透水面积比例
  c : Double // 蒸散发系数
  sm : Double // 流域平均自由水蓄水容量(mm)
  ex : Double // 自由水容量曲线指数
  kg : Double // 地下水消退系数
  ki : Double // 壤中流消退系数
  cg : Double // 地下水汇流消退系数
  ci : Double // 壤中流汇流消退系数
  cs : Double // 地表水汇流消退系数
  ke : Double // Muskingum K参数(槽蓄时间常数)
  x : Double // Muskingum x参数
  y : Double // Muskingum y参数
  n : Int // 单位线时段数
  l : Int // 滞后时间(时段数)
  fr : Double // 产流面积比例
  kg1 : Double // 三水源地下水消退系数1
  ki1 : Double // 三水源壤中流消退系数1
  kg2 : Double // 三水源地下水消退系数2
  ki2 : Double // 三水源壤中流消退系数2
  t0 : Double // 时间参数0
  t1 : Double // 时间参数1
  td : Double // 时间参数d
  u0 : Double // 单位线纵坐标0
  u1 : Double // 单位线纵坐标1
  u2 : Double // 单位线纵坐标2
} derive(Debug, ToJson, FromJson, Default)

///|
/// 新安江模型瞬时仿真状态（可变）
pub(all) struct XinanjiangState {
  mut w : Double // 张力水蓄量(mm)
  mut wu : Double // 上层张力水蓄量(mm)
  mut wl : Double // 下层张力水蓄量(mm)
  mut wd : Double // 深层张力水蓄量(mm)
  mut s : Double // 自由水蓄量(mm)
  mut r : Double // 时段产流量(mm)
  mut rs : Double // 地表径流(mm)
  mut ri : Double // 壤中流(mm)
  mut rg : Double // 地下径流(mm)
  mut e : Double // 时段蒸散发量(mm)
  mut q : Double // 出口断面流量(m³/s)
  mut qs : Double // 地表水汇流分量(m³/s) P1-1修复：保存路由状态
  mut qi : Double // 壤中流汇流分量(m³/s)
  mut qg : Double // 地下水汇流分量(m³/s)
} derive(Debug, ToJson, FromJson, Default)

///|
/// 气象驱动时序数据
pub(all) struct ForcingData {
  rainfall : Double // 时段降雨量(mm)
  evaporation : Double // 时段蒸散发能力(mm)
  datetime : String // 时间标识(ISO格式或时段序号)
} derive(Debug, ToJson, FromJson, Default)

///|
/// 仿真输出结果与评价指标
pub(all) struct SimResult {
  runoff_series : Array[Double] // 径流过程序列
  state_series : Array[XinanjiangState] // 状态过程序列
  nse : Double // Nash-Sutcliffe效率系数
  kge : Double // Kling-Gupta效率系数
  pbias : Double // 偏差百分比
} derive(Debug, ToJson, FromJson)

///|
/// 率定配置（SCE-UA/DDS）
pub(all) struct CalibConfig {
  algorithm : String // 算法名称("sceua"或"dds")
  params_range : Array[(String, Double, Double)] // 参数范围(名称,下限,上限)
  max_iter : Int // 最大迭代次数
  target_metric : String // 目标指标("nse"或"kge")
} derive(Debug, ToJson, FromJson) // 修复：移除Default，外部应使用显式构造，勿用Default（零值非法）

///|
/// 构造默认新安江参数（三水源新安江模型典型值）
pub fn XinanjiangParams::default() -> XinanjiangParams {
  {
    wm: 120.0,
    wum: 20.0,
    wlm: 60.0,
    wdm: 40.0,
    b: 0.3,
    im: 0.01,
    c: 1.0,
    sm: 20.0,
    ex: 1.5,
    kg: 0.35,
    ki: 0.3,
    cg: 0.98,
    ci: 0.63,
    cs: 0.2,
    ke: 1.0,
    x: 0.3,
    y: 0.6,
    n: 3,
    l: 0,
    fr: 1.0,
    kg1: 0.35,
    ki1: 0.3,
    kg2: 0.35,
    ki2: 0.3,
    t0: 0.0,
    t1: 0.0,
    td: 1.0,
    u0: 0.0,
    u1: 0.5,
    u2: 0.5,
  }
}

///|
/// 构造初始状态（全零）
pub fn XinanjiangState::initial() -> XinanjiangState {
  {
    w: 0.0,
    wu: 0.0,
    wl: 0.0,
    wd: 0.0,
    s: 0.0,
    r: 0.0,
    rs: 0.0,
    ri: 0.0,
    rg: 0.0,
    e: 0.0,
    q: 0.0,
    qs: 0.0,
    qi: 0.0,
    qg: 0.0,
  }
}
