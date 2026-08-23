///|
/// 参数率定算法模块
///
/// 实现DDS（Dynamically Dimensioned Search）全局参数优化算法
/// DDS适用于高维水文模型参数率定，随迭代递减扰动维度

///|
/// 率定参数定义
pub(all) struct CalibParam {
  name : String
  lower : Double // 下限
  upper : Double // 上限
  value : Double // 当前值
} derive(Debug, ToJson, FromJson)

///|
/// DDS率定配置
pub(all) struct DDSConfig {
  max_iter : Int // 最大迭代次数
  r : Double // 扰动率(默认0.2)
  seed : UInt64 // 随机种子
  target_metric : String // 目标指标("nse"或"kge")
  params : Array[CalibParam] // 待率定参数
  max_no_improve : Int // P3-2修复：最大无改进迭代次数(默认100)
} derive(Debug, ToJson, FromJson, Default)

///|
/// 率定结果
pub(all) struct CalibResult {
  best_params : Array[CalibParam] // 最优参数组合
  best_metric : Double // 最优指标值
  metric_history : Array[Double] // 指标收敛历史
  n_iter : Int // 实际迭代次数
  converged : Bool // 是否收敛
} derive(Debug, ToJson, FromJson)

///|
/// 构造默认DDS配置
pub fn DDSConfig::default() -> DDSConfig {
  {
    max_iter: 1000,
    r: 0.2,
    seed: 42,
    target_metric: "nse",
    params: [],
    max_no_improve: 100,
  }
}

///|

///|
/// 计算DDS扰动维度数
///
/// 随迭代次数递减：从全维度到1维
/// P = 1 - ln(iter) / ln(max_iter)
fn dds_dimension(iter : Int, max_iter : Int, n_params : Int) -> Int {
  if iter >= max_iter {
    return 1
  }
  let iter_d = iter.to_double()
  let max_d = max_iter.to_double()
  let dim_ratio = if max_d <= 1.0 {
    0.0
  } else {
    1.0 - @math.ln(iter_d) / @math.ln(max_d)
  }
  let dim = (dim_ratio * n_params.to_double()).to_int()
  if dim < 1 {
    1
  } else if dim > n_params {
    n_params
  } else {
    dim
  }
}

///|
/// 高斯随机扰动（Box-Muller变换）
fn gaussian_perturbation(
  rng : @splitmix.RandomState,
  mean? : Double = 0.0,
  stddev? : Double = 1.0,
) -> Double {
  // P1修复：用1.0-next_double()保证u1∈(0,1]，避免ln(0)和ln(>1)的NaN
  let u1 = 1.0 - rng.next_double()
  let u2 = rng.next_double()
  // Box-Muller变换（P2-13：仅使用cos分量，sin分量未复用，可优化为交替输出）
  let z = @math.pow(-2.0 * @math.ln(u1), 0.5) *
    @math.cos(2.0 * @math.PI * u2)
  mean + stddev * z
}

///|
/// DDS单步扰动
///
/// 随机选择dim个参数进行高斯扰动
fn dds_perturb(
  current : Array[CalibParam],
  dim : Int,
  r : Double,
  rng : @splitmix.RandomState,
) -> Array[CalibParam] {
  let n = current.length()
  // 边界保护：空参数数组直接返回空结果
  if n == 0 {
    return []
  }
  // 复制当前参数
  let new_params : Array[CalibParam] = []
  for p in current {
    new_params.push({
      name: p.name,
      lower: p.lower,
      upper: p.upper,
      value: p.value,
    })
  }
  // 随机选择dim个参数进行扰动
  for _ in 0..<dim {
    let raw = rng.next_int()
    let idx = if raw == -2147483648 { 0 } else { raw.abs() % n }
    let p = new_params[idx]
    // 扰动量 = r × (upper - lower) × gaussian
    let range = p.upper - p.lower
    let perturbation = r * range * gaussian_perturbation(rng)
    let new_value = p.value + perturbation
    // 边界约束
    let clamped = if new_value < p.lower {
      p.lower
    } else if new_value > p.upper {
      p.upper
    } else {
      new_value
    }
    new_params[idx] = {
      name: p.name,
      lower: p.lower,
      upper: p.upper,
      value: clamped,
    }
  }
  new_params
}

///|
/// 将CalibParam数组转换为新安江参数
///
/// 按参数名匹配更新XinanjiangParams字段
pub fn params_to_xaj(params : Array[CalibParam]) -> XinanjiangParams {
  let base = XinanjiangParams::default()
  let mut wm = base.wm
  let mut b = base.b
  let mut im = base.im
  let mut c = base.c
  let mut sm = base.sm
  let mut ex = base.ex
  let mut kg = base.kg
  let mut ki = base.ki
  let mut cg = base.cg
  let mut ci = base.ci
  let mut cs = base.cs
  for p in params {
    match p.name {
      "wm" => wm = p.value
      "b" => b = p.value
      "im" => im = p.value
      "c" => c = p.value
      "sm" => sm = p.value
      "ex" => ex = p.value
      "kg" => kg = p.value
      "ki" => ki = p.value
      "cg" => cg = p.value
      "ci" => ci = p.value
      "cs" => cs = p.value
      _ => ()
    }
  }
  {
    wm,
    wum: base.wum,
    wlm: base.wlm,
    wdm: base.wdm,
    b,
    im,
    c,
    sm,
    ex,
    kg,
    ki,
    cg,
    ci,
    cs,
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
/// 目标函数：计算给定参数下的NSE或KGE（负值，因为DDS是最小化）
///
/// P1-2修复：支持target_metric配置，不再只算NSE
fn objective_nse(
  params : Array[CalibParam],
  area : Double,
  dt : Double,
  forcings : Array[ForcingData],
  observed : Array[Double],
  target_metric : String,
) -> Double {
  let xaj_params = params_to_xaj(params)
  let model = XinanjiangModel::new(params=xaj_params, area~, dt~)
  let result = model.run(forcings)
  let metric = if target_metric == "kge" {
    kge(observed, result.runoff_series)
  } else {
    nse(observed, result.runoff_series)
  }
  // DDS最小化，所以返回负指标
  -metric
}

///|
/// DDS率定主函数
///
/// 给定配置、流域信息和观测数据，运行DDS优化
pub fn dds_calibrate(
  config : DDSConfig,
  area~ : Double,
  dt~ : Double,
  forcings : Array[ForcingData],
  observed : Array[Double],
) -> CalibResult {
  let rng = @splitmix.new(seed=config.seed)
  let n_params = config.params.length()
  // 初始化：从参数范围内随机采样
  let mut current_params : Array[CalibParam] = []
  for p in config.params {
    let random_val = p.lower + rng.next_double() * (p.upper - p.lower)
    current_params.push({
      name: p.name,
      lower: p.lower,
      upper: p.upper,
      value: random_val,
    })
  }
  // 初始目标函数值
  let mut best_metric = objective_nse(
    current_params,
    area,
    dt,
    forcings,
    observed,
    config.target_metric,
  )
  let mut best_params : Array[CalibParam] = []
  for p in current_params {
    best_params.push({
      name: p.name,
      lower: p.lower,
      upper: p.upper,
      value: p.value,
    })
  }
  let metric_history : Array[Double] = [-best_metric] // 存储NSE正值
  let mut converged = false
  let mut no_improve_count = 0
  // DDS迭代
  for iter in 1..<=config.max_iter {
    // 计算扰动维度
    let dim = dds_dimension(iter, config.max_iter, n_params)
    // 扰动生成新参数
    let candidate = dds_perturb(current_params, dim, config.r, rng)
    // 计算新目标函数值
    let candidate_metric = objective_nse(
      candidate,
      area,
      dt,
      forcings,
      observed,
      config.target_metric,
    )
    // 接受准则：如果更好则更新
    if candidate_metric < best_metric {
      best_metric = candidate_metric
      best_params = []
      for p in candidate {
        best_params.push({
          name: p.name,
          lower: p.lower,
          upper: p.upper,
          value: p.value,
        })
      }
      current_params = []
      for p in candidate {
        current_params.push({
          name: p.name,
          lower: p.lower,
          upper: p.upper,
          value: p.value,
        })
      }
      no_improve_count = 0
    } else {
      no_improve_count = no_improve_count + 1
    }
    metric_history.push(-best_metric)
    // 收敛判定：连续max_no_improve次无改进
    if no_improve_count >= config.max_no_improve {
      converged = true
      break
    }
  }
  {
    best_params,
    best_metric: -best_metric,
    metric_history,
    n_iter: metric_history.length() - 1,
    converged,
  }
}

///|
/// 构造新安江典型率定参数集
///
/// 返回11个核心参数的默认率定范围
pub fn default_calib_params() -> Array[CalibParam] {
  [
    { name: "wm", lower: 80.0, upper: 160.0, value: 120.0 },
    { name: "b", lower: 0.2, upper: 0.6, value: 0.3 },
    { name: "im", lower: 0.0, upper: 0.05, value: 0.01 },
    { name: "c", lower: 0.5, upper: 1.0, value: 1.0 },
    { name: "sm", lower: 10.0, upper: 40.0, value: 20.0 },
    { name: "ex", lower: 1.0, upper: 2.5, value: 1.5 },
    { name: "kg", lower: 0.2, upper: 0.5, value: 0.35 },
    { name: "ki", lower: 0.2, upper: 0.5, value: 0.3 },
    { name: "cg", lower: 0.9, upper: 0.99, value: 0.98 },
    { name: "ci", lower: 0.5, upper: 0.8, value: 0.63 },
    { name: "cs", lower: 0.1, upper: 0.4, value: 0.2 },
  ]
}
