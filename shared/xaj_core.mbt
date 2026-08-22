///|
/// 新安江模型仿真器
///
/// 三水源新安江模型XAJ完整实现：
/// 三层蒸散发 → 蓄满产流 → 自由水三水源划分 → 汇流演算
pub(all) struct XinanjiangModel {
  params : XinanjiangParams
  area : Double // 流域面积(km²)
  dt : Double // 时段长度(h)
}

///|
/// 构造新安江模型
pub fn XinanjiangModel::new(
  params~ : XinanjiangParams,
  area~ : Double,
  dt~ : Double,
) -> XinanjiangModel {
  { params, area, dt }
}

///|
/// 三层蒸散发计算
///
/// 按"先上层、后下层、再深层"顺序计算蒸散发
/// 更新state中的wu/wl/wd/w/e
fn XinanjiangModel::compute_evaporation(
  self : XinanjiangModel,
  p : Double,
  em : Double,
  state : XinanjiangState,
) -> Unit {
  let params = self.params

  let wlm = params.wlm
  let c = params.c
  let mut eu = 0.0
  let mut el = 0.0
  let mut ed = 0.0
  let wu = state.wu
  let wl = state.wl
  let wd = state.wd
  if p + wu >= em {
    eu = em
    el = 0.0
    ed = 0.0
  } else if c * (p + wu) >= em {
    eu = p + wu
    el = (em - eu) * wl / wlm
    ed = 0.0
  } else {
    eu = p + wu
    if wl / wlm >= c * (p + wu) / em {
      el = c * (em - eu) * wl / wlm
      ed = 0.0
    } else {
      el = wl
      ed = c * (em - eu) - el
      if ed > wd {
        ed = wd
      }
    }
  }
  state.wu = wu + p - eu
  if state.wu < 0.0 {
    state.wu = 0.0
  }
  state.wl = wl - el
  if state.wl < 0.0 {
    state.wl = 0.0
  }
  state.wd = wd - ed
  if state.wd < 0.0 {
    state.wd = 0.0
  }
  state.w = state.wu + state.wl + state.wd
  state.e = eu + el + ed
}

///|
/// 蓄满产流计算
///
/// 基于蓄水容量曲线计算产流量
/// 返回产流量R，更新state中的w/r
fn XinanjiangModel::compute_runoff(
  self : XinanjiangModel,
  pe : Double,
  state : XinanjiangState,
) -> Double {
  let params = self.params
  let wm = params.wm
  let b = params.b
  let im = params.im
  let w = state.w
  let mm = wm * (1.0 + b)
  let a = wm * (1.0 - @math.pow(1.0 - w / wm, 1.0 / (1.0 + b)))
  let mut r = 0.0
  if pe <= 0.0 {
    r = 0.0
  } else if pe + a < mm {
    r = pe + w - wm + mm * (1.0 - @math.pow((pe + a) / mm, 1.0 / (1.0 + b)))
  } else {
    r = pe + w - wm
  }
  if r < 0.0 {
    r = 0.0
  }
  let r_im = im * pe
  let r_b = (1.0 - im) * r
  r = r_im + r_b
  state.w = w + pe - r
  if state.w < 0.0 {
    state.w = 0.0
  }
  if state.w > wm {
    state.w = wm
  }
  state.r = r
  r
}

///|
/// 自由水三水源划分
///
/// 将产流量划分为地表径流rs、壤中流ri、地下径流rg
/// 更新state中的s/rs/ri/rg
fn XinanjiangModel::compute_source_split(
  self : XinanjiangModel,
  r : Double,
  state : XinanjiangState,
) -> Unit {
  let params = self.params
  let sm = params.sm
  let ex = params.ex
  let kg = params.kg
  let ki = params.ki
  let fr = params.fr
  let s = state.s
  let mut rs = 0.0
  let mut ri = 0.0
  let mut rg = 0.0
  if fr > 0.0 {
    let s_ratio = if sm > 0.0 { s / sm } else { 0.0 }
    let s_ratio_safe = if s_ratio < 0.0 {
      0.0
    } else if s_ratio > 1.0 {
      1.0
    } else {
      s_ratio
    }
    rs = r * (fr + (1.0 - fr) * @math.pow(s_ratio_safe, ex))
    ri = ki * s * fr
    rg = kg * s * fr
  } else {
    rs = r
    ri = 0.0
    rg = 0.0
  }
  state.s = s + r - rs - ri - rg
  if state.s < 0.0 {
    state.s = 0.0
  }
  if state.s > sm {
    state.s = sm
  }
  state.rs = rs
  state.ri = ri
  state.rg = rg
}

///|
/// 汇流演算
///
/// 地表水用消退系数法、壤中流和地下水用线性水库
/// 返回(qs, qi, qg)，更新state中的q
fn XinanjiangModel::compute_routing(
  self : XinanjiangModel,
  state : XinanjiangState,
  prev_qs : Double,
  prev_qi : Double,
  prev_qg : Double,
) -> (Double, Double, Double) {
  let params = self.params
  let cs = params.cs
  let ci = params.ci
  let cg = params.cg
  let rs = state.rs
  let ri = state.ri
  let rg = state.rg
  let u = self.area / (3.6 * self.dt)
  let qs = cs * prev_qs + (1.0 - cs) * rs * u
  let qi = ci * prev_qi + (1.0 - ci) * ri * u
  let qg = cg * prev_qg + (1.0 - cg) * rg * u
  state.q = qs + qi + qg
  (qs, qi, qg)
}

///|
/// 单步仿真核心逻辑（私有）
fn XinanjiangModel::step_impl(
  self : XinanjiangModel,
  forcing : ForcingData,
  state : XinanjiangState,
) -> XinanjiangState {
  let p = forcing.rainfall
  let em = forcing.evaporation
  self.compute_evaporation(p, em, state)
  let pe = p - state.e
  let r = self.compute_runoff(pe, state)
  self.compute_source_split(r, state)
  // P1-1修复：使用state中保存的前一步汇流分量，而非0.0
  let (qs, qi, qg) = self.compute_routing(state, state.qs, state.qi, state.qg)
  state.qs = qs
  state.qi = qi
  state.qg = qg
  state
}

///|
/// 完整仿真核心逻辑（私有）
fn XinanjiangModel::run_impl(
  self : XinanjiangModel,
  forcings : Array[ForcingData],
) -> SimResult {
  let state = XinanjiangState::initial()
  let runoff_series : Array[Double] = []
  let state_series : Array[XinanjiangState] = []
  let mut prev_qs = 0.0
  let mut prev_qi = 0.0
  let mut prev_qg = 0.0
  for forcing in forcings {
    let p = forcing.rainfall
    let em = forcing.evaporation
    self.compute_evaporation(p, em, state)
    let pe = p - state.e
    let r = self.compute_runoff(pe, state)
    self.compute_source_split(r, state)
    let (qs, qi, qg) = self.compute_routing(state, prev_qs, prev_qi, prev_qg)
    prev_qs = qs
    prev_qi = qi
    prev_qg = qg
    runoff_series.push(state.q)
    state_series.push({
      w: state.w,
      wu: state.wu,
      wl: state.wl,
      wd: state.wd,
      s: state.s,
      r: state.r,
      rs: state.rs,
      ri: state.ri,
      rg: state.rg,
      e: state.e,
      q: state.q,
      qs: state.qs,
      qi: state.qi,
      qg: state.qg,
    })
  }
  // P2-1修复说明：nse/kge/pbias需要观测数据才能计算
  // 此处返回0.0作为占位符，调用方应通过evaluation模块计算指标
  { runoff_series, state_series, nse: 0.0, kge: 0.0, pbias: 0.0 }
}

///|
/// 单步仿真：输入气象驱动与当前状态，输出更新后状态
pub fn XinanjiangModel::step(
  self : XinanjiangModel,
  forcing : ForcingData,
  state : XinanjiangState,
) -> XinanjiangState {
  self.step_impl(forcing, state)
}

///|
/// 完整仿真：输入气象驱动序列，输出仿真结果
pub fn XinanjiangModel::run(
  self : XinanjiangModel,
  forcings : Array[ForcingData],
) -> SimResult {
  self.run_impl(forcings)
}

///|
/// 实现HydroModel trait：单步仿真
pub impl HydroModel for XinanjiangModel with fn step(self, forcing, state) {
  self.step_impl(forcing, state)
}

///|
/// 实现HydroModel trait：完整仿真
pub impl HydroModel for XinanjiangModel with fn run(self, forcings) {
  self.run_impl(forcings)
}
