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
} derive(Debug, ToJson, FromJson, Default)

///|
/// 耦合仿真结果
pub(all) struct CouplingResult {
  xaj_states : Array[XinanjiangState] // 新安江状态序列
  swe_h_series : Array[Array[Double]] // SWE水深场序列
  swe_hu_series : Array[Array[Double]] // SWE单宽流量场序列
  lateral_inflow_series : Array[Double] // 侧向入流过程
  water_level_series : Array[Double] // 河道平均水位过程
  stable : Bool // 耦合稳定性标记
} derive(Debug, ToJson, FromJson)

///|
/// 构造默认耦合参数
pub fn CouplingParams::default() -> CouplingParams {
  {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [],
    base_flow_threshold: 0.5,
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
  dt : Double,
) -> Double {
  let total_runoff = xaj_state.rs + xaj_state.ri + xaj_state.rg
  let dt_safe = if dt > 0.0 { dt } else { 1.0 }
  params.lateral_inflow_coeff * total_runoff * params.cell_area / (3.6 * dt_safe)
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
  xaj_model : XinanjiangModel,
  xaj_state : XinanjiangState,
  feedback : Double,
) -> Unit {
  // feedback单位为m（SWE水深），wd/s单位为mm，需转换
  let feedback_mm = feedback * 1000.0
  let params = xaj_model.params
  xaj_state.wd = xaj_state.wd + feedback_mm
  if xaj_state.wd < 0.0 {
    xaj_state.wd = 0.0
  } else if xaj_state.wd > params.wdm {
    // 钳制到深层张力水上限，防止反馈正失控
    xaj_state.wd = params.wdm
  }
  xaj_state.s = xaj_state.s + feedback_mm * 0.5
  if xaj_state.s < 0.0 {
    xaj_state.s = 0.0
  } else if xaj_state.s > params.sm {
    // 钳制到自由水蓄水容量上限，防止ri/rg随s_total失控放大
    xaj_state.s = params.sm
  }
  xaj_state.w = xaj_state.wu + xaj_state.wl + xaj_state.wd
  if xaj_state.w > params.wm {
    xaj_state.w = params.wm
  }
}

///|
/// 单步耦合仿真
///
/// 1. 新安江模型单步仿真 → 产流量
/// 2. 产流量 → 侧向入流 → 注入SWE网格
/// 3. SWE模型单步推进
/// 4. SWE河道水位 → 反馈新安江地下水储量
/// 返回更新后的新安江状态和SWE网格
/// P2-8说明：swe_dt为固定步长，未做CFL自适应检查
/// P3-7说明：返回四元组(XinanjiangState, SWEGrid1D, Double, Double)可读性较差
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
  let lateral_inflow = compute_lateral_inflow(new_xaj_state, coupling_params, xaj_model.dt)
  // 3. 复制SWE网格避免就地修改入参
  let h_copy = Array::make(swe_grid.nx, 0.0)
  let hu_copy = Array::make(swe_grid.nx, 0.0)
  for i in 0..<swe_grid.nx {
    h_copy[i] = swe_grid.h[i]
    hu_copy[i] = swe_grid.hu[i]
  }
  let swe_work = { ..swe_grid, h: h_copy, hu: hu_copy }
  // 4-5. SWE子步循环推进（XAJ dt单位小时，SWE dt单位秒）
  //      每个子步注入该子步对应的侧向入流量，保证时段内水量连续补给
  let n_substeps = if swe_dt <= 0.0 {
    1
  } else {
    let n = (xaj_model.dt * 3600.0 / swe_dt).to_int()
    if n < 1 {
      1
    } else {
      n
    }
  }
  let mut current_swe = swe_work
  for _ in 0..<n_substeps {
    inject_lateral_inflow(current_swe, lateral_inflow, coupling_params, swe_dt)
    current_swe = current_swe.step_lf(swe_dt, swe_boundary)
  }
  let new_swe_grid = current_swe
  // 6. 计算河道水位反馈
  let feedback = compute_water_level_feedback(new_swe_grid, coupling_params)
  apply_water_level_feedback(xaj_model, new_xaj_state, feedback)
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
      qs: new_xaj.qs,
      qi: new_xaj.qi,
      qg: new_xaj.qg,
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
