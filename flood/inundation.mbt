///|
/// 洪水淹没推演模块
///
/// 基于2D浅水方程求解器 + GIS DEM，实现：
/// - 洪水淹没仿真（从DEM构造计算网格，设置入流/初始条件，运行2D SWE）
/// - 最大水深场计算
/// - 洪水到达时间分析
/// - 淹没持续时间分析
/// - 淹没范围提取
///
/// 注：P2-10：本模块与 shared.SWEGrid2D 存在紧耦合（直接访问h/hu/hv/z字段）。
/// 未来可考虑通过 trait 抽象 SWE 网格接口以降低耦合度。

///|
/// 淹没推演配置
pub(all) struct InundationConfig {
  dt : Double // 时间步长(s)
  n_steps : Int // 总时间步数
  cfl : Double // CFL安全系数
  depth_threshold : Double // 淹没水深阈值(m)，超过则视为淹没
} derive(Debug, ToJson, FromJson)

///|
/// 默认配置
pub fn InundationConfig::default() -> InundationConfig {
  { dt: 0.1, n_steps: 500, cfl: 0.5, depth_threshold: 0.05, }
}

///|
/// 淹没推演结果
pub(all) struct InundationResult {
  nx : Int // 网格列数
  ny : Int // 网格行数
  dx : Double // x方向分辨率
  dy : Double // y方向分辨率
  max_depth : Array[Double] // 各单元最大水深(m)
  final_depth : Array[Double] // 最终水深场(m)
  hu_final : Array[Double] // 最终x方向流量(m²/s)
  hv_final : Array[Double] // 最终y方向流量(m²/s)
  arrival_time : Array[Double] // 洪水到达时间(s)，-1表示未到达
  inundation_duration : Array[Double] // 淹没持续时间(s)
  stable : Bool // 数值稳定性
  n_steps_actual : Int // 实际执行步数
  total_inundated_cells : Int // 淹没单元总数
  inundated_area : Double // 淹没面积(km²)
} derive(Debug, ToJson, FromJson)

///|
/// 从DEM构造2D SWE计算网格
///
/// 将GIS的DEMGrid转换为SWE的SWEGrid2D，高程作为河底高程
pub fn dem_to_swe_grid(
  dem : @gis.DEMGrid,
  h0? : Double = 0.0,
  manning? : Double = 0.03,
) -> @shared.SWEGrid2D {
  let n_total = dem.nx * dem.ny
  let h = Array::make(n_total, h0)
  let hu = Array::make(n_total, 0.0)
  let hv = Array::make(n_total, 0.0)
  // SWEGrid2D uses idx2d(x_idx, y_idx) = x_idx * ny + y_idx
  // DEMGrid uses elevations[row][col] = elevations[y_idx][x_idx]
  // Must fill z[x_idx * ny + y_idx] = dem.elevations[y_idx][x_idx]
  let z = Array::make(n_total, 0.0)
  let n_arr = Array::make(n_total, manning)
  for x_idx in 0..<dem.nx {
    for y_idx in 0..<dem.ny {
      z[x_idx * dem.ny + y_idx] = dem.elevations[y_idx][x_idx]
    }
  }
  {
    nx: dem.nx,
    ny: dem.ny,
    dx: dem.dx,
    dy: dem.dy,
    h,
    hu,
    hv,
    z,
    n_manning: n_arr,
  }
}

///|
/// 设置入流边界条件（在指定区域注入水流）
///
/// 在网格的指定行/列范围内设置水深和流速
pub fn set_inflow(
  grid : @shared.SWEGrid2D,
  i0~ : Int,
  i1~ : Int,
  j0~ : Int,
  j1~ : Int,
  h_value~ : Double,
  u_velocity? : Double = 1.0,
  v_velocity? : Double = 0.0,
) -> @shared.SWEGrid2D {
  let ny = grid.ny
  for i in i0..<i1 {
    for j in j0..<j1 {
      if i >= 0 && i < grid.nx && j >= 0 && j < ny {
        let k = i * ny + j
        grid.h[k] = h_value
        grid.hu[k] = h_value * u_velocity
        grid.hv[k] = h_value * v_velocity
      }
    }
  }
  grid
}

///|
/// 运行洪水淹没仿真
///
/// 从给定初始网格出发，运行2D SWE求解器，记录：
/// - 各单元最大水深
/// - 洪水到达时间（首次超过阈值的时间）
/// - 淹没持续时间（末次超过阈值 - 首次超过阈值）
pub fn simulate_inundation(
  grid : @shared.SWEGrid2D,
  config : InundationConfig,
) -> InundationResult {
  let nx = grid.nx
  let ny = grid.ny
  let dx = grid.dx
  let dy = grid.dy
  let n_total = nx * ny
  let max_depth = Array::make(n_total, 0.0)
  let arrival_time = Array::make(n_total, -1.0)
  let wet_duration = Array::make(n_total, 0.0)
  let mut current_grid = grid
  let mut stable = true
  let mut steps_done = 0
  let mut current_time = 0.0
  let g = 9.81
  for step in 0..<config.n_steps {
    // CFL自适应时间步长
    let mut max_speed = 0.0
    for k in 0..<n_total {
      let h = current_grid.h[k]
      if h > 0.0 {
        let c = @math.pow(g * h, 0.5)
        let u = current_grid.hu[k] / h
        let v = current_grid.hv[k] / h
        let speed = @math.pow(u * u + v * v, 0.5) + c
        if speed > max_speed {
          max_speed = speed
        }
      }
    }
    let dt_eff = if max_speed > 0.0 {
      let dt_cfl_x = config.cfl * dx / max_speed
      let dt_cfl_y = config.cfl * dy / max_speed
      let dt_cfl = if dt_cfl_x < dt_cfl_y { dt_cfl_x } else { dt_cfl_y }
      if dt_cfl < config.dt {
        dt_cfl
      } else {
        config.dt
      }
    } else {
      config.dt
    }
    // 记录最大水深和到达时间
    for k in 0..<n_total {
      let h = current_grid.h[k]
      if h > max_depth[k] {
        max_depth[k] = h
      }
      if h > config.depth_threshold {
        if arrival_time[k] < 0.0 {
          arrival_time[k] = current_time
        }
        // T45修复：累计实际淹没时间，不包含干旱间隙
        wet_duration[k] = wet_duration[k] + dt_eff
      }
      // 稳定性检查
      if h < -0.001 || h > 1000000.0 {
        stable = false
      }
    }
    if !stable {
      break
    }
    // 推进
    let boundary = @shared.SWE2DBoundary::Transmissive
    current_grid = current_grid.step_lf(dt_eff, boundary)
    current_time = current_time + dt_eff
    steps_done = step + 1
  }
  // 最终水深记录
  for k in 0..<n_total {
    let h = current_grid.h[k]
    if h > max_depth[k] {
      max_depth[k] = h
    }
    // 终态到达时间记录：若末步推演后首次超过阈值，补记arrival_time
    if h > config.depth_threshold && arrival_time[k] < 0.0 {
      arrival_time[k] = current_time
    }
  }
  // 计算淹没持续时间和淹没单元数
  let inundation_duration = Array::make(n_total, 0.0)
  let mut inundated_count = 0
  for k in 0..<n_total {
    if arrival_time[k] >= 0.0 {
      inundation_duration[k] = wet_duration[k]
      if max_depth[k] > config.depth_threshold {
        inundated_count = inundated_count + 1
      }
    }
  }
  let cell_area = dx * dy
  let inundated_area = inundated_count.to_double() * cell_area / 1000000.0
  {
    nx,
    ny,
    dx,
    dy,
    max_depth,
    final_depth: current_grid.h,
    hu_final: current_grid.hu,
    hv_final: current_grid.hv,
    arrival_time,
    inundation_duration,
    stable,
    n_steps_actual: steps_done,
    total_inundated_cells: inundated_count,
    inundated_area,
  }
}

///|
/// 提取淹没范围（水深超过阈值的单元坐标）
pub fn extract_inundation_extent(
  result : InundationResult,
  threshold? : Double = 0.05,
) -> Array[(Int, Int)] {
  let extent : Array[(Int, Int)] = []
  for i in 0..<result.nx {
    for j in 0..<result.ny {
      let k = i * result.ny + j
      if result.max_depth[k] > threshold {
        extent.push((i, j))
      }
    }
  }
  extent
}

///|
/// 计算淹没统计信息
pub fn inundation_stats(
  result : InundationResult,
  threshold? : Double = 0.05,
) -> (Int, Double, Double, Double) {
  let mut max_h = 0.0
  let mut sum_h = 0.0
  let mut count = 0
  for k in 0..<result.max_depth.length() {
    if result.max_depth[k] > threshold {
      sum_h = sum_h + result.max_depth[k]
      if result.max_depth[k] > max_h {
        max_h = result.max_depth[k]
      }
      count = count + 1
    }
  }
  let mean_h = if count > 0 { sum_h / count.to_double() } else { 0.0 }
  (count, result.inundated_area, max_h, mean_h)
}

///|
/// 生成合成淹没场景（演示用）
///
/// 构造一个带坡度的DEM + 上游入流条件
pub fn synthetic_flood_scenario(
  nx? : Int = 50,
  ny? : Int = 40,
  dx? : Double = 50.0,
  dy? : Double = 50.0,
) -> (@shared.SWEGrid2D, InundationConfig) {
  // 构造DEM：从西北向东南倾斜的地形
  let dem = @gis.synthetic_dem(nx~, ny~, dx~, dy~)
  // 转换为SWE网格（初始无水）
  let grid = dem_to_swe_grid(dem, h0=0.0, manning=0.035)
  // 在上游（西北角）设置入流
  let inflow_grid = set_inflow(
    grid,
    i0=0,
    i1=3,
    j0=0,
    j1=ny / 2,
    h_value=2.0,
    u_velocity=1.5,
    v_velocity=0.5,
  )
  let config : InundationConfig = {
    dt: 0.05,
    n_steps: 300,
    cfl: 0.4,
    depth_threshold: 0.05,
  }
  (inflow_grid, config)
}
