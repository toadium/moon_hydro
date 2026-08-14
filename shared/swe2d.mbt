///|
/// 二维浅水方程求解内核
///
/// 2D Saint-Venant方程Lax-Friedrichs显式格式
/// 结构化网格 + 维度分裂通量计算
///
/// 浅水方程（2D）：
///   ∂h/∂t + ∂(hu)/∂x + ∂(hv)/∂y = 0
///   ∂(hu)/∂t + ∂(hu²+gh²/2)/∂x + ∂(huv)/∂y = -gh∂z/∂x - gSfx
///   ∂(hv)/∂t + ∂(huv)/∂x + ∂(hv²+gh²/2)/∂y = -gh∂z/∂y - gSfy

///|
/// 二维浅水方程网格状态
///
/// nx: x方向网格单元数
/// ny: y方向网格单元数
/// dx: x方向空间步长(m)
/// dy: y方向空间步长(m)
/// h: 各单元水深(m)，按行优先存储 h[i*ny+j]
/// hu: 各单元x方向单宽流量(m²/s)
/// hv: 各单元y方向单宽流量(m²/s)
/// z: 各单元河底高程(m)
/// n_manning: 各单元Manning糙率系数
pub(all) struct SWEGrid2D {
  nx : Int
  ny : Int
  dx : Double
  dy : Double
  h : Array[Double]
  hu : Array[Double]
  hv : Array[Double]
  z : Array[Double]
  n_manning : Array[Double]
} derive(Debug, ToJson, FromJson)

///|
/// 2D边界条件类型
pub(all) enum SWE2DBoundary {
  Transmissive // 透射边界
  SolidWall // 固壁边界
} derive(Debug, ToJson, FromJson, Eq)

///|
/// 2D SWE求解器配置
pub(all) struct SWE2DSolverConfig {
  dt : Double // 时间步长(s)
  n_steps : Int // 总时间步数
  cfl : Double // CFL安全系数
  boundary : SWE2DBoundary // 统一边界条件
} derive(Debug, ToJson, FromJson)

///|
/// 2D SWE仿真结果
pub(all) struct SWE2DResult {
  h_final : Array[Double] // 最终水深场
  hu_final : Array[Double] // 最终x方向流量
  hv_final : Array[Double] // 最终y方向流量
  max_depth : Array[Double] // 各单元最大水深
  stable : Bool // 数值稳定性
  n_steps_actual : Int // 实际执行步数
} derive(Debug, ToJson, FromJson)

///|
/// 构造均匀二维浅水网格
pub fn SWEGrid2D::uniform(
  nx~ : Int,
  ny~ : Int,
  dx~ : Double,
  dy~ : Double,
  h0~ : Double,
  z0? : Double = 0.0,
  n0? : Double = 0.03,
) -> SWEGrid2D {
  let n_total = nx * ny
  {
    nx,
    ny,
    dx,
    dy,
    h: Array::make(n_total, h0),
    hu: Array::make(n_total, 0.0),
    hv: Array::make(n_total, 0.0),
    z: Array::make(n_total, z0),
    n_manning: Array::make(n_total, n0),
  }
}

///|
/// 获取单元索引（行优先）
fn idx2d(i : Int, j : Int, ny : Int) -> Int {
  i * ny + j
}

///|
/// 2D通量计算：x方向通量 F = [hu, hu²+gh²/2, huv]
fn swe2d_flux_x(
  h : Double,
  hu : Double,
  hv : Double,
) -> (Double, Double, Double) {
  if h <= 0.0 {
    return (0.0, 0.0, 0.0)
  }
  let u = hu / h
  let v = hv / h
  (hu, hu * u + 0.5 * g_gravity * h * h, hu * v)
}

///|
/// 2D通量计算：y方向通量 G = [hv, huv, hv²+gh²/2]
fn swe2d_flux_y(
  h : Double,
  hu : Double,
  hv : Double,
) -> (Double, Double, Double) {
  if h <= 0.0 {
    return (0.0, 0.0, 0.0)
  }
  let u = hu / h
  let v = hv / h
  (hv, hv * u, hv * v + 0.5 * g_gravity * h * h)
}

///|
/// x方向Lax-Friedrichs数值通量
fn swe2d_lf_flux_x(
  hL : Double,
  huL : Double,
  hvL : Double,
  hR : Double,
  huR : Double,
  hvR : Double,
) -> (Double, Double, Double) {
  let (f1L, f2L, f3L) = swe2d_flux_x(hL, huL, hvL)
  let (f1R, f2R, f3R) = swe2d_flux_x(hR, huR, hvR)
  let cL = if hL > 0.0 { @math.pow(g_gravity * hL, 0.5) } else { 0.0 }
  let cR = if hR > 0.0 { @math.pow(g_gravity * hR, 0.5) } else { 0.0 }
  let uL = if hL > 0.0 { huL / hL } else { 0.0 }
  let uR = if hR > 0.0 { huR / hR } else { 0.0 }
  let sL = uL.abs() + cL
  let sR = uR.abs() + cR
  let alpha = if sL > sR { sL } else { sR }
  (
    0.5 * (f1L + f1R) - 0.5 * alpha * (hR - hL),
    0.5 * (f2L + f2R) - 0.5 * alpha * (huR - huL),
    0.5 * (f3L + f3R) - 0.5 * alpha * (hvR - hvL),
  )
}

///|
/// y方向Lax-Friedrichs数值通量
fn swe2d_lf_flux_y(
  hL : Double,
  huL : Double,
  hvL : Double,
  hR : Double,
  huR : Double,
  hvR : Double,
) -> (Double, Double, Double) {
  let (g1L, g2L, g3L) = swe2d_flux_y(hL, huL, hvL)
  let (g1R, g2R, g3R) = swe2d_flux_y(hR, huR, hvR)
  let cL = if hL > 0.0 { @math.pow(g_gravity * hL, 0.5) } else { 0.0 }
  let cR = if hR > 0.0 { @math.pow(g_gravity * hR, 0.5) } else { 0.0 }
  let vL = if hL > 0.0 { hvL / hL } else { 0.0 }
  let vR = if hR > 0.0 { hvR / hR } else { 0.0 }
  let sL = vL.abs() + cL
  let sR = vR.abs() + cR
  let alpha = if sL > sR { sL } else { sR }
  (
    0.5 * (g1L + g1R) - 0.5 * alpha * (hR - hL),
    0.5 * (g2L + g2R) - 0.5 * alpha * (huR - huL),
    0.5 * (g3L + g3R) - 0.5 * alpha * (hvR - hvL),
  )
}

///|
/// 获取带边界条件的单元值（x方向）
fn get_cell_x(
  grid : SWEGrid2D,
  i : Int,
  j : Int,
  boundary : SWE2DBoundary,
) -> (Double, Double, Double) {
  let nx = grid.nx
  let ny = grid.ny
  // j方向使用透射边界
  let jj = if j < 0 { 0 } else if j >= ny { ny - 1 } else { j }
  // i方向边界处理
  if i < 0 {
    match boundary {
      Transmissive => {
        let k = idx2d(0, jj, ny)
        (grid.h[k], grid.hu[k], grid.hv[k])
      }
      SolidWall => {
        let k = idx2d(0, jj, ny)
        (grid.h[k], -grid.hu[k], grid.hv[k])
      }
    }
  } else if i >= nx {
    match boundary {
      Transmissive => {
        let k = idx2d(nx - 1, jj, ny)
        (grid.h[k], grid.hu[k], grid.hv[k])
      }
      SolidWall => {
        let k = idx2d(nx - 1, jj, ny)
        (grid.h[k], -grid.hu[k], grid.hv[k])
      }
    }
  } else {
    let k = idx2d(i, jj, ny)
    (grid.h[k], grid.hu[k], grid.hv[k])
  }
}

///|
/// 获取带边界条件的单元值（y方向）
fn get_cell_y(
  grid : SWEGrid2D,
  i : Int,
  j : Int,
  boundary : SWE2DBoundary,
) -> (Double, Double, Double) {
  let nx = grid.nx
  let ny = grid.ny
  // i方向使用透射边界
  let ii = if i < 0 { 0 } else if i >= nx { nx - 1 } else { i }
  // j方向边界处理
  if j < 0 {
    match boundary {
      Transmissive => {
        let k = idx2d(ii, 0, ny)
        (grid.h[k], grid.hu[k], grid.hv[k])
      }
      SolidWall => {
        let k = idx2d(ii, 0, ny)
        (grid.h[k], grid.hu[k], -grid.hv[k])
      }
    }
  } else if j >= ny {
    match boundary {
      Transmissive => {
        let k = idx2d(ii, ny - 1, ny)
        (grid.h[k], grid.hu[k], grid.hv[k])
      }
      SolidWall => {
        let k = idx2d(ii, ny - 1, ny)
        (grid.h[k], grid.hu[k], -grid.hv[k])
      }
    }
  } else {
    let k = idx2d(ii, j, ny)
    (grid.h[k], grid.hu[k], grid.hv[k])
  }
}

///|
/// 2D单步Lax-Friedrichs推进
pub fn SWEGrid2D::step_lf(
  self : SWEGrid2D,
  dt : Double,
  boundary : SWE2DBoundary,
) -> SWEGrid2D {
  let nx = self.nx
  let ny = self.ny
  let dx = self.dx
  let dy = self.dy
  let n_total = nx * ny
  let h_new = Array::make(n_total, 0.0)
  let hu_new = Array::make(n_total, 0.0)
  let hv_new = Array::make(n_total, 0.0)
  // 维度分裂：先x方向，再y方向
  // x方向通量更新
  for i in 0..<nx {
    for j in 0..<ny {
      let k = idx2d(i, j, ny)
      // 左侧单元
      let (hL, huL, hvL) = get_cell_x(self, i - 1, j, boundary)
      // 当前单元
      let (hC, huC, hvC) = get_cell_x(self, i, j, boundary)
      // 右侧单元
      let (hR, huR, hvR) = get_cell_x(self, i + 1, j, boundary)
      // x方向数值通量
      let (fxL1, fxL2, fxL3) = swe2d_lf_flux_x(hL, huL, hvL, hC, huC, hvC)
      let (fxR1, fxR2, fxR3) = swe2d_lf_flux_x(hC, huC, hvC, hR, huR, hvR)
      // x方向更新
      h_new[k] = hC - dt / dx * (fxR1 - fxL1)
      hu_new[k] = huC - dt / dx * (fxR2 - fxL2)
      hv_new[k] = hvC - dt / dx * (fxR3 - fxL3)
    }
  }
  // y方向通量更新（基于x方向更新后的状态）
  let h_mid = Array::make(n_total, 0.0)
  let hu_mid = Array::make(n_total, 0.0)
  let hv_mid = Array::make(n_total, 0.0)
  for k in 0..<n_total {
    h_mid[k] = h_new[k]
    hu_mid[k] = hu_new[k]
    hv_mid[k] = hv_new[k]
  }
  let mid_grid : SWEGrid2D = {
    nx,
    ny,
    dx,
    dy,
    h: h_mid,
    hu: hu_mid,
    hv: hv_mid,
    z: self.z,
    n_manning: self.n_manning,
  }
  for i in 0..<nx {
    for j in 0..<ny {
      let k = idx2d(i, j, ny)
      let (hL, huL, hvL) = get_cell_y(mid_grid, i, j - 1, boundary)
      let (hC, huC, hvC) = get_cell_y(mid_grid, i, j, boundary)
      let (hR, huR, hvR) = get_cell_y(mid_grid, i, j + 1, boundary)
      let (gyL1, gyL2, gyL3) = swe2d_lf_flux_y(hL, huL, hvL, hC, huC, hvC)
      let (gyR1, gyR2, gyR3) = swe2d_lf_flux_y(hC, huC, hvC, hR, huR, hvR)
      h_new[k] = hC - dt / dy * (gyR1 - gyL1)
      hu_new[k] = huC - dt / dy * (gyR2 - gyL2)
      hv_new[k] = hvC - dt / dy * (gyR3 - gyL3)
    }
  }
  // 源项：底坡 + Manning摩阻
  for i in 0..<nx {
    for j in 0..<ny {
      let k = idx2d(i, j, ny)
      if h_new[k] > 0.000001 {
        let u = hu_new[k] / h_new[k]
        let v = hv_new[k] / h_new[k]
        let n_val = self.n_manning[k]
        // 底坡源项
        let dzdx = if i > 0 && i < nx - 1 {
          (self.z[idx2d(i + 1, j, ny)] - self.z[idx2d(i - 1, j, ny)]) /
          (2.0 * dx)
        } else {
          0.0
        }
        let dzdy = if j > 0 && j < ny - 1 {
          (self.z[idx2d(i, j + 1, ny)] - self.z[idx2d(i, j - 1, ny)]) /
          (2.0 * dy)
        } else {
          0.0
        }
        let s_bed_x = -g_gravity * h_new[k] * dzdx
        let s_bed_y = -g_gravity * h_new[k] * dzdy
        // Manning摩阻
        let speed = @math.pow(u * u + v * v, 0.5)
        let h4_3 = @math.pow(h_new[k], 4.0 / 3.0)
        let s_fric_x = -g_gravity * n_val * n_val * u * speed / h4_3
        let s_fric_y = -g_gravity * n_val * n_val * v * speed / h4_3
        hu_new[k] = hu_new[k] + dt * (s_bed_x + s_fric_x)
        hv_new[k] = hv_new[k] + dt * (s_bed_y + s_fric_y)
      }
      // 水深非负保护
      if h_new[k] < 0.0 {
        h_new[k] = 0.0
        hu_new[k] = 0.0
        hv_new[k] = 0.0
      }
    }
  }
  {
    nx,
    ny,
    dx,
    dy,
    h: h_new,
    hu: hu_new,
    hv: hv_new,
    z: self.z,
    n_manning: self.n_manning,
  }
}

///|
/// 2D完整仿真
pub fn SWEGrid2D::run(
  self : SWEGrid2D,
  config : SWE2DSolverConfig,
) -> SWE2DResult {
  let n_total = self.nx * self.ny
  let max_depth = Array::make(n_total, 0.0)
  let mut grid = self
  let mut stable = true
  let mut steps_done = 0
  for step in 0..<config.n_steps {
    // CFL自适应时间步长
    let mut max_speed = 0.0
    for k in 0..<n_total {
      let h = grid.h[k]
      if h > 0.0 {
        let c = @math.pow(g_gravity * h, 0.5)
        let u = grid.hu[k] / h
        let v = grid.hv[k] / h
        let speed = @math.pow(u * u + v * v, 0.5) + c
        if speed > max_speed {
          max_speed = speed
        }
      }
    }
    let dt_eff = if max_speed > 0.0 {
      let dt_cfl_x = config.cfl * grid.dx / max_speed
      let dt_cfl_y = config.cfl * grid.dy / max_speed
      let dt_cfl = if dt_cfl_x < dt_cfl_y { dt_cfl_x } else { dt_cfl_y }
      if dt_cfl < config.dt {
        dt_cfl
      } else {
        config.dt
      }
    } else {
      config.dt
    }
    // 记录最大水深和稳定性
    for k in 0..<n_total {
      if grid.h[k] > max_depth[k] {
        max_depth[k] = grid.h[k]
      }
      if grid.h[k] < -0.001 || grid.h[k] > 1000000.0 {
        stable = false
      }
    }
    // 推进
    grid = grid.step_lf(dt_eff, config.boundary)
    steps_done = step + 1
    if !stable {
      break
    }
  }
  // 最终最大水深
  for k in 0..<n_total {
    if grid.h[k] > max_depth[k] {
      max_depth[k] = grid.h[k]
    }
  }
  {
    h_final: grid.h,
    hu_final: grid.hu,
    hv_final: grid.hv,
    max_depth,
    stable,
    n_steps_actual: steps_done,
  }
}

///|
/// 设置局部水深扰动（如dam-break初始条件）
pub fn SWEGrid2D::set_block(
  self : SWEGrid2D,
  i0~ : Int,
  i1~ : Int,
  j0~ : Int,
  j1~ : Int,
  h_value~ : Double,
) -> SWEGrid2D {
  let ny = self.ny
  for i in i0..<i1 {
    for j in j0..<j1 {
      if i >= 0 && i < self.nx && j >= 0 && j < ny {
        self.h[idx2d(i, j, ny)] = h_value
      }
    }
  }
  self
}

///|
/// 设置局部河底高程
pub fn SWEGrid2D::set_elevation(
  self : SWEGrid2D,
  i0~ : Int,
  i1~ : Int,
  j0~ : Int,
  j1~ : Int,
  z_value~ : Double,
) -> SWEGrid2D {
  let ny = self.ny
  for i in i0..<i1 {
    for j in j0..<j1 {
      if i >= 0 && i < self.nx && j >= 0 && j < ny {
        self.z[idx2d(i, j, ny)] = z_value
      }
    }
  }
  self
}
