///|
/// 模型双向耦合模块
///
/// 新安江各单元产流量 → 河道侧向通量边界（正向耦合）
/// 河道水位 → 流域地下径流储量反馈调整（反向耦合）
///
/// 耦合接口：couple_step(xaj_model, swe_grid, params, forcing) -> (XinanjiangState, SWEGrid1D)

///|
/// 耦合参数配置
pub(all) struct CouplingParams {
  lateral_inflow_coeff : Double // 侧向入流系数（产流量→侧向入流转换）
  feedback_coeff : Double // 反馈系数（河道水位→地下水储量调整）
  cell_area : Double // 新安江单元面积(km²)
  river_cells : Array[Int] // SWE网格中河道对应单元索引
  base_flow_threshold : Double // 基流阈值(m³/s)，低于此值不反馈
  n_river_cells : Int // 河道单元总数
} derive(Debug, ToJson, Default)

///|
/// 耦合仿真结果
pub(all) struct CouplingResult {
  xaj_states : Array[XinanjiangState] // 新安江状态序列
  swe_h_series : Array[Array[Double]] // SWE水深场序列
  swe_hu_series : Array[Array[Double]] // SWE单宽流量场序列
  lateral_inflow_series : Array[Double] // 侧向入流过程
  water_level_series : Array[Double] // 河道平均水位过程
  stable : Bool // 耦合稳定性标记
} derive(Debug, ToJson)

///|
/// 构造默认耦合参数
pub fn CouplingParams::default() -> CouplingParams {
  {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [],
    base_flow_threshold: 0.5,
    n_river_cells: 0,
  }
}

///|
/// 计算新安江产流量到河道侧向入流的转换
///
/// Q_lateral = coeff * (rs + ri + rg) * cell_area / 3.6
/// 单位：mm * km² / 3.6 = m³/s
fn compute_lateral_inflow(
  xaj_state : XinanjiangState,
  params : CouplingParams,
) -> Double {
  let total_runoff = xaj_state.rs + xaj_state.ri + xaj_state.rg
  params.lateral_inflow_coeff * total_runoff * params.cell_area / 3.6
}

///|
/// 计算河道水位对新安江地下径流的反馈
///
/// 当河道水位高于阈值时，增加地下水储量；低于时减少
fn compute_water_level_feedback(
  swe_grid : SWEGrid1D,
  params : CouplingParams,
) -> Double {
  if params.river_cells.length() == 0 {
    return 0.0
  }
  // 计算河道平均水深
  let mut total_depth = 0.0
  let mut count = 0
  for cell_idx in params.river_cells {
    if cell_idx >= 0 && cell_idx < swe_grid.nx {
      total_depth = total_depth + swe_grid.h[cell_idx]
      count = count + 1
    }
  }
  if count == 0 {
    return 0.0
  }
  let avg_depth = total_depth / count.to_double()
  // 反馈量 = feedback_coeff * (avg_depth - threshold)
  params.feedback_coeff * (avg_depth - params.base_flow_threshold)
}

///|
/// 将侧向入流注入SWE网格
///
/// 在河道单元上均匀分配侧向入流，增加水深
fn inject_lateral_inflow(
  swe_grid : SWEGrid1D,
  lateral_inflow : Double,
  params : CouplingParams,
  dt : Double,
) -> Unit {
  if params.river_cells.length() == 0 {
    return
  }
  // 将侧向入流均匀分配到各河道单元
  let n_cells = params.river_cells.length().to_double()
  let inflow_per_cell = lateral_inflow / n_cells
  // 转换为水深增量：dh = Q * dt / (cell_width * cell_length)
  // 简化：dh = inflow_per_cell * dt / (dx * 1.0) （假设单元宽度1m）
  let dh = inflow_per_cell * dt / swe_grid.dx
  for cell_idx in params.river_cells {
    if cell_idx >= 0 && cell_idx < swe_grid.nx {
      swe_grid.h[cell_idx] = swe_grid.h[cell_idx] + dh
      if swe_grid.h[cell_idx] < 0.0 {
        swe_grid.h[cell_idx] = 0.0
      }
    }
  }
}

///|
/// 应用河道水位反馈到新安江状态
///
/// 调整深层张力水蓄量wd和自由水蓄量s
fn apply_water_level_feedback(
  xaj_state : XinanjiangState,
  feedback : Double,
) -> Unit {
  // 正反馈（河道水深大）：增加地下水储量
  // 负反馈（河道水深小）：减少地下水储量
  xaj_state.wd = xaj_state.wd + feedback
  if xaj_state.wd < 0.0 {
    xaj_state.wd = 0.0
  }
  xaj_state.s = xaj_state.s + feedback * 0.5
  if xaj_state.s < 0.0 {
    xaj_state.s = 0.0
  }
  // 更新总张力水蓄量
  xaj_state.w = xaj_state.wu + xaj_state.wl + xaj_state.wd
}

///|
/// 单步耦合仿真
///
/// 1. 新安江模型单步仿真 → 产流量
/// 2. 产流量 → 侧向入流 → 注入SWE网格
/// 3. SWE模型单步推进
/// 4. SWE河道水位 → 反馈新安江地下水储量
/// 返回更新后的新安江状态和SWE网格
pub fn couple_step(
  xaj_model : XinanjiangModel,
  swe_grid : SWEGrid1D,
  coupling_params : CouplingParams,
  swe_boundary : SWEBoundary,
  forcing : ForcingData,
  xaj_state : XinanjiangState,
  swe_dt : Double,
) -> (XinanjiangState, SWEGrid1D, Double, Double) {
  // 1. 新安江单步仿真
  let new_xaj_state = xaj_model.step(forcing, xaj_state)
  // 2. 计算侧向入流
  let lateral_inflow = compute_lateral_inflow(new_xaj_state, coupling_params)
  // 3. 注入侧向入流到SWE网格
  inject_lateral_inflow(swe_grid, lateral_inflow, coupling_params, swe_dt)
  // 4. SWE单步推进
  let new_swe_grid = swe_grid.step_lf(swe_dt, swe_boundary)
  // 5. 计算河道水位反馈
  let feedback = compute_water_level_feedback(new_swe_grid, coupling_params)
  apply_water_level_feedback(new_xaj_state, feedback)
  // 返回（新安江状态, SWE网格, 侧向入流, 河道平均水位）
  let river_level = if coupling_params.river_cells.length() > 0 {
    let mut total = 0.0
    let mut cnt = 0
    for idx in coupling_params.river_cells {
      if idx >= 0 && idx < new_swe_grid.nx {
        total = total + new_swe_grid.h[idx]
        cnt = cnt + 1
      }
    }
    if cnt > 0 {
      total / cnt.to_double()
    } else {
      0.0
    }
  } else {
    0.0
  }
  (new_xaj_state, new_swe_grid, lateral_inflow, river_level)
}

///|
/// 完整耦合仿真
///
/// 给定新安江模型、SWE网格、耦合参数和气象驱动序列，
/// 运行完整耦合仿真，返回耦合结果
pub fn couple_run(
  xaj_model : XinanjiangModel,
  swe_grid : SWEGrid1D,
  coupling_params : CouplingParams,
  swe_boundary : SWEBoundary,
  forcings : Array[ForcingData],
  swe_dt : Double,
) -> CouplingResult {
  let xaj_state = XinanjiangState::initial()
  let xaj_states : Array[XinanjiangState] = []
  let swe_h_series : Array[Array[Double]] = []
  let swe_hu_series : Array[Array[Double]] = []
  let lateral_inflow_series : Array[Double] = []
  let water_level_buf : Array[Double] = []
  let mut current_swe = swe_grid
  let mut stable = true
  for forcing in forcings {
    let (new_xaj, new_swe, lateral_inflow, river_level) = couple_step(
      xaj_model, current_swe, coupling_params, swe_boundary, forcing, xaj_state,
      swe_dt,
    )
    // 记算CFL自适应步长已在SWE内部处理
    // 记录状态
    xaj_states.push({
      w: new_xaj.w,
      wu: new_xaj.wu,
      wl: new_xaj.wl,
      wd: new_xaj.wd,
      s: new_xaj.s,
      r: new_xaj.r,
      rs: new_xaj.rs,
      ri: new_xaj.ri,
      rg: new_xaj.rg,
      e: new_xaj.e,
      q: new_xaj.q,
    })
    let h_copy = Array::make(new_swe.nx, 0.0)
    let hu_copy = Array::make(new_swe.nx, 0.0)
    for i in 0..<new_swe.nx {
      h_copy[i] = new_swe.h[i]
      hu_copy[i] = new_swe.hu[i]
      // 稳定性检测
      if new_swe.h[i] < -0.001 || new_swe.h[i] > 1000000.0 {
        stable = false
      }
    }
    swe_h_series.push(h_copy)
    swe_hu_series.push(hu_copy)
    lateral_inflow_series.push(lateral_inflow)
    water_level_buf.push(river_level)
    // 更新状态供下一步使用
    xaj_state.w = new_xaj.w
    xaj_state.wu = new_xaj.wu
    xaj_state.wl = new_xaj.wl
    xaj_state.wd = new_xaj.wd
    xaj_state.s = new_xaj.s
    xaj_state.r = new_xaj.r
    xaj_state.rs = new_xaj.rs
    xaj_state.ri = new_xaj.ri
    xaj_state.rg = new_xaj.rg
    xaj_state.e = new_xaj.e
    xaj_state.q = new_xaj.q
    current_swe = new_swe
  }
  {
    xaj_states,
    swe_h_series,
    swe_hu_series,
    lateral_inflow_series,
    water_level_series: water_level_buf,
    stable,
  }
}
