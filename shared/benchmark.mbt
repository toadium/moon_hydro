///|
/// 性能基准测试模块
///
/// 提供轻量级基准测试框架，测量各算法模块执行耗时。
/// 使用 @env.now() 获取时间戳，统计均值/最小/最大/标准差/吞吐量。

///|
/// 单次基准测试结果
pub(all) struct BenchResult {
  name : String // 测试名称
  iterations : Int // 迭代次数
  total_ms : Double // 总耗时(ms)
  mean_ms : Double // 平均耗时(ms)
  min_ms : Double // 最小耗时(ms)
  max_ms : Double // 最大耗时(ms)
  stddev_ms : Double // 标准差(ms)
  ops_per_sec : Double // 每秒操作数
}

///|
/// 基准测试套件结果
pub(all) struct BenchSuiteResult {
  suite_name : String
  results : Array[BenchResult]
  total_ms : Double
}

///|
/// 运行单次基准测试
///
/// 重复执行 fn n_iters 次，统计耗时
pub fn bench(name~ : String, n_iters~ : Int, f : () -> Unit) -> BenchResult {
  if n_iters <= 0 {
    return {
      name,
      iterations: n_iters,
      total_ms: 0.0,
      mean_ms: 0.0,
      min_ms: 0.0,
      max_ms: 0.0,
      stddev_ms: 0.0,
      ops_per_sec: 0.0,
    }
  }
  let times : Array[Double] = []
  for _ in 0..<n_iters {
    let start = @env.now()
    f()
    let elapsed = (@env.now() - start).to_double() / 1_000_000.0
    times.push(elapsed)
  }
  // 统计
  let mut sum = 0.0
  let mut min_val = times[0]
  let mut max_val = times[0]
  for t in times {
    sum = sum + t
    if t < min_val {
      min_val = t
    }
    if t > max_val {
      max_val = t
    }
  }
  let mean = sum / n_iters.to_double()
  let mut var_sum = 0.0
  for t in times {
    let diff = t - mean
    var_sum = var_sum + diff * diff
  }
  let stddev = if n_iters > 1 {
    @math.pow(var_sum / (n_iters - 1).to_double(), 0.5)
  } else {
    0.0
  }
  let ops = if sum > 0.0 { 1000.0 * n_iters.to_double() / sum } else { 0.0 }
  {
    name,
    iterations: n_iters,
    total_ms: sum,
    mean_ms: mean,
    min_ms: min_val,
    max_ms: max_val,
    stddev_ms: stddev,
    ops_per_sec: ops,
  }
}

///|
/// 运行基准测试套件
pub fn bench_suite(
  suite_name~ : String,
  benchmarks : Array[BenchResult],
) -> BenchSuiteResult {
  let mut total = 0.0
  for r in benchmarks {
    total = total + r.total_ms
  }
  { suite_name, results: benchmarks, total_ms: total, }
}

///|
/// 格式化基准测试结果为字符串
pub fn format_bench_result(r : BenchResult) -> String {
  let mut s = "\{r.name}:\n"
  s = s + "  迭代: \{r.iterations}, 总耗时: \{r.total_ms}ms\n"
  s = s +
    "  均值: \{r.mean_ms}ms, 最小: \{r.min_ms}ms, 最大: \{r.max_ms}ms\n"
  s = s + "  标准差: \{r.stddev_ms}ms, 吞吐: \{r.ops_per_sec} ops/s"
  s
}

///|
/// 格式化套件结果为字符串
pub fn format_bench_suite(sr : BenchSuiteResult) -> String {
  let mut s = "===== \{sr.suite_name} =====\n"
  for r in sr.results {
    s = s + format_bench_result(r) + "\n\n"
  }
  s = s + "套件总耗时: \{sr.total_ms}ms"
  s
}

///|
/// 运行全部基准测试并输出报告
pub fn run_all_benchmarks() -> String {
  let mut report = "沐澜水文 性能基准测试报告\n"
  report = report + "========================\n\n"

  // 1. 新安江模型
  let xaj_model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let xaj_forcings : Array[ForcingData] = []
  for i in 0..<100 {
    let r = if i < 20 {
      20.0 - i.to_double()
    } else if i < 50 {
      5.0
    } else {
      0.0
    }
    xaj_forcings.push({ rainfall: r, evaporation: 1.0, datetime: "t\{i}", })
  }
  let xaj_bench = bench(name="新安江模型仿真(100步)", n_iters=50, fn() {
    ignore(xaj_model.run(xaj_forcings))
  })
  report = report + format_bench_result(xaj_bench) + "\n\n"

  // 2. 1D SWE
  let swe_grid = SWEGrid1D::uniform(nx=100, dx=1.0, h0=1.0)
  let swe_config : SWESolverConfig = {
    dt: 0.01,
    n_steps: 100,
    cfl: 0.4,
    boundary: {
      left: SWEBoundaryType::SolidWall,
      right: SWEBoundaryType::Transmissive,
    },
  }
  let swe_bench = bench(name="1D SWE求解(100单元x100步)", n_iters=30, fn() {
    ignore(swe_grid.run(swe_config))
  })
  report = report + format_bench_result(swe_bench) + "\n\n"

  // 3. 2D SWE
  let grid2d = SWEGrid2D::uniform(nx=30, ny=30, dx=1.0, dy=1.0, h0=0.1)
  ignore(grid2d.set_block(i0=0, i1=15, j0=0, j1=30, h_value=2.0))
  let config2d : SWE2DSolverConfig = {
    dt: 0.005,
    n_steps: 50,
    cfl: 0.3,
    boundary: SWE2DBoundary::SolidWall,
  }
  let swe2d_bench = bench(name="2D SWE求解(30x30网格x50步)", n_iters=20, fn() {
    ignore(grid2d.run(config2d))
  })
  report = report + format_bench_result(swe2d_bench) + "\n\n"

  // 4. SCE-UA率定
  let obs = xaj_model.run(xaj_forcings).runoff_series
  let sceua_cfg : SCEUAConfig = {
    max_iter: 30,
    n_complexes: 3,
    complex_size: 0,
    cce_iterations: 0,
    seed: 42,
    target_metric: "nse",
    params: default_calib_params(),
    convergence_threshold: 0.000001,
    max_no_improve: 15,
  }
  let sceua_bench = bench(name="SCE-UA率定(11参数x30迭代)", n_iters=5, fn() {
    ignore(sceua_calibrate(sceua_cfg, area=100.0, dt=1.0, xaj_forcings, obs))
  })
  report = report + format_bench_result(sceua_bench) + "\n\n"

  // 5. DDS率定
  let dds_cfg : DDSConfig = {
    max_iter: 30,
    r: 0.2,
    seed: 42,
    target_metric: "nse",
    params: default_calib_params(),
    max_no_improve: 100,
  }
  let dds_bench = bench(name="DDS率定(11参数x30迭代)", n_iters=5, fn() {
    ignore(dds_calibrate(dds_cfg, area=100.0, dt=1.0, xaj_forcings, obs))
  })
  report = report + format_bench_result(dds_bench) + "\n\n"

  // 6. 批量仿真
  let batch_tasks : Array[SimTask] = []
  for i in 0..<10 {
    batch_tasks.push({
      task_id: "b\{i}",
      basin_name: "流域\{i}",
      params: XinanjiangParams::default(),
      area: 100.0 + i.to_double() * 10.0,
      dt: 1.0,
      forcings: xaj_forcings,
      observed: obs,
    })
  }
  let batch_bench = bench(name="批量仿真(10流域x100步)", n_iters=10, fn() {
    ignore(run_batch_sim(batch_tasks))
  })
  report = report + format_bench_result(batch_bench) + "\n\n"

  // 7. 耦合仿真
  let coupling_params : CouplingParams = {
    lateral_inflow_coeff: 0.8,
    feedback_coeff: 0.01,
    cell_area: 100.0,
    river_cells: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    base_flow_threshold: 0.3,
  }
  let swe_boundary : SWEBoundary = {
    left: SWEBoundaryType::SolidWall,
    right: SWEBoundaryType::Transmissive,
  }
  let coup_grid = SWEGrid1D::uniform(nx=50, dx=1.0, h0=0.5)
  let coup_forcings : Array[ForcingData] = []
  for i in 0..<20 {
    coup_forcings.push({ rainfall: 15.0, evaporation: 1.0, datetime: "t\{i}", })
  }
  let coup_bench = bench(name="耦合仿真(20步)", n_iters=20, fn() {
    ignore(
      couple_run(
        xaj_model, coup_grid, coupling_params, swe_boundary, coup_forcings, 0.005,
      ),
    )
  })
  report = report + format_bench_result(coup_bench) + "\n\n"

  // 8. 评价指标（修复：含合理偏差而非平凡完美匹配，使评价函数执行全部计算分支）
  let sim = obs.map(fn(v) { v * 1.1 + 0.5 })
  let eval_bench = bench(name="扩展评价指标(100点)", n_iters=100, fn() {
    ignore(evaluate_extended(obs, sim))
  })
  report = report + format_bench_result(eval_bench) + "\n\n"

  // 9. 蒙特卡洛
  let mc_forcings : Array[ForcingData] = []
  for i in 0..<20 {
    mc_forcings.push({ rainfall: 10.0, evaporation: 1.0, datetime: "t\{i}", })
  }
  let mc_bench = bench(name="蒙特卡洛不确定性(20采样)", n_iters=3, fn() {
    ignore(
      monte_carlo_uncertainty(
        XinanjiangParams::default(),
        default_calib_params(),
        n_samples=20,
        area=100.0,
        dt=1.0,
        mc_forcings,
        seed=42,
      ),
    )
  })
  report = report + format_bench_result(mc_bench) + "\n\n"

  // 10. JSON序列化
  let xaj_req : XajRunRequest = {
    params: XinanjiangParams::default(),
    area: 100.0,
    dt: 1.0,
    forcings: xaj_forcings,
    observed: [],
  }
  let json_bench = bench(name="JSON序列化(100步请求)", n_iters=100, fn() {
    ignore(to_json_string(xaj_req))
  })
  report = report + format_bench_result(json_bench) + "\n\n"

  report = report + "========================\n"
  report = report + "基准测试完成"
  report
}
