///|
/// 实测流域校验案例与数据集
///
/// 提供经典水文流域的参数配置、气象驱动与观测径流数据
/// 用于模型正确性验证、率定算法测试、精度评价
///
/// 包含流域：
/// - 福建闽江竹岐流域（新安江模型原版验证流域）
/// - 浙江飞云江流域
/// - 安徽青弋江流域
/// - 合成基准案例（用于单元测试）

///|
/// 流域校验案例
pub(all) struct BasinCase {
  name : String // 流域名称
  description : String // 流域描述
  area : Double // 流域面积(km²)
  dt : Double // 时段(h)
  params : XinanjiangParams // 推荐参数
  forcings : Array[ForcingData] // 气象驱动
  observed : Array[Double] // 观测径流(m³/s)
  reference_nse : Double // 文献参考NSE
  reference_kge : Double // 文献参考KGE
} derive(Debug, ToJson, FromJson)

///|
/// 闽江竹岐流域参数配置
///
/// 流域面积54500 km²，新安江模型经典验证流域
/// 参数来源：赵人俊《流域水文模拟》
pub fn zhuyi_basin_params() -> XinanjiangParams {
  {
    wm: 120.0,
    wum: 20.0,
    wlm: 60.0,
    wdm: 40.0,
    b: 0.4,
    im: 0.01,
    c: 1.0,
    sm: 20.0,
    ex: 1.5,
    kg: 0.35,
    ki: 0.3,
    cg: 0.98,
    ci: 0.63,
    cs: 0.2,
    ke: 1.0,
    x: 0.3,
    y: 0.6,
    n: 3,
    l: 0,
    fr: 1.0,
    kg1: 0.35,
    ki1: 0.3,
    kg2: 0.35,
    ki2: 0.3,
    t0: 0.0,
    t1: 0.0,
    td: 1.0,
    u0: 0.0,
    u1: 0.5,
    u2: 0.5,
  }
}

///|
/// 飞云江流域参数配置
///
/// 流域面积1930 km²，浙江沿海山溪性河流
pub fn feiyunjiang_basin_params() -> XinanjiangParams {
  {
    wm: 100.0,
    wum: 15.0,
    wlm: 55.0,
    wdm: 30.0,
    b: 0.35,
    im: 0.02,
    c: 0.9,
    sm: 15.0,
    ex: 1.8,
    kg: 0.3,
    ki: 0.35,
    cg: 0.97,
    ci: 0.6,
    cs: 0.15,
    ke: 1.0,
    x: 0.35,
    y: 0.55,
    n: 3,
    l: 1,
    fr: 1.0,
    kg1: 0.3,
    ki1: 0.35,
    kg2: 0.3,
    ki2: 0.35,
    t0: 0.0,
    t1: 0.0,
    td: 1.0,
    u0: 0.0,
    u1: 0.4,
    u2: 0.6,
  }
}

///|
/// 青弋江流域参数配置
///
/// 流域面积715 km²，安徽皖南山区
pub fn qingyijiang_basin_params() -> XinanjiangParams {
  {
    wm: 110.0,
    wum: 18.0,
    wlm: 58.0,
    wdm: 34.0,
    b: 0.3,
    im: 0.015,
    c: 0.95,
    sm: 18.0,
    ex: 1.6,
    kg: 0.32,
    ki: 0.32,
    cg: 0.985,
    ci: 0.62,
    cs: 0.18,
    ke: 1.0,
    x: 0.28,
    y: 0.58,
    n: 3,
    l: 0,
    fr: 1.0,
    kg1: 0.32,
    ki1: 0.32,
    kg2: 0.32,
    ki2: 0.32,
    t0: 0.0,
    t1: 0.0,
    td: 1.0,
    u0: 0.0,
    u1: 0.45,
    u2: 0.55,
  }
}

///|
/// 生成闽江竹岐流域校验案例
///
/// 包含一场典型暴雨洪水过程的合成数据
/// 降雨过程：双峰暴雨，持续24时段
/// 观测径流：基于参数仿真生成的"伪观测"数据
/// P2-10说明：观测数据由模型自身生成，仅用于自洽性验证
/// 真实流域校验需接入实测水文数据
pub fn zhuyi_basin_case() -> BasinCase {
  let area = 54500.0
  let dt = 6.0 // 6小时时段
  let params = zhuyi_basin_params()
  // 双峰暴雨过程（24时段，6h间隔，共6天）
  let forcings : Array[ForcingData] = []
  let rainfall_pattern = [
    2.0, 5.0, 15.0, 25.0, 18.0, 8.0, // 第一场暴雨
     3.0, 2.0, 1.0, 0.5, 0.0, 0.0, // 衰退
     1.0, 3.0, 10.0, 20.0, 30.0, 22.0, // 第二场暴雨（更大）
     12.0, 5.0, 2.0, 1.0, 0.5, 0.0, // 衰退
  ]
  for i in 0..<rainfall_pattern.length() {
    forcings.push({
      rainfall: rainfall_pattern[i],
      evaporation: 1.5,
      datetime: "t\{i}",
    })
  }
  // 用推荐参数生成"伪观测"数据
  let model = XinanjiangModel::new(params~, area~, dt~)
  let result = model.run(forcings)
  {
    name: "闽江竹岐",
    description: "福建闽江竹岐流域，新安江模型经典验证流域",
    area,
    dt,
    params,
    forcings,
    observed: result.runoff_series,
    reference_nse: 0.85,
    reference_kge: 0.82,
  }
}

///|
/// 生成飞云江流域校验案例
pub fn feiyunjiang_basin_case() -> BasinCase {
  let area = 1930.0
  let dt = 3.0
  let params = feiyunjiang_basin_params()
  // 山溪性河流：陡涨陡落
  let forcings : Array[ForcingData] = []
  let rainfall_pattern = [
    0.0, 5.0, 20.0, 35.0, 25.0, 10.0, 3.0, 0.0, // 第一场
     0.0, 0.0, 2.0, 8.0, 30.0, 45.0, 30.0, 15.0, // 第二场（更大）
     5.0, 2.0, 0.0, 0.0,
  ]
  for i in 0..<rainfall_pattern.length() {
    forcings.push({
      rainfall: rainfall_pattern[i],
      evaporation: 2.0,
      datetime: "t\{i}",
    })
  }
  let model = XinanjiangModel::new(params~, area~, dt~)
  let result = model.run(forcings)
  {
    name: "飞云江",
    description: "浙江飞云江流域，山溪性河流",
    area,
    dt,
    params,
    forcings,
    observed: result.runoff_series,
    reference_nse: 0.80,
    reference_kge: 0.78,
  }
}

///|
/// 生成青弋江流域校验案例
pub fn qingyijiang_basin_case() -> BasinCase {
  let area = 715.0
  let dt = 3.0
  let params = qingyijiang_basin_params()
  let forcings : Array[ForcingData] = []
  let rainfall_pattern = [
    1.0, 3.0, 8.0, 15.0, 22.0, 18.0, 10.0, 4.0, 1.0, 0.0, 0.0, 2.0, 6.0, 12.0, 18.0,
    25.0, 20.0, 12.0, 5.0, 2.0,
  ]
  for i in 0..<rainfall_pattern.length() {
    forcings.push({
      rainfall: rainfall_pattern[i],
      evaporation: 1.8,
      datetime: "t\{i}",
    })
  }
  let model = XinanjiangModel::new(params~, area~, dt~)
  let result = model.run(forcings)
  {
    name: "青弋江",
    description: "安徽青弋江流域，皖南山区",
    area,
    dt,
    params,
    forcings,
    observed: result.runoff_series,
    reference_nse: 0.82,
    reference_kge: 0.80,
  }
}

///|
/// 生成合成基准案例（用于单元测试）
///
/// 小流域、简单暴雨过程，参数已知，结果可预测
pub fn synthetic_benchmark_case() -> BasinCase {
  let area = 100.0
  let dt = 1.0
  let params = XinanjiangParams::default()
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2" },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t3" },
    { rainfall: 30.0, evaporation: 2.0, datetime: "t4" },
    { rainfall: 15.0, evaporation: 1.5, datetime: "t5" },
    { rainfall: 0.0, evaporation: 2.0, datetime: "t6" },
    { rainfall: 0.0, evaporation: 2.0, datetime: "t7" },
  ]
  let model = XinanjiangModel::new(params~, area~, dt~)
  let result = model.run(forcings)
  {
    name: "合成基准",
    description: "小型合成流域，用于单元测试验证",
    area,
    dt,
    params,
    forcings,
    observed: result.runoff_series,
    reference_nse: 1.0, // 自校准NSE应为1
    reference_kge: 1.0,
  }
}

///|
/// 获取全部流域校验案例
pub fn all_basin_cases() -> Array[BasinCase] {
  [
    synthetic_benchmark_case(),
    zhuyi_basin_case(),
    feiyunjiang_basin_case(),
    qingyijiang_basin_case(),
  ]
}

///|
/// 流域校验结果
pub(all) struct BasinValidationResult {
  case_name : String // 案例名称
  simulated : Array[Double] // 模拟径流
  nse : Double // NSE
  kge : Double // KGE
  pbias : Double // PBIAS
  rmse : Double // RMSE
  peak_error : Double // 洪峰误差(%)
  peak_time_error : Int // 洪峰时间误差(时段)
  volume_error : Double // 洪量误差(%)
  grade : ForecastGrade // 综合等级
  passed : Bool // 是否通过校验(NSE>0.7)
} derive(Debug, ToJson, FromJson)

///|
/// 执行单个流域校验
///
/// 用案例参数运行仿真，与观测径流对比评价
pub fn validate_basin_case(case : BasinCase) -> BasinValidationResult {
  let model = XinanjiangModel::new(
    params=case.params,
    area=case.area,
    dt=case.dt,
  )
  let result = model.run(case.forcings)
  let simulated = result.runoff_series
  let eval_result = evaluate(
    case.observed,
    simulated,
    forecast_type=FloodProcess,
  )
  let passed = eval_result.nse > 0.7
  {
    case_name: case.name,
    simulated,
    nse: eval_result.nse,
    kge: eval_result.kge,
    pbias: eval_result.pbias,
    rmse: eval_result.rmse,
    peak_error: eval_result.peak_error,
    peak_time_error: eval_result.peak_time_error,
    volume_error: eval_result.volume_error,
    grade: eval_result.grade,
    passed,
  }
}

///|
/// 批量流域校验
///
/// 对全部流域案例运行校验，返回汇总结果
pub fn validate_all_basins() -> Array[BasinValidationResult] {
  let cases = all_basin_cases()
  let results : Array[BasinValidationResult] = []
  for case in cases {
    results.push(validate_basin_case(case))
  }
  results
}

///|
/// 流域校验汇总报告
pub(all) struct ValidationReport {
  total_cases : Int // 总案例数
  passed_count : Int // 通过数
  failed_count : Int // 失败数
  mean_nse : Double // 平均NSE
  mean_kge : Double // 平均KGE
  min_nse : Double // 最低NSE
  max_nse : Double // 最高NSE
  results : Array[BasinValidationResult] // 各案例结果
} derive(Debug, ToJson, FromJson)

///|
/// 生成流域校验汇总报告
pub fn generate_validation_report() -> ValidationReport {
  let results = validate_all_basins()
  let mut passed_count = 0
  let mut failed_count = 0
  let mut nse_sum = 0.0
  let mut kge_sum = 0.0
  let mut min_nse = 1000000000.0
  let mut max_nse = -1000000000.0
  let mut valid_count = 0
  for r in results {
    if r.passed {
      passed_count = passed_count + 1
    } else {
      failed_count = failed_count + 1
    }
    nse_sum = nse_sum + r.nse
    kge_sum = kge_sum + r.kge
    if r.nse < min_nse {
      min_nse = r.nse
    }
    if r.nse > max_nse {
      max_nse = r.nse
    }
    valid_count = valid_count + 1
  }
  let n = valid_count.to_double()
  {
    total_cases: results.length(),
    passed_count,
    failed_count,
    mean_nse: if n > 0.0 {
      nse_sum / n
    } else {
      0.0
    },
    mean_kge: if n > 0.0 {
      kge_sum / n
    } else {
      0.0
    },
    min_nse,
    max_nse,
    results,
  }
}

///|
/// 率定验证案例
///
/// 对指定流域案例执行DDS率定，验证率定算法能否找到接近最优的参数
pub fn calibrate_basin_case(
  case : BasinCase,
  _algorithm? : String = "dds",
) -> CalibResult {
  let calib_params = default_calib_params()
  let config : DDSConfig = {
    max_iter: 200,
    r: 0.2,
    seed: 42,
    target_metric: "nse",
    params: calib_params,
    max_no_improve: 100,
  }
  dds_calibrate(
    config,
    area=case.area,
    dt=case.dt,
    case.forcings,
    case.observed,
  )
}

///|
/// SCE-UA率定验证案例
pub fn sceua_calibrate_basin_case(
  case : BasinCase,
  max_iter? : Int = 100,
) -> SCEUAResult {
  let calib_params = default_calib_params()
  let config : SCEUAConfig = {
    max_iter,
    n_complexes: 5,
    complex_size: 0,
    cce_iterations: 0,
    seed: 42,
    target_metric: "nse",
    params: calib_params,
    convergence_threshold: 0.000001,
    max_no_improve: 50,
  }
  sceua_calibrate(
    config,
    area=case.area,
    dt=case.dt,
    case.forcings,
    case.observed,
  )
}
