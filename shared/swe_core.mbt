///|
/// 二维浅水方程求解内核
///
/// V0.1阶段：一维Saint-Venant方程Lax-Friedrichs显式格式
/// 后续V0.2扩展为二维有限体积法FVM
///
/// 浅水方程（1D）：
///   ∂h/∂t + ∂(hu)/∂x = 0
///   ∂(hu)/∂t + ∂(hu² + gh²/2)/∂x = -gh∂z/∂x - gSf
/// 其中 Sf = n²u|u|/h^(4/3) 为Manning摩阻坡度

///|
/// 一维浅水方程网格状态
///
/// nx: 网格单元数
/// dx: 空间步长(m)
/// h: 各单元水深(m)
/// hu: 各单元单宽流量(m²/s)
/// z: 各单元河底高程(m)
/// n_manning: 各单元Manning糙率系数
pub(all) struct SWEGrid1D {
  nx : Int
  dx : Double
  h : Array[Double]
  hu : Array[Double]
  z : Array[Double]
  n_manning : Array[Double]
} derive(Debug, ToJson, FromJson)

///|
/// 边界条件类型
pub(all) enum SWEBoundaryType {
  Transmissive // 透射边界（零梯度）
  SolidWall // 固壁边界（反射）
  Dirichlet(Double) // 给定值边界
} derive(Debug, ToJson, FromJson)

///|
/// 边界条件配置
pub(all) struct SWEBoundary {
  left : SWEBoundaryType
  right : SWEBoundaryType
} derive(Debug, ToJson, FromJson)

///|
/// SWE求解器配置
pub(all) struct SWESolverConfig {
  dt : Double // 时间步长(s)
  n_steps : Int // 总时间步数
  cfl : Double // CFL安全系数(用于自适应步长)
  boundary : SWEBoundary
} derive(Debug, ToJson, FromJson)

///|
/// SWE仿真结果
pub(all) struct SWEResult {
  h_series : Array[Array[Double]] // 各时刻水深场
  hu_series : Array[Array[Double]] // 各时刻单宽流量场
  max_depth : Array[Double] // 各单元最大水深
  stable : Bool // 数值稳定性标记
} derive(Debug, ToJson, FromJson)

///|
/// 构造均匀一维浅水网格
///
/// nx: 网格单元数
/// dx: 空间步长(m)
/// h0: 初始均匀水深(m)
/// z0: 初始均匀河底高程(m)
/// n0: 初始均匀Manning糙率
pub fn SWEGrid1D::uniform(
  nx~ : Int,
  dx~ : Double,
  h0~ : Double,
  z0? : Double = 0.0,
  n0? : Double = 0.03,
) -> SWEGrid1D {
  let h = Array::make(nx, h0)
  let hu = Array::make(nx, 0.0)
  let z = Array::make(nx, z0)
  let n_manning = Array::make(nx, n0)
  { nx, dx, h, hu, z, n_manning }
}

///|
/// 计算浅水方程通量F = [hu, hu² + gh²/2]
///
/// 给定守恒变量(h, hu)，返回通量(F1, F2)
fn swe_flux(h : Double, hu : Double) -> (Double, Double) {
  if h <= 0.0 {
    return (0.0, 0.0)
  }
  let u = hu / h
  (hu, hu * u + 0.5 * g_gravity * h * h)
}

///|
/// 计算波速c = √(gh)
fn wave_speed(h : Double) -> Double {
  if h <= 0.0 {
    return 0.0
  }
  @math.pow(g_gravity * h, 0.5)
}

///|
/// Lax-Friedrichs数值通量
///
/// F_lf = 0.5*(F_L + F_R) - 0.5*max_speed*(U_R - U_L)
fn lax_friedrichs_flux(
  hL : Double,
  huL : Double,
  hR : Double,
  huR : Double,
) -> (Double, Double) {
  let (f1L, f2L) = swe_flux(hL, huL)
  let (f1R, f2R) = swe_flux(hR, huR)
  // 最大波速估计
  let cL = wave_speed(hL)
  let cR = wave_speed(hR)
  let uL = if hL > 0.0 { huL / hL } else { 0.0 }
  let uR = if hR > 0.0 { huR / hR } else { 0.0 }
  let max_speed_l = uL.abs() + cL
  let max_speed_r = uR.abs() + cR
  let alpha = if max_speed_l > max_speed_r { max_speed_l } else { max_speed_r }
  // Lax-Friedrichs通量
  let f1 = 0.5 * (f1L + f1R) - 0.5 * alpha * (hR - hL)
  let f2 = 0.5 * (f2L + f2R) - 0.5 * alpha * (huR - huL)
  (f1, f2)
}

///|
/// 应用边界条件（返回新网格，不修改输入）
/// P1-7修复：不再就地修改输入grid，改为返回副本
fn apply_boundary(grid : SWEGrid1D, boundary : SWEBoundary) -> SWEGrid1D {
  let nx = grid.nx
  // P1修复：nx < 2 时无法应用边界条件，直接返回
  if nx < 2 {
    return grid
  }
  // 复制数组避免修改原grid
  let h = Array::make(nx, 0.0)
  let hu = Array::make(nx, 0.0)
  for i in 0..<nx {
    h[i] = grid.h[i]
    hu[i] = grid.hu[i]
  }
  // 左边界
  match boundary.left {
    Transmissive => {
      h[0] = h[1]
      hu[0] = hu[1]
    }
    SolidWall => {
      h[0] = h[1]
      hu[0] = -hu[1]
    }
    Dirichlet(h_fix) => {
      h[0] = h_fix
      hu[0] = 0.0
    }
  }
  // 右边界
  match boundary.right {
    Transmissive => {
      h[nx - 1] = h[nx - 2]
      hu[nx - 1] = hu[nx - 2]
    }
    SolidWall => {
      h[nx - 1] = h[nx - 2]
      hu[nx - 1] = -hu[nx - 2]
    }
    Dirichlet(h_fix) => {
      h[nx - 1] = h_fix
      hu[nx - 1] = 0.0
    }
  }
  { ..grid, h, hu }
}

///|
/// 单步Lax-Friedrichs推进
///
/// 给定当前网格状态，推进一个时间步，返回更新后的网格
pub fn SWEGrid1D::step_lf(
  self : SWEGrid1D,
  dt : Double,
  boundary : SWEBoundary,
) -> SWEGrid1D {
  let nx = self.nx
  let dx = self.dx
  // P1-7修复：使用apply_boundary返回的副本进行通量计算
  let bounded = apply_boundary(self, boundary)
  // 计算所有界面通量（i=0..nx-2，共nx-1个界面）
  let n_faces = nx - 1
  let f1_arr : Array[Double] = Array::make(n_faces, 0.0)
  let f2_arr : Array[Double] = Array::make(n_faces, 0.0)
  for i in 0..<n_faces {
    let (f1, f2) = lax_friedrichs_flux(
      bounded.h[i],
      bounded.hu[i],
      bounded.h[i + 1],
      bounded.hu[i + 1],
    )
    f1_arr[i] = f1
    f2_arr[i] = f2
  }
  // 更新内部单元（i=1..nx-2）
  let h_new = Array::make(nx, 0.0)
  let hu_new = Array::make(nx, 0.0)
  for i in 0..<nx {
    h_new[i] = bounded.h[i]
    hu_new[i] = bounded.hu[i]
  }
  let n_inner = nx - 1
  for i in 1..<n_inner {
    // 守恒变量更新：U_i^{n+1} = U_i^n - dt/dx * (F_{i+1/2} - F_{i-1/2})
    h_new[i] = bounded.h[i] - dt / dx * (f1_arr[i] - f1_arr[i - 1])
    hu_new[i] = bounded.hu[i] - dt / dx * (f2_arr[i] - f2_arr[i - 1])
    // 源项：底坡 + Manning摩阻
    let dz = bounded.z[i + 1] - bounded.z[i - 1]
    let h_avg = h_new[i]
    if h_avg > 0.0 {
      let h_fric = if h_avg < 0.001 { 0.001 } else { h_avg }
      let u_avg = hu_new[i] / h_avg
      let n_val = bounded.n_manning[i]
      // 底坡源项：-gh∂z/∂x
      let s_bed = -g_gravity * h_avg * dz / (2.0 * dx)
      // Manning摩阻源项：-g*n²*u*|u|/h^(4/3)，小水深钳制防发散
      let s_friction = -g_gravity *
        n_val *
        n_val *
        u_avg *
        u_avg.abs() *
        @math.pow(h_fric, -4.0 / 3.0)
      hu_new[i] = hu_new[i] + dt * (s_bed + s_friction)
    }
    // 水深非负保护，按比例缩放动量保持守恒
    if h_new[i] < 0.0 {
      let h_clamped = 0.0
      let h_old = bounded.h[i]
      if h_old > 0.0 {
        hu_new[i] = hu_new[i] * (h_clamped / h_old)
      } else {
        hu_new[i] = 0.0
      }
      h_new[i] = h_clamped
    }
  }
  // 边界单元使用已应用边界条件的值
  h_new[0] = bounded.h[0]
  hu_new[0] = bounded.hu[0]
  h_new[nx - 1] = bounded.h[nx - 1]
  hu_new[nx - 1] = bounded.hu[nx - 1]
  { nx, dx, h: h_new, hu: hu_new, z: self.z, n_manning: self.n_manning }
}

///|
/// 完整SWE仿真
///
/// 给定初始网格和求解配置，运行完整仿真，返回结果序列
pub fn SWEGrid1D::run(self : SWEGrid1D, config : SWESolverConfig) -> SWEResult {
  let h_series : Array[Array[Double]] = []
  let hu_series : Array[Array[Double]] = []
  let max_depth = Array::make(self.nx, 0.0)
  let mut grid = self
  let mut stable = true
  for _ in 0..<config.n_steps {
    // 计算自适应时间步长（CFL条件）
    let mut max_speed = 0.0
    for i in 0..<grid.nx {
      let c = wave_speed(grid.h[i])
      let u = if grid.h[i] > 0.0 { grid.hu[i] / grid.h[i] } else { 0.0 }
      let speed = u.abs() + c
      if speed > max_speed {
        max_speed = speed
      }
    }
    let dt_eff = if max_speed > 0.0 {
      let dt_cfl = config.cfl * grid.dx / max_speed
      if dt_cfl < config.dt {
        dt_cfl
      } else {
        config.dt
      }
    } else {
      config.dt
    }
    // 记录当前状态
    let h_copy = Array::make(grid.nx, 0.0)
    let hu_copy = Array::make(grid.nx, 0.0)
    for i in 0..<grid.nx {
      h_copy[i] = grid.h[i]
      hu_copy[i] = grid.hu[i]
      if grid.h[i] > max_depth[i] {
        max_depth[i] = grid.h[i]
      }
      // 稳定性检测
      if grid.h[i] < -0.001 || grid.h[i] > 1000000.0 {
        stable = false
      }
    }
    if !stable {
      break
    }
    h_series.push(h_copy)
    hu_series.push(hu_copy)
    // 推进
    grid = grid.step_lf(dt_eff, config.boundary)
  }
  // 计算最终时刻最大水深
  for i in 0..<grid.nx {
    if grid.h[i] > max_depth[i] {
      max_depth[i] = grid.h[i]
    }
    // P2-12修复：检查最终时刻稳定性（循环内检查在推进前，最后一步未覆盖）
    if grid.h[i] < -0.001 || grid.h[i] > 1000000.0 {
      stable = false
    }
  }
  { h_series, hu_series, max_depth, stable }
}

///|
/// 计算CFL条件下的最大稳定时间步长
///
/// dt_max = CFL * dx / max(|u| + c)
pub fn SWEGrid1D::max_stable_dt(self : SWEGrid1D, cfl~ : Double) -> Double {
  let mut max_speed = 0.0
  for i in 0..<self.nx {
    let c = wave_speed(self.h[i])
    let u = if self.h[i] > 0.0 { self.hu[i] / self.h[i] } else { 0.0 }
    let speed = u.abs() + c
    if speed > max_speed {
      max_speed = speed
    }
  }
  if max_speed > 0.0 {
    cfl * self.dx / max_speed
  } else {
    1.0
  }
}
