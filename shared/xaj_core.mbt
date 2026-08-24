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
  // P2-3修复：负蒸发能力保护，em < 0 时用极小值避免除零
  let em_safe = if em < 0.0000000001 { 0.0000000001 } else { em }
  let wl_over_wlm = if wlm <= 0.0 { 0.0 } else { wl / wlm }
  if p + wu >= em_safe {
    eu = em_safe
    el = 0.0
    ed = 0.0
  } else if p + wu >= c * em_safe {
    eu = p + wu
    el = (em_safe - eu) * wl_over_wlm
    ed = 0.0
  } else {
    eu = p + wu
    if wl >= c * (em_safe - eu) {
      el = c * (em_safe - eu) * wl_over_wlm
      ed = 0.0
    } else {
      el = wl
      ed = c * (em_safe - eu) - el
      if ed < 0.0 {
        ed = 0.0
      }
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
) -> (Double, Double) {
  let params = self.params
  let wm = params.wm
  let b = params.b
  let im = params.im
  let w = state.w
  let pe_eff = if pe > 0.0 { pe } else { 0.0 }
  if wm <= 0.0 {
    let r0 = pe_eff
    state.w = 0.0
    state.r = r0
    return (r0, im * pe_eff)
  }
  let w_safe = if w < 0.0 { 0.0 } else if w > wm { wm } else { w }
  // S2修复：compute_evaporation已将PE加入state.w，需还原产流前张力水参与公式
  let w_init_raw = w_safe - pe_eff
  let w_init = if w_init_raw < 0.0 {
    0.0
  } else if w_init_raw > wm {
    wm
  } else {
    w_init_raw
  }
  // P2-4修复：b <= -1 时除零保护
  let b_safe = if b <= -1.0 { 0.0 } else { b }
  let mm = wm * (1.0 + b_safe)
  let a = wm * (1.0 - @math.pow(1.0 - w_init / wm, 1.0 / (1.0 + b_safe)))
  let mut r = 0.0
  if pe <= 0.0 {
    r = 0.0
  } else if pe + a < mm {
    r = pe +
      w_init -
      wm +
      mm * (1.0 - @math.pow((pe + a) / mm, 1.0 / (1.0 + b_safe)))
  } else {
    r = pe + w_init - wm
  }
  if r < 0.0 {
    r = 0.0
  }
  let r_im = im * pe_eff
  let r_b = (1.0 - im) * r
  r = r_im + r_b
  state.w = w_safe - r
  if state.w < 0.0 {
    state.w = 0.0
  }
  if state.w > wm {
    state.w = wm
  }
  state.r = r
  (r, r_im)
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
    let s_total = s + r
    if sm > 0.0 {
      let s_safe = if s < 0.0 { 0.0 } else if s > sm { sm } else { s }
      // P1修复：ex <= -1 时除零保护，同 b_safe 模式
      let ex_safe = if ex <= -1.0 { 0.0 } else { ex }
      let mm_s = sm * (1.0 + ex_safe)
      let a_s = sm * (1.0 - @math.pow(1.0 - s_safe / sm, 1.0 / (1.0 + ex_safe)))
      if r + a_s >= mm_s {
        rs = s_total - sm
      } else {
        rs = r +
          s_safe -
          sm +
          mm_s * (1.0 - @math.pow((r + a_s) / mm_s, 1.0 / (1.0 + ex_safe)))
      }
      if rs > r {
        rs = r
      }
      if rs < 0.0 {
        rs = 0.0
      }
    } else {
      rs = if r > 0.0 { r } else { 0.0 }
    }
    ri = ki * s_total * fr
    rg = kg * s_total * fr
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
  let u = if self.dt <= 0.0 { 0.0 } else { self.area / (3.6 * self.dt) }
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
  // S3修复：不透水产流r_im直接进入地表径流，不经过自由水蓄量
  let (r, r_im) = self.compute_runoff(pe, state)
  self.compute_source_split(r - r_im, state)
  state.rs = state.rs + r_im
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
  for forcing in forcings {
    ignore(self.step_impl(forcing, state))
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
