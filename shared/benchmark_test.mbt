///|
/// 基准测试模块测试
test "bench - 基本计时" {
  let result = bench(name="空操作", n_iters=10, fn() { ignore(0) })
  assert_eq(result.name, "空操作")
  assert_eq(result.iterations, 10)
  assert_true(result.mean_ms >= 0.0)
  assert_true(result.ops_per_sec >= 0.0)
}

///|
test "bench - 新安江模型基准" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2", },
  ]
  let result = bench(name="XAJ仿真", n_iters=5, fn() {
    ignore(model.run(forcings))
  })
  assert_eq(result.iterations, 5)
  assert_true(result.total_ms >= 0.0)
  assert_true(result.min_ms <= result.max_ms)
  assert_true(
    result.mean_ms >= result.min_ms && result.mean_ms <= result.max_ms,
  )
}

///|
test "bench - 统计正确性" {
  let result = bench(name="计数操作", n_iters=100, fn() {
    let mut sum = 0
    for i in 0..<100 {
      sum = sum + i
    }
    ignore(sum)
  })
  assert_eq(result.iterations, 100)
  assert_true(result.stddev_ms >= 0.0)
  assert_true(result.total_ms >= 0.0)
}

///|
test "bench_suite - 套件聚合" {
  let r1 = bench(name="测试1", n_iters=5, fn() { ignore(1) })
  let r2 = bench(name="测试2", n_iters=5, fn() { ignore(2) })
  let suite = bench_suite(suite_name="套件", [r1, r2])
  assert_eq(suite.suite_name, "套件")
  assert_eq(suite.results.length(), 2)
  assert_true(suite.total_ms >= 0.0)
}

///|
test "format_bench_result - 格式化输出" {
  let r = bench(name="格式化测试", n_iters=3, fn() { ignore(0) })
  let s = format_bench_result(r)
  assert_true(s.contains("格式化测试"))
  assert_true(s.contains("迭代"))
  assert_true(s.contains("ops/s"))
}

///|
test "run_all_benchmarks - 全量报告" {
  let report = run_all_benchmarks()
  assert_true(report.contains("性能基准测试报告"))
  assert_true(report.contains("新安江模型"))
  assert_true(report.contains("SWE"))
  assert_true(report.contains("SCE-UA"))
  assert_true(report.contains("DDS"))
  assert_true(report.contains("批量仿真"))
  assert_true(report.contains("耦合"))
  assert_true(report.contains("JSON"))
}
