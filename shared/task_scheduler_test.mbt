///|
/// 任务调度模块测试

///|
test "TaskScheduler::new 空调度器" {
  let scheduler = TaskScheduler::new()
  assert_eq(scheduler.task_count(), 0)
  assert_eq(scheduler.completed_count(), 0)
}

///|
test "TaskScheduler::add_task 添加任务" {
  let scheduler = TaskScheduler::new()
  let task : SimTask = {
    task_id: "task_001",
    basin_name: "闽江竹岐",
    params: XinanjiangParams::default(),
    forcings: [{ rainfall: 10.0, evaporation: 2.0, datetime: "t0" }],
    area: 100.0,
    dt: 1.0,
    observed: [],
  }
  scheduler.add_task(task)
  assert_eq(scheduler.task_count(), 1)
  let status = scheduler.get_status("task_001")
  guard status is Some(s) else { fail("任务状态未找到") }
  assert_true(s is Pending)
}

///|
test "run_task 单任务执行" {
  let task : SimTask = {
    task_id: "single_task",
    basin_name: "合成基准",
    params: XinanjiangParams::default(),
    forcings: [
      { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
      { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    ],
    area: 100.0,
    dt: 1.0,
    observed: [],
  }
  let result = run_task(task)
  assert_eq(result.task_id, "single_task")
  assert_true(result.success)
  guard result.result is Some(_) else { fail("仿真结果为空") }
  assert_eq(result.error, "")
}

///|
test "run_tasks 批量执行带进度" {
  let tasks : Array[SimTask] = [
    {
      task_id: "batch_1",
      basin_name: "合成基准",
      params: XinanjiangParams::default(),
      forcings: [{ rainfall: 10.0, evaporation: 2.0, datetime: "t0" }],
      area: 100.0,
      dt: 1.0,
      observed: [],
    },
    {
      task_id: "batch_2",
      basin_name: "合成基准",
      params: XinanjiangParams::default(),
      forcings: [{ rainfall: 20.0, evaporation: 1.0, datetime: "t0" }],
      area: 200.0,
      dt: 2.0,
      observed: [],
    },
    {
      task_id: "batch_3",
      basin_name: "合成基准",
      params: XinanjiangParams::default(),
      forcings: [{ rainfall: 5.0, evaporation: 3.0, datetime: "t0" }],
      area: 50.0,
      dt: 0.5,
      observed: [],
    },
  ]
  let progress_records : Array[ProgressInfo] = []
  let results = run_tasks(tasks, progress => progress_records.push(progress))
  assert_eq(results.length(), 3)
  assert_true(results[0].success)
  assert_true(results[1].success)
  assert_true(results[2].success)
  // 验证进度回调
  assert_eq(progress_records.length(), 3)
  assert_eq(progress_records[0].completed, 1)
  assert_eq(progress_records[0].total, 3)
  assert_true((progress_records[0].percentage - 33.33).abs() < 0.1)
  assert_eq(progress_records[2].completed, 3)
  assert_true((progress_records[2].percentage - 100.0).abs() < 0.001)
}

///|
test "TaskScheduler::run 调度器执行" {
  let scheduler = TaskScheduler::new()
  let tasks : Array[SimTask] = [
    {
      task_id: "sched_1",
      basin_name: "合成基准",
      params: XinanjiangParams::default(),
      forcings: [{ rainfall: 10.0, evaporation: 2.0, datetime: "t0" }],
      area: 100.0,
      dt: 1.0,
      observed: [],
    },
    {
      task_id: "sched_2",
      basin_name: "合成基准",
      params: XinanjiangParams::default(),
      forcings: [{ rainfall: 15.0, evaporation: 1.5, datetime: "t0" }],
      area: 150.0,
      dt: 1.0,
      observed: [],
    },
  ]
  scheduler.add_tasks(tasks)
  let progress_records : Array[ProgressInfo] = []
  scheduler.run(progress => progress_records.push(progress))
  let results = scheduler.get_results()
  assert_eq(results.length(), 2)
  // 验证状态
  let status1 = scheduler.get_status("sched_1")
  guard status1 is Some(s1) else { fail("任务1状态未找到") }
  assert_true(s1 is Completed)
  let status2 = scheduler.get_status("sched_2")
  guard status2 is Some(s2) else { fail("任务2状态未找到") }
  assert_true(s2 is Completed)
  // 验证进度
  assert_eq(progress_records.length(), 2)
  assert_eq(progress_records[1].completed, 2)
}

///|
test "TaskScheduler::progress_report 进度报告" {
  let scheduler = TaskScheduler::new()
  let task : SimTask = {
    task_id: "report_task",
    basin_name: "合成基准",
    params: XinanjiangParams::default(),
    forcings: [{ rainfall: 10.0, evaporation: 2.0, datetime: "t0" }],
    area: 100.0,
    dt: 1.0,
    observed: [],
  }
  scheduler.add_task(task)
  scheduler.run(_ => ())
  let report = scheduler.progress_report()
  assert_true(report.contains("总数=1"))
  assert_true(report.contains("完成=1"))
  assert_true(report.contains("失败=0"))
}

///|
test "create_task_from_basin 从流域案例创建任务" {
  let case = synthetic_benchmark_case()
  let task = create_task_from_basin("basin_task", case)
  assert_eq(task.task_id, "basin_task")
  assert_eq(task.basin_name, case.name)
  assert_true((task.area - case.area).abs() < 0.001)
}

///|
test "create_basin_tasks 批量创建流域任务" {
  let basins : Array[BasinCase] = [
    synthetic_benchmark_case(),
    zhuyi_basin_case(),
  ]
  let tasks = create_basin_tasks(basins)
  assert_eq(tasks.length(), 2)
  assert_eq(tasks[0].task_id, "task_0")
  assert_eq(tasks[1].task_id, "task_1")
}

///|
test "TaskStatus Show实现" {
  assert_eq(TaskStatus::Pending.to_string(), "待执行")
  assert_eq(TaskStatus::Running.to_string(), "执行中")
  assert_eq(TaskStatus::Completed.to_string(), "已完成")
  assert_eq(TaskStatus::Failed.to_string(), "失败")
}
