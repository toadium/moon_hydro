///|
/// SCE-UA(Shuffled Complex Evolution)全局参数率定算法
///
/// Duan et al.(1992)提出的水文模型参数全局优化算法
/// 算法核心：多complex并行进化 + 周期性shuffle混合
/// 适用于高维、多峰、非凸水文模型参数空间
///
/// 算法步骤：
/// 1. 在参数空间随机生成 s = p × m 个样本点
/// 2. 按目标函数值排序，划分为 p 个 complex
/// 3. 每个 complex 内执行 CCE（竞争复形进化）：
///    - 选取子单纯形（n+1 个点）
///    - 反射、扩张、收缩操作
///    - 替换最差点
/// 4. 所有 complex 进化完成后 shuffle：合并、排序、重新分区
/// 5. 收敛判定（最大迭代次数或目标函数改进阈值）

///|
/// SCE-UA算法配置
pub(all) struct SCEUAConfig {
  max_iter : Int // 最大全局迭代次数
  n_complexes : Int // complex数p(默认5)
  complex_size : Int // 每个complex的点数m(默认2n+1)
  cce_iterations : Int // 每个complex内CCE进化次数(默认n+1)
  seed : UInt64 // 随机种子
  target_metric : String // 目标指标("nse"或"kge")
  params : Array[CalibParam] // 待率定参数
  convergence_threshold : Double // 收敛阈值(目标函数改进小于此值则收敛)
  max_no_improve : Int // 最大无改进迭代次数
} derive(Debug, ToJson, FromJson, Default)

///|
/// SCE-UA率定结果
pub(all) struct SCEUAResult {
  best_params : Array[CalibParam] // 最优参数组合
  best_metric : Double // 最优指标值(NSE或KGE)
  metric_history : Array[Double] // 全局指标收敛历史
  n_iter : Int // 实际迭代次数
  converged : Bool // 是否收敛
  n_function_evals : Int // 目标函数调用次数
  complex_evolution_history : Array[Double] // 各complex最优值历史
} derive(Debug, ToJson, FromJson)

///|
/// 构造默认SCE-UA配置
pub fn SCEUAConfig::default() -> SCEUAConfig {
  {
    max_iter: 1000,
    n_complexes: 5,
    complex_size: 0, // 0表示自动(2n+1)
    cce_iterations: 0, // 0表示自动(n+1)
    seed: 42,
    target_metric: "nse",
    params: [],
    convergence_threshold: 0.000001,
    max_no_improve: 200,
  }
}

///|
/// 样本点：参数组合 + 目标函数值
priv struct SamplePoint {
  params : Array[Double] // 参数值数组
  fitness : Double // 目标函数值(越小越好，存储-NSE或-KGE)
}

///|
/// 从CalibParam数组提取上下界
fn extract_bounds(params : Array[CalibParam]) -> (Array[Double], Array[Double]) {
  let lowers : Array[Double] = []
  let uppers : Array[Double] = []
  for p in params {
    lowers.push(p.lower)
    uppers.push(p.upper)
  }
  (lowers, uppers)
}

///|
/// 将参数值数组转换为CalibParam数组
fn values_to_calib_params(
  values : Array[Double],
  template : Array[CalibParam],
) -> Array[CalibParam] {
  let result : Array[CalibParam] = []
  for i in 0..<values.length() {
    let p = template[i]
    result.push({
      name: p.name,
      lower: p.lower,
      upper: p.upper,
      value: values[i],
    })
  }
  result
}

///|
/// 目标函数：计算给定参数下的负NSE或负KGE
fn sceua_objective(
  values : Array[Double],
  template : Array[CalibParam],
  area : Double,
  dt : Double,
  forcings : Array[ForcingData],
  observed : Array[Double],
  target_metric : String,
) -> Double {
  let calib_params = values_to_calib_params(values, template)
  let xaj_params = params_to_xaj(calib_params)
  let model = XinanjiangModel::new(params=xaj_params, area~, dt~)
  let result = model.run(forcings)
  let metric = if target_metric == "kge" {
    kge(observed, result.runoff_series)
  } else {
    nse(observed, result.runoff_series)
  }
  // 最小化问题：返回负指标
  -metric
}

///|
/// 在参数空间内随机生成一个样本点
fn random_sample(
  lowers : Array[Double],
  uppers : Array[Double],
  rng : @splitmix.RandomState,
) -> Array[Double] {
  let values : Array[Double] = []
  for i in 0..<lowers.length() {
    let r = rng.next_double()
    values.push(lowers[i] + r * (uppers[i] - lowers[i]))
  }
  values
}

///|
/// 参数边界约束
fn clamp_params(
  values : Array[Double],
  lowers : Array[Double],
  uppers : Array[Double],
) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<values.length() {
    let v = if values[i] < lowers[i] {
      lowers[i]
    } else if values[i] > uppers[i] {
      uppers[i]
    } else {
      values[i]
    }
    result.push(v)
  }
  result
}

///|
/// 计算单纯形质心（排除最差点）
fn compute_centroid(
  points : Array[SamplePoint],
  exclude_idx : Int,
) -> Array[Double] {
  let n = points.length()
  let dim = if n > 0 { points[0].params.length() } else { 0 }
  if dim == 0 {
    return []
  }
  let centroid : Array[Double] = Array::make(dim, 0.0)
  let mut count = 0
  for i in 0..<n {
    if i != exclude_idx {
      for j in 0..<dim {
        centroid[j] = centroid[j] + points[i].params[j]
      }
      count = count + 1
    }
  }
  if count > 0 {
    for j in 0..<dim {
      centroid[j] = centroid[j] / count.to_double()
    }
  }
  centroid
}

///|
/// CCE竞争复形进化：单个complex内的Nelder-Mead单纯形进化
///
/// complex: 该complex的所有样本点
/// lowers/uppers: 参数边界
/// objective_ctx: 目标函数上下文
/// n_cce: CCE迭代次数
/// rng: 随机数生成器
fn cce_evolution(
  complex : Array[SamplePoint],
  lowers : Array[Double],
  uppers : Array[Double],
  area : Double,
  dt : Double,
  forcings : Array[ForcingData],
  observed : Array[Double],
  target_metric : String,
  template : Array[CalibParam],
  n_cce : Int,
  rng : @splitmix.RandomState,
  n_evals : Ref[Int],
) -> Array[SamplePoint] {
  let n = complex.length()
  let dim = if n > 0 { complex[0].params.length() } else { 0 }
  if n < 2 || dim == 0 {
    return complex
  }
  // 复制complex
  let points : Array[SamplePoint] = []
  for p in complex {
    let copy : Array[Double] = []
    for v in p.params {
      copy.push(v)
    }
    points.push({ params: copy, fitness: p.fitness })
  }
  // Nelder-Mead参数
  let alpha = 1.0 // 反射系数
  let beta = 0.5 // 收缩系数
  let gamma = 2.0 // 扩张系数
  for _ in 0..<n_cce {
    // 按fitness排序（升序，最好的在前）
    points.sort_by(fn(a, b) {
      if a.fitness < b.fitness {
        -1
      } else if a.fitness > b.fitness {
        1
      } else {
        0
      }
    })
    // T21修复：随机选取q个不同点构成子单纯形（标准SCE-UA CCE）
    let q = if dim + 1 < n { dim + 1 } else { n }
    let indices : Array[Int] = []
    for i in 0..<n {
      indices.push(i)
    }
    // 部分Fisher-Yates洗牌，选取q个不重复索引
    // 注意：采用均匀选取简化变体，非标准SCE-UA三角概率分布
    for i in 0..<q {
      let j_raw = (rng.next_double() * (n - i).to_double()).to_int()
      let j = i + (if j_raw >= n - i { n - i - 1 } else { j_raw })
      let tmp = indices[i]
      indices[i] = indices[j]
      indices[j] = tmp
    }
    let sub_points : Array[SamplePoint] = []
    for i in 0..<q {
      sub_points.push(points[indices[i]])
    }
    // 按fitness升序对子单纯形排序（插入排序），定位最差点
    let order : Array[Int] = []
    for i in 0..<q {
      order.push(i)
    }
    for i in 1..<q {
      let key = order[i]
      let key_fit = sub_points[key].fitness
      let mut k = i - 1
      while k >= 0 && sub_points[order[k]].fitness > key_fit {
        order[k + 1] = order[k]
        k = k - 1
      }
      order[k + 1] = key
    }
    let worst_local = q - 1
    let worst_pos = indices[order[worst_local]]
    // 计算质心（排除最差点）
    let centroid = compute_centroid(sub_points, worst_local)
    let worst = sub_points[worst_local]
    // 反射点：xr = centroid + alpha × (centroid - worst)
    let reflected : Array[Double] = []
    for j in 0..<dim {
      reflected.push(centroid[j] + alpha * (centroid[j] - worst.params[j]))
    }
    let reflected_clamped = clamp_params(reflected, lowers, uppers)
    let reflected_fitness = sceua_objective(
      reflected_clamped, template, area, dt, forcings, observed, target_metric,
    )
    n_evals.val = n_evals.val + 1
    // 比较反射点与最好点
    let best_fitness = points[0].fitness
    let second_worst_fitness = if q >= 2 {
      sub_points[order[q - 2]].fitness
    } else {
      worst.fitness
    }
    if reflected_fitness < best_fitness {
      // 反射点更好：尝试扩张
      let expanded : Array[Double] = []
      for j in 0..<dim {
        expanded.push(
          centroid[j] + gamma * (reflected_clamped[j] - centroid[j]),
        )
      }
      let expanded_clamped = clamp_params(expanded, lowers, uppers)
      let expanded_fitness = sceua_objective(
        expanded_clamped, template, area, dt, forcings, observed, target_metric,
      )
      n_evals.val = n_evals.val + 1
      if expanded_fitness < reflected_fitness {
        // 接受扩张点
        points[worst_pos] = {
          params: expanded_clamped,
          fitness: expanded_fitness,
        }
      } else {
        // 接受反射点
        points[worst_pos] = {
          params: reflected_clamped,
          fitness: reflected_fitness,
        }
      }
    } else if reflected_fitness < second_worst_fitness {
      // 反射点次优：接受
      points[worst_pos] = {
        params: reflected_clamped,
        fitness: reflected_fitness,
      }
    } else {
      // 反射点差：收缩
      let contracted : Array[Double] = []
      let better_worst = if reflected_fitness < worst.fitness {
        reflected_clamped
      } else {
        worst.params
      }
      for j in 0..<dim {
        contracted.push(centroid[j] + beta * (better_worst[j] - centroid[j]))
      }
      let contracted_clamped = clamp_params(contracted, lowers, uppers)
      let contracted_fitness = sceua_objective(
        contracted_clamped, template, area, dt, forcings, observed, target_metric,
      )
      n_evals.val = n_evals.val + 1
      if contracted_fitness < worst.fitness {
        // 接受收缩点
        points[worst_pos] = {
          params: contracted_clamped,
          fitness: contracted_fitness,
        }
      } else {
        // 收缩失败：整体向最好点收缩
        let best = points[0]
        for i in 1..<n {
          let new_params : Array[Double] = []
          for j in 0..<dim {
            new_params.push(
              best.params[j] + beta * (points[i].params[j] - best.params[j]),
            )
          }
          let clamped = clamp_params(new_params, lowers, uppers)
          let new_fitness = sceua_objective(
            clamped, template, area, dt, forcings, observed, target_metric,
          )
          n_evals.val = n_evals.val + 1
          points[i] = { params: clamped, fitness: new_fitness }
        }
      }
    }
  }
  points
}

///|
/// SCE-UA主率定函数
///
/// 给定配置、流域信息和观测数据，运行SCE-UA全局优化
pub fn sceua_calibrate(
  config : SCEUAConfig,
  area~ : Double,
  dt~ : Double,
  forcings : Array[ForcingData],
  observed : Array[Double],
) -> SCEUAResult {
  let rng = @splitmix.new(seed=config.seed)
  let n_params = config.params.length()
  if n_params == 0 {
    return {
      best_params: [],
      best_metric: 0.0,
      metric_history: [],
      n_iter: 0,
      converged: true,
      n_function_evals: 0,
      complex_evolution_history: [],
    }
  }
  let (lowers, uppers) = extract_bounds(config.params)
  // 自动确定complex大小和CCE次数
  let m = if config.complex_size > 0 {
    config.complex_size
  } else {
    2 * n_params + 1
  }
  let p = config.n_complexes
  let s = p * m // 总样本数
  let n_cce = if config.cce_iterations > 0 {
    config.cce_iterations
  } else {
    n_params + 1
  }
  // 1. 初始化：随机生成s个样本点
  let all_points : Array[SamplePoint] = []
  for _ in 0..<s {
    let values = random_sample(lowers, uppers, rng)
    let fitness = sceua_objective(
      values,
      config.params,
      area,
      dt,
      forcings,
      observed,
      config.target_metric,
    )
    all_points.push({ params: values, fitness })
  }
  let n_evals = Ref(s)
  // 2. 初始排序
  all_points.sort_by(fn(a, b) {
    if a.fitness < b.fitness {
      -1
    } else if a.fitness > b.fitness {
      1
    } else {
      0
    }
  })
  let mut best_fitness = all_points[0].fitness
  let mut best_values : Array[Double] = []
  for v in all_points[0].params {
    best_values.push(v)
  }
  let metric_history : Array[Double] = [-best_fitness]
  let complex_history : Array[Double] = [-best_fitness]
  let mut no_improve_count = 0
  let mut converged = false
  // 3. 主循环
  for _ in 1..<=config.max_iter {
    // 划分为p个complex：采用"分块"分配策略
    // 第i个complex包含索引 i, i+p, i+2p, ... 的点
    let complexes : Array[Array[SamplePoint]] = []
    for c in 0..<p {
      let complex : Array[SamplePoint] = []
      let mut k = c
      while k < s {
        let copy : Array[Double] = []
        for v in all_points[k].params {
          copy.push(v)
        }
        complex.push({ params: copy, fitness: all_points[k].fitness })
        k = k + p
      }
      complexes.push(complex)
    }
    // 4. 每个complex内执行CCE进化
    for c in 0..<p {
      let evolved = cce_evolution(
        complexes[c],
        lowers,
        uppers,
        area,
        dt,
        forcings,
        observed,
        config.target_metric,
        config.params,
        n_cce,
        rng,
        n_evals,
      )
      complexes[c] = evolved
    }
    // 5. Shuffle：合并所有complex的点
    let mut idx = 0
    for c in 0..<p {
      for point in complexes[c] {
        if idx < s {
          all_points[idx] = point
          idx = idx + 1
        }
      }
    }
    // 6. 重新排序
    all_points.sort_by(fn(a, b) {
      if a.fitness < b.fitness {
        -1
      } else if a.fitness > b.fitness {
        1
      } else {
        0
      }
    })
    // 7. 更新最优值
    let current_best = all_points[0].fitness
    if current_best < best_fitness {
      let improvement = best_fitness - current_best
      best_fitness = current_best
      best_values = []
      for v in all_points[0].params {
        best_values.push(v)
      }
      no_improve_count = 0
      // 收敛判定：改进小于阈值
      if improvement < config.convergence_threshold {
        converged = true
        metric_history.push(-best_fitness)
        complex_history.push(-best_fitness)
        break
      }
    } else {
      no_improve_count = no_improve_count + 1
    }
    metric_history.push(-best_fitness)
    complex_history.push(-best_fitness)
    // 8. 无改进收敛判定
    if no_improve_count >= config.max_no_improve {
      converged = true
      break
    }
  }
  // 构造最终结果
  let best_params = values_to_calib_params(best_values, config.params)
  {
    best_params,
    best_metric: -best_fitness,
    metric_history,
    n_iter: metric_history.length() - 1,
    converged,
    n_function_evals: n_evals.val,
    complex_evolution_history: complex_history,
  }
}

///|
/// 构造SCE-UA典型率定参数集（与DDS共享）
///
/// 返回11个核心参数的默认率定范围
pub fn sceua_default_calib_params() -> Array[CalibParam] {
  default_calib_params()
}
