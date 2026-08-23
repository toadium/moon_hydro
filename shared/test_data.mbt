///|
/// 生产级测试数据生成模块（Mock + Dummy）
///
/// 提供典型水文测试场景的模拟数据生成：
/// - 暴雨洪水、干旱退水、dam-break、潮波
/// - 随机参数生成（基于Arbitrary/splitmix）
/// - 生产级流域参数配置

///|
/// 测试场景类型
pub(all) enum TestScenario {
  FloodEvent // 暴雨洪水
  DryPeriod // 干旱退水
  DamBreak // 水坝溃决
  TidalWave // 潮波演进
  MultiPeakFlood // 多峰洪水
  LongTermSimulation // 长期仿真
} derive(Debug, ToJson, FromJson, Eq)

///|
/// 流域特征配置（生产级参数）
pub(all) struct BasinProfile {
  name : String // 流域名称
  area : Double // 流域面积(km²)
  mean_slope : Double // 平均坡度
  river_length : Double // 河道长度(km)
  roughness : Double // 河道糙率
  design_rainfall : Double // 设计降雨量(mm)
  dt : Double // 计算时段(h)
} derive(Debug, ToJson, FromJson, Default)

///|
/// 构造典型流域配置
pub fn BasinProfile::small_basin() -> BasinProfile {
  {
    name: "小型流域",
    area: 50.0,
    mean_slope: 0.01,
    river_length: 10.0,
    roughness: 0.035,
    design_rainfall: 80.0,
    dt: 1.0,
  }
}

///|
/// 构造中型流域配置
pub fn BasinProfile::medium_basin() -> BasinProfile {
  {
    name: "中型流域",
    area: 500.0,
    mean_slope: 0.005,
    river_length: 50.0,
    roughness: 0.03,
    design_rainfall: 120.0,
    dt: 1.0,
  }
}

///|
/// 构造大型流域配置
pub fn BasinProfile::large_basin() -> BasinProfile {
  {
    name: "大型流域",
    area: 2000.0,
    mean_slope: 0.002,
    river_length: 200.0,
    roughness: 0.025,
    design_rainfall: 150.0,
    dt: 3.0,
  }
}

// ============ Mock气象驱动数据生成 ============

///|
/// 生成暴雨事件气象驱动序列
///
/// 模拟单峰暴雨：快速上升到峰值后缓慢衰减
/// duration: 降雨持续时段数
/// peak_rainfall: 峰值降雨量(mm)
/// evaporation: 蒸发量(mm)
pub fn mock_flood_rainfall(
  duration~ : Int,
  peak_rainfall? : Double = 50.0,
  evaporation? : Double = 2.0,
) -> Array[ForcingData] {
  let forcings : Array[ForcingData] = []
  let peak_time = duration / 2
  for t in 0..<duration {
    // 三角形暴雨过程：线性上升到峰值后线性下降
    // P1-4修复：peak_time=0或duration-peak_time=0时除零保护
    let rainfall = if duration <= 1 {
      peak_rainfall
    } else if t <= peak_time {
      if peak_time > 0 {
        peak_rainfall * t.to_double() / peak_time.to_double()
      } else {
        0.0
      }
    } else {
      let denom = duration - peak_time
      if denom > 0 {
        peak_rainfall * (duration - t).to_double() / denom.to_double()
      } else {
        0.0
      }
    }
    forcings.push({
      rainfall: if rainfall < 0.0 {
        0.0
      } else {
        rainfall
      },
      evaporation,
      datetime: "t\{t}",
    })
  }
  forcings
}

///|
/// 生成多峰洪水气象驱动序列
///
/// 模拟多场连续暴雨，每场之间有间歇
/// n_peaks: 暴雨场次
/// peak_interval: 场次间隔时段数
/// peak_duration: 每场暴雨持续时段数
pub fn mock_multi_peak_rainfall(
  n_peaks~ : Int,
  peak_interval? : Int = 5,
  peak_duration? : Int = 4,
  peak_rainfall? : Double = 40.0,
) -> Array[ForcingData] {
  let forcings : Array[ForcingData] = []
  for peak in 0..<n_peaks {
    // 每场暴雨
    for t in 0..<peak_duration {
      let rainfall = peak_rainfall *
        (1.0 - (2.0 * t.to_double() / peak_duration.to_double() - 1.0).abs())
      forcings.push({
        rainfall: if rainfall < 0.0 {
          0.0
        } else {
          rainfall
        },
        evaporation: 1.5,
        datetime: "peak\{peak}_t\{t}",
      })
    }
    // 间歇期
    for _ in 0..<peak_interval {
      forcings.push({ rainfall: 0.0, evaporation: 2.0, datetime: "gap\{peak}" })
    }
  }
  forcings
}

///|
/// 生成干旱退水气象驱动序列
///
/// 前期有少量降雨，后期无雨纯退水
pub fn mock_dry_period(
  duration~ : Int,
  initial_rainfall? : Double = 10.0,
  wet_days? : Int = 3,
) -> Array[ForcingData] {
  let forcings : Array[ForcingData] = []
  for t in 0..<duration {
    let rainfall = if t < wet_days { initial_rainfall } else { 0.0 }
    forcings.push({ rainfall, evaporation: 3.0, datetime: "dry_t\{t}" })
  }
  forcings
}

///|
/// 生成长期仿真气象驱动序列（随机+季节性）
///
/// 基于splitmix随机数生成器，模拟长期气象过程
/// n_days: 仿真天数
/// seed: 随机种子
pub fn mock_long_term_forcings(
  n_days~ : Int,
  seed? : UInt64 = 42,
) -> Array[ForcingData] {
  let rng = @splitmix.new(seed~)
  let forcings : Array[ForcingData] = []
  for day in 0..<n_days {
    // 季节性降雨模式：夏季多雨，冬季少雨
    let seasonal_factor = 0.5 +
      0.5 * @math.cos(2.0 * @math.PI * day.to_double() / 365.0)
    let base_rainfall = 20.0 * seasonal_factor
    // 随机扰动
    let noise = rng.next_double() * 10.0
    let rainfall = if base_rainfall + noise > 0.0 {
      base_rainfall + noise
    } else {
      0.0
    }
    let evaporation = 2.0 + rng.next_double() * 2.0
    forcings.push({ rainfall, evaporation, datetime: "day\{day}" })
  }
  forcings
}

// ============ Mock新安江参数生成 ============

///|
/// 生成随机新安江参数（基于splitmix）
///
/// 在合理范围内随机生成参数，用于率定测试
pub fn mock_xaj_params(seed? : UInt64 = 123) -> XinanjiangParams {
  let rng = @splitmix.new(seed~)
  let base = XinanjiangParams::default()
  {
    wm: 80.0 + rng.next_double() * 80.0,
    wum: base.wum,
    wlm: base.wlm,
    wdm: base.wdm,
    b: 0.2 + rng.next_double() * 0.4,
    im: rng.next_double() * 0.05,
    c: 0.5 + rng.next_double() * 0.5,
    sm: 10.0 + rng.next_double() * 30.0,
    ex: 1.0 + rng.next_double() * 1.5,
    kg: 0.2 + rng.next_double() * 0.3,
    ki: 0.2 + rng.next_double() * 0.3,
    cg: 0.9 + rng.next_double() * 0.09,
    ci: 0.5 + rng.next_double() * 0.3,
    cs: 0.1 + rng.next_double() * 0.3,
    ke: base.ke,
    x: base.x,
    y: base.y,
    n: base.n,
    l: base.l,
    fr: base.fr,
    kg1: base.kg1,
    ki1: base.ki1,
    kg2: base.kg2,
    ki2: base.ki2,
    t0: base.t0,
    t1: base.t1,
    td: base.td,
    u0: base.u0,
    u1: base.u1,
    u2: base.u2,
  }
}

///|
/// 生成极端工况新安江参数（高产流率）
pub fn mock_extreme_flood_params() -> XinanjiangParams {
  let base = XinanjiangParams::default()
  {
    wm: 80.0,
    wum: base.wum,
    wlm: base.wlm,
    wdm: base.wdm,
    b: 0.4,
    im: 0.02,
    c: base.c,
    sm: 15.0,
    ex: base.ex,
    kg: 0.45,
    ki: 0.4,
    cg: base.cg,
    ci: base.ci,
    cs: 0.1,
    ke: base.ke,
    x: base.x,
    y: base.y,
    n: base.n,
    l: base.l,
    fr: base.fr,
    kg1: base.kg1,
    ki1: base.ki1,
    kg2: base.kg2,
    ki2: base.ki2,
    t0: base.t0,
    t1: base.t1,
    td: base.td,
    u0: base.u0,
    u1: base.u1,
    u2: base.u2,
  }
}

// ============ Mock SWE网格生成 ============

///|
/// 生成dam-break初始SWE网格
///
/// 左侧高水位、右侧低水位，经典溃坝测试
pub fn mock_dam_break_grid(
  nx? : Int = 100,
  dx? : Double = 1.0,
  h_left? : Double = 4.0,
  h_right? : Double = 1.0,
) -> SWEGrid1D {
  let grid = SWEGrid1D::uniform(nx~, dx~, h0=0.0)
  for i in 0..<nx {
    if i < nx / 2 {
      grid.h[i] = h_left
    } else {
      grid.h[i] = h_right
    }
  }
  grid
}

///|
/// 生成带底坡的河道SWE网格
///
/// 线性递减底坡，模拟自然河道
pub fn mock_sloped_river_grid(
  nx? : Int = 50,
  dx? : Double = 1.0,
  h0? : Double = 1.0,
  slope? : Double = 0.001,
  n_manning? : Double = 0.03,
) -> SWEGrid1D {
  let grid = SWEGrid1D::uniform(nx~, dx~, h0~, z0=0.0, n0=n_manning)
  for i in 0..<nx {
    grid.z[i] = (nx - i).to_double() * slope * dx
  }
  grid
}

///|
/// 生成潮波初始SWE网格
///
/// 正弦波形水深分布，模拟潮波传入
pub fn mock_tidal_wave_grid(
  nx? : Int = 100,
  dx? : Double = 1.0,
  h_mean? : Double = 2.0,
  amplitude? : Double = 0.5,
  wavelength? : Double = 20.0,
) -> SWEGrid1D {
  let grid = SWEGrid1D::uniform(nx~, dx~, h0=h_mean)
  for i in 0..<nx {
    let phase = 2.0 * @math.PI * i.to_double() / wavelength
    grid.h[i] = h_mean + amplitude * @math.sin(phase)
  }
  grid
}

// ============ Mock耦合参数生成 ============

///|
/// 生成典型耦合参数配置
///
/// basin: 流域特征
/// swe_nx: SWE网格单元数
pub fn mock_coupling_params(
  basin~ : BasinProfile,
  swe_nx? : Int = 50,
) -> CouplingParams {
  // 河道单元位于网格中间段
  let river_start = swe_nx / 3
  let river_end = swe_nx * 2 / 3
  let river_cells : Array[Int] = []
  for i in river_start..<river_end {
    river_cells.push(i)
  }
  {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: basin.area,
    river_cells,
    base_flow_threshold: 0.3,
  }
}

///|
/// 生成完整测试场景包
///
/// 根据场景类型生成对应的全部测试数据
pub fn mock_scenario(
  scenario~ : TestScenario,
  basin? : BasinProfile = BasinProfile::medium_basin(),
) -> (
  XinanjiangModel,
  Array[ForcingData],
  SWEGrid1D,
  CouplingParams,
  SWEBoundary,
) {
  let xaj_model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=basin.area,
    dt=basin.dt,
  )
  let swe_nx = 50
  let coupling_params = mock_coupling_params(basin~, swe_nx~)
  let boundary : SWEBoundary = { left: SolidWall, right: Transmissive }
  match scenario {
    FloodEvent => {
      let forcings = mock_flood_rainfall(
        duration=10,
        peak_rainfall=basin.design_rainfall,
      )
      let swe_grid = SWEGrid1D::uniform(nx=swe_nx, dx=1.0, h0=0.5)
      (xaj_model, forcings, swe_grid, coupling_params, boundary)
    }
    DryPeriod => {
      let forcings = mock_dry_period(
        duration=20,
        initial_rainfall=5.0,
        wet_days=3,
      )
      let swe_grid = SWEGrid1D::uniform(nx=swe_nx, dx=1.0, h0=1.0)
      (xaj_model, forcings, swe_grid, coupling_params, boundary)
    }
    DamBreak => {
      let forcings = mock_flood_rainfall(duration=5, peak_rainfall=20.0)
      let swe_grid = mock_dam_break_grid(nx=swe_nx, dx=1.0)
      (xaj_model, forcings, swe_grid, coupling_params, boundary)
    }
    TidalWave => {
      let forcings = mock_flood_rainfall(duration=15, peak_rainfall=30.0)
      let swe_grid = mock_tidal_wave_grid(nx=swe_nx, dx=1.0)
      (xaj_model, forcings, swe_grid, coupling_params, boundary)
    }
    MultiPeakFlood => {
      let forcings = mock_multi_peak_rainfall(
        n_peaks=3,
        peak_interval=5,
        peak_duration=4,
      )
      let swe_grid = SWEGrid1D::uniform(nx=swe_nx, dx=1.0, h0=0.5)
      (xaj_model, forcings, swe_grid, coupling_params, boundary)
    }
    LongTermSimulation => {
      let forcings = mock_long_term_forcings(n_days=30)
      let swe_grid = mock_sloped_river_grid(nx=swe_nx, dx=1.0)
      (xaj_model, forcings, swe_grid, coupling_params, boundary)
    }
  }
}
