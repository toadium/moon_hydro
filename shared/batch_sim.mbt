///|
/// 批量仿真调度模块
///
/// 提供多流域、多情景批量仿真调度能力
/// 由于当前环境无async库，采用顺序执行+结果聚合模式
/// 后续接入async后可替换为并行调度
///
/// 功能：
/// - 多流域批量仿真
/// - 多情景集合仿真
/// - 参数敏感性扫描
/// - 蒙特卡洛不确定性分析
/// - 批量评价聚合

///|
/// 单个仿真任务定义
pub(all) struct SimTask {
  task_id : String // 任务标识
  basin_name : String // 流域名称
  params : XinanjiangParams // 模型参数
  area : Double // 流域面积
  dt : Double // 时段
  forcings : Array[ForcingData] // 气象驱动
  observed : Array[Double] // 观测径流(可选，用于评价)
} derive(Debug, ToJson, FromJson)

///|
/// 单个仿真任务结果
pub(all) struct SimTaskResult {
  task_id : String // 任务标识
  basin_name : String // 流域名称
  runoff_series : Array[Double] // 径流过程
  peak_flow : Double // 洪峰流量
  peak_time : Int // 洪峰时段索引
  total_volume : Double // 总径流量
  nse : Double // NSE(若有观测)
  kge : Double // KGE(若有观测)
  pbias : Double // PBIAS(若有观测)
  has_obs : Bool // P2-9修复：标记是否有观测数据
  success : Bool // 是否成功
  error_message : String // 错误信息
} derive(Debug, ToJson, FromJson)

///|
/// 批量仿真结果汇总
pub(all) struct BatchSimResult {
  results : Array[SimTaskResult] // 各任务结果
  total_tasks : Int // 总任务数
  success_count : Int // 成功数
  failure_count : Int // 失败数
  total_time_steps : Int // 总仿真时段数
  summary_stats : BatchSummaryStats // 汇总统计
} derive(Debug, ToJson, FromJson)

///|
/// 批量仿真汇总统计
pub(all) struct BatchSummaryStats {
  mean_nse : Double // 平均NSE
  mean_kge : Double // 平均KGE
  mean_pbias : Double // 平均PBIAS
  best_nse : Double // 最优NSE
  worst_nse : Double // 最差NSE
  mean_peak_flow : Double // 平均洪峰
  total_volume : Double // 总径流量
} derive(Debug, ToJson, FromJson)

///|
/// 执行单个仿真任务
///
/// 返回仿真结果，包含径流过程与评价指标
pub fn run_sim_task(task : SimTask) -> SimTaskResult {
  let task_id = task.task_id
  let basin_name = task.basin_name
  // T24修复：输入校验，非法入参走失败路径而非产生无意义结果
  if task.area <= 0.0 || task.dt <= 0.0 {
    return {
      task_id,
      basin_name,
      runoff_series: [],
      peak_flow: 0.0,
      peak_time: 0,
      total_volume: 0.0,
      nse: 0.0,
      kge: 0.0,
      pbias: 0.0,
      has_obs: false,
      success: false,
      error_message: "invalid area or dt (must be positive)",
    }
  }
  if task.forcings.length() == 0 {
    return {
      task_id,
      basin_name,
      runoff_series: [],
      peak_flow: 0.0,
      peak_time: 0,
      total_volume: 0.0,
      nse: 0.0,
      kge: 0.0,
      pbias: 0.0,
      has_obs: false,
      success: false,
      error_message: "empty forcings",
    }
  }
  let model = XinanjiangModel::new(
    params=task.params,
    area=task.area,
    dt=task.dt,
  )
  let result = model.run(task.forcings)
  let runoff = result.runoff_series
  // 计算洪峰
  let mut peak_flow = 0.0
  let mut peak_time = 0
  for i in 0..<runoff.length() {
    if runoff[i] > peak_flow {
      peak_flow = runoff[i]
      peak_time = i
    }
  }
  // 计算总径流量
  let mut total_volume = 0.0
  for v in runoff {
    total_volume = total_volume + v
  }
  // 评价指标（若有观测）
  let has_obs = task.observed.length() > 0 &&
    task.observed.length() == runoff.length()
  let nse_val = if has_obs { nse(task.observed, runoff) } else { 0.0 }
  let kge_val = if has_obs { kge(task.observed, runoff) } else { 0.0 }
  let pbias_val = if has_obs { pbias(task.observed, runoff) } else { 0.0 }
  {
    task_id,
    basin_name,
    runoff_series: runoff,
    peak_flow,
    peak_time,
    total_volume,
    nse: nse_val,
    kge: kge_val,
    pbias: pbias_val,
    has_obs,
    success: true,
    error_message: "",
  }
}

///|
/// 批量执行仿真任务
///
/// 顺序执行所有任务并聚合结果
pub fn run_batch_sim(tasks : Array[SimTask]) -> BatchSimResult {
  let results : Array[SimTaskResult] = []
  let mut success_count = 0
  let mut failure_count = 0
  let mut total_time_steps = 0
  for task in tasks {
    let result = run_sim_task(task)
    if result.success {
      success_count = success_count + 1
      total_time_steps = total_time_steps + result.runoff_series.length()
    } else {
      failure_count = failure_count + 1
    }
    results.push(result)
  }
  // 汇总统计
  let summary = compute_batch_summary(results)
  {
    results,
    total_tasks: tasks.length(),
    success_count,
    failure_count,
    total_time_steps,
    summary_stats: summary,
  }
}

///|
/// 计算批量仿真汇总统计
fn compute_batch_summary(results : Array[SimTaskResult]) -> BatchSummaryStats {
  let mut nse_sum = 0.0
  let mut kge_sum = 0.0
  let mut pbias_sum = 0.0
  let mut peak_flow_sum = 0.0
  let mut total_volume = 0.0
  let mut best_nse = -1000000000.0
  let mut worst_nse = 1000000000.0
  let mut valid_count = 0
  let mut success_count = 0
  for r in results {
    // P2-9修复：使用has_obs标志替代nse!=0.0过滤
    if r.success && r.has_obs {
      nse_sum = nse_sum + r.nse
      kge_sum = kge_sum + r.kge
      pbias_sum = pbias_sum + r.pbias
      if r.nse > best_nse {
        best_nse = r.nse
      }
      if r.nse < worst_nse {
        worst_nse = r.nse
      }
      valid_count = valid_count + 1
    }
    if r.success {
      peak_flow_sum = peak_flow_sum + r.peak_flow
      total_volume = total_volume + r.total_volume
      success_count = success_count + 1
    }
  }
  let n = valid_count.to_double()
  if n == 0.0 {
    return {
      mean_nse: 0.0,
      mean_kge: 0.0,
      mean_pbias: 0.0,
      best_nse: 0.0,
      worst_nse: 0.0,
      mean_peak_flow: 0.0,
      total_volume: 0.0,
    }
  }
  {
    mean_nse: nse_sum / n,
    mean_kge: kge_sum / n,
    mean_pbias: pbias_sum / n,
    best_nse,
    worst_nse,
    mean_peak_flow: if success_count > 0 {
      peak_flow_sum / success_count.to_double()
    } else {
      0.0
    },
    total_volume,
  }
}

///|
/// 多情景集合仿真
///
/// 对同一流域应用多组参数/气象情景，输出集合仿真结果
pub fn run_ensemble_sim(
  basin_name~ : String,
  params_set : Array[XinanjiangParams],
  area~ : Double,
  dt~ : Double,
  forcings : Array[ForcingData],
  observed? : Array[Double] = [],
) -> BatchSimResult {
  let tasks : Array[SimTask] = []
  for i in 0..<params_set.length() {
    tasks.push({
      task_id: "ensemble_\{i}",
      basin_name,
      params: params_set[i],
      area,
      dt,
      forcings,
      observed,
    })
  }
  run_batch_sim(tasks)
}

///|
/// 参数敏感性扫描
///
/// 对指定参数在范围内等间隔扫描，评估其对仿真结果的影响
pub fn param_sensitivity_scan(
  base_params : XinanjiangParams,
  param_name~ : String,
  lower~ : Double,
  upper~ : Double,
  n_samples~ : Int,
  area~ : Double,
  dt~ : Double,
  forcings : Array[ForcingData],
  observed : Array[Double],
) -> Array[(Double, SimTaskResult)] {
  let results : Array[(Double, SimTaskResult)] = []
  if n_samples <= 0 {
    return results
  }
  for i in 0..<n_samples {
    let param_value = if n_samples == 1 {
      (lower + upper) / 2.0
    } else {
      lower + (upper - lower) * i.to_double() / (n_samples - 1).to_double()
    }
    // 构造扫描参数
    let scan_params = set_xaj_param(base_params, param_name, param_value)
    let task : SimTask = {
      task_id: "scan_\{param_name}_\{i}",
      basin_name: "sensitivity",
      params: scan_params,
      area,
      dt,
      forcings,
      observed,
    }
    let result = run_sim_task(task)
    results.push((param_value, result))
  }
  results
}

///|
/// 设置新安江参数指定字段的值
///
/// 支持所有可率定参数名
pub fn set_xaj_param(
  base : XinanjiangParams,
  name : String,
  value : Double,
) -> XinanjiangParams {
  match name {
    "wm" => { ..base, wm: value }
    "wum" => { ..base, wum: value }
    "wlm" => { ..base, wlm: value }
    "wdm" => { ..base, wdm: value }
    "b" => { ..base, b: value }
    "im" => { ..base, im: value }
    "c" => { ..base, c: value }
    "sm" => { ..base, sm: value }
    "ex" => { ..base, ex: value }
    "kg" => { ..base, kg: value }
    "ki" => { ..base, ki: value }
    "cg" => { ..base, cg: value }
    "ci" => { ..base, ci: value }
    "cs" => { ..base, cs: value }
    "ke" => { ..base, ke: value }
    "x" => { ..base, x: value }
    "y" => { ..base, y: value }
    "fr" => { ..base, fr: value }
    "kg1" => { ..base, kg1: value }
    "ki1" => { ..base, ki1: value }
    "kg2" => { ..base, kg2: value }
    "ki2" => { ..base, ki2: value }
    _ => abort("set_xaj_param: unknown param " + name) // fail-fast：未知参数名暴露配置错误
  }
}

///|
/// 蒙特卡洛不确定性分析
///
/// 在参数范围内随机采样，运行N次仿真，统计输出不确定性
pub fn monte_carlo_uncertainty(
  base_params : XinanjiangParams,
  calib_params : Array[CalibParam],
  n_samples~ : Int,
  area~ : Double,
  dt~ : Double,
  forcings : Array[ForcingData],
  seed? : UInt64 = 42,
) -> MonteCarloResult {
  let rng = @splitmix.new(seed~)
  let peak_flows : Array[Double] = []
  let total_volumes : Array[Double] = []
  let runoff_ensembles : Array[Array[Double]] = []
  for _ in 0..<n_samples {
    // 在参数范围内随机采样
    let mut params = base_params
    for cp in calib_params {
      let random_value = cp.lower + rng.next_double() * (cp.upper - cp.lower)
      params = set_xaj_param(params, cp.name, random_value)
    }
    let model = XinanjiangModel::new(params~, area~, dt~)
    let result = model.run(forcings)
    let runoff = result.runoff_series
    // 洪峰
    let mut peak = 0.0
    for v in runoff {
      if v > peak {
        peak = v
      }
    }
    peak_flows.push(peak)
    // 总量
    let mut vol = 0.0
    for v in runoff {
      vol = vol + v
    }
    total_volumes.push(vol)
    runoff_ensembles.push(runoff)
  }
  // 计算统计量
  let peak_stats = array_stats(peak_flows)
  let vol_stats = array_stats(total_volumes)
  // 计算各时段的分位数
  let n_steps = if runoff_ensembles.length() > 0 {
    runoff_ensembles[0].length()
  } else {
    0
  }
  let p5 : Array[Double] = Array::make(n_steps, 0.0)
  let p50 : Array[Double] = Array::make(n_steps, 0.0)
  let p95 : Array[Double] = Array::make(n_steps, 0.0)
  for t in 0..<n_steps {
    let values : Array[Double] = []
    for ensemble in runoff_ensembles {
      if t < ensemble.length() {
        values.push(ensemble[t])
      }
    }
    values.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
    let n = values.length()
    if n > 0 {
      // S10修复：线性插值分位数，与array_stats的interp逻辑一致
      let interp = fn(p : Double) -> Double {
        let idx = (n - 1).to_double() * p
        let lo = idx.floor().to_int()
        let lo_c = if lo < 0 { 0 } else if lo > n - 1 { n - 1 } else { lo }
        let hi_c = if lo_c + 1 > n - 1 { n - 1 } else { lo_c + 1 }
        let frac = idx - idx.floor()
        values[lo_c] * (1.0 - frac) + values[hi_c] * frac
      }
      p5[t] = interp(0.05)
      p50[t] = interp(0.5)
      p95[t] = interp(0.95)
    }
  }
  {
    n_samples,
    peak_flow_mean: peak_stats.0,
    peak_flow_std: peak_stats.1,
    peak_flow_p5: peak_stats.2,
    peak_flow_p95: peak_stats.3,
    volume_mean: vol_stats.0,
    volume_std: vol_stats.1,
    runoff_p5: p5,
    runoff_p50: p50,
    runoff_p95: p95,
  }
}

///|
/// 蒙特卡洛不确定性分析结果
pub(all) struct MonteCarloResult {
  n_samples : Int // 采样数
  peak_flow_mean : Double // 洪峰均值
  peak_flow_std : Double // 洪峰标准差
  peak_flow_p5 : Double // 洪峰5%分位数
  peak_flow_p95 : Double // 洪峰95%分位数
  volume_mean : Double // 总量均值
  volume_std : Double // 总量标准差
  runoff_p5 : Array[Double] // 各时段5%分位过程
  runoff_p50 : Array[Double] // 各时段中位数过程
  runoff_p95 : Array[Double] // 各时段95%分位过程
} derive(Debug, ToJson, FromJson)

///|
/// 数组统计：返回(均值, 标准差, 5%分位, 95%分位)
fn array_stats(values : Array[Double]) -> (Double, Double, Double, Double) {
  let n = values.length()
  if n == 0 {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let mut sum = 0.0
  for v in values {
    sum = sum + v
  }
  let mean = sum / n.to_double()
  let mut var_sum = 0.0
  for v in values {
    let diff = v - mean
    var_sum = var_sum + diff * diff
  }
  let stddev = if n > 1 {
    @math.pow(var_sum / (n - 1).to_double(), 0.5)
  } else {
    0.0
  }
  // 分位数
  let sorted : Array[Double] = []
  for v in values {
    sorted.push(v)
  }
  sorted.sort_by(fn(a, b) { if a < b { -1 } else if a > b { 1 } else { 0 } })
  // P2-18修复：线性插值替代整数截断，提升小样本分位数精度
  let interp = fn(p : Double) -> Double {
    let idx = (n - 1).to_double() * p
    let lo = idx.floor().to_int()
    let lo_c = if lo < 0 { 0 } else if lo > n - 1 { n - 1 } else { lo }
    let hi_c = if lo_c + 1 > n - 1 { n - 1 } else { lo_c + 1 }
    let frac = idx - idx.floor()
    sorted[lo_c] * (1.0 - frac) + sorted[hi_c] * frac
  }
  let p5 = interp(0.05)
  let p95 = interp(0.95)
  (mean, stddev, p5, p95)
}
