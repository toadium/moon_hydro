///|
/// 任务调度模块
///
/// 提供批量仿真任务调度与进度推送。
/// 复用batch_sim.mbt中的SimTask类型，添加进度跟踪与调度器。
/// 当前为顺序执行（async库不可用），后续可扩展为并行。

///|
/// 任务状态
pub(all) enum TaskStatus {
  Pending // 待执行
  Running // 执行中
  Completed // 已完成
  Failed // 失败
} derive(Debug, ToJson, FromJson, Eq)

///|
/// Show实现
pub impl Show for TaskStatus with fn to_string(self : TaskStatus) -> String {
  match self {
    Pending => "待执行"
    Running => "执行中"
    Completed => "已完成"
    Failed => "失败"
  }
}

///|
/// 任务执行结果（含计时与状态）
pub(all) struct TaskExecResult {
  task_id : String // 任务ID
  success : Bool // 是否成功
  result : SimResult? // 仿真结果
  error : String // 错误信息
  duration_ms : UInt64 // 执行耗时(毫秒)
} derive(Debug, ToJson, FromJson, Default)

///|
/// 进度信息
pub(all) struct ProgressInfo {
  completed : Int // 已完成数
  total : Int // 总数
  current_task_id : String // 当前任务ID
  percentage : Double // 完成百分比
} derive(Debug, ToJson, FromJson, Default)

///|
/// 任务调度器
pub(all) struct TaskScheduler {
  tasks : Array[SimTask] // 任务队列
  results : Array[TaskExecResult] // 执行结果
  status : Map[String, TaskStatus] // 任务状态
} derive(Debug, ToJson, FromJson)

///|
/// 构造空调度器
pub fn TaskScheduler::new() -> TaskScheduler {
  { tasks: [], results: [], status: {} }
}

///|
/// 默认实现
pub impl Default for TaskScheduler with fn default() {
  TaskScheduler::new()
}

///|
/// 添加任务到队列
pub fn TaskScheduler::add_task(self : TaskScheduler, task : SimTask) -> Unit {
  self.tasks.push(task)
  self.status[task.task_id] = Pending
}

///|
/// 批量添加任务
pub fn TaskScheduler::add_tasks(
  self : TaskScheduler,
  tasks : Array[SimTask],
) -> Unit {
  for task in tasks {
    self.add_task(task)
  }
}

///|
/// 获取任务总数
pub fn TaskScheduler::task_count(self : TaskScheduler) -> Int {
  self.tasks.length()
}

///|
/// 获取已完成数
pub fn TaskScheduler::completed_count(self : TaskScheduler) -> Int {
  let mut count = 0
  for _, status in self.status {
    if status is Completed {
      count = count + 1
    }
  }
  count
}

///|
/// 执行单个任务
/// P2-11修复说明：当前model.run()不raise异常，故无需try-catch
/// 若未来扩展引入可能失败的操作（如文件IO），应在此添加异常捕获
pub fn run_task(task : SimTask) -> TaskExecResult {
  let start_time = @env.now()
  if task.forcings.length() == 0 {
    let end_time = @env.now()
    return {
      task_id: task.task_id,
      success: false,
      result: None,
      error: "forcings为空",
      duration_ms: end_time - start_time,
    }
  }
  let model = XinanjiangModel::new(
    params=task.params,
    area=task.area,
    dt=task.dt,
  )
  let result = model.run(task.forcings)
  let end_time = @env.now()
  {
    task_id: task.task_id,
    success: true,
    result: Some(result),
    error: "",
    duration_ms: end_time - start_time,
  }
}

///|
/// 批量执行任务，带进度回调
///
/// progress_callback在每个任务完成后调用
pub fn run_tasks(
  tasks : Array[SimTask],
  progress_callback : (ProgressInfo) -> Unit,
) -> Array[TaskExecResult] {
  let total = tasks.length()
  let results : Array[TaskExecResult] = []
  for i in 0..<total {
    let task = tasks[i]
    let result = run_task(task)
    results.push(result)
    let progress : ProgressInfo = {
      completed: i + 1,
      total,
      current_task_id: task.task_id,
      percentage: if total > 0 {
        (i + 1).to_double() * 100.0 / total.to_double()
      } else {
        0.0
      },
    }
    progress_callback(progress)
  }
  results
}

///|
/// 执行调度器中所有任务
///
/// progress_callback在每个任务完成后调用
pub fn TaskScheduler::run(
  self : TaskScheduler,
  progress_callback : (ProgressInfo) -> Unit,
) -> Unit {
  for task in self.tasks {
    self.status[task.task_id] = Running
    let result = run_task(task)
    self.results.push(result)
    if result.success {
      self.status[task.task_id] = Completed
    } else {
      self.status[task.task_id] = Failed
    }
    let completed = self.completed_count()
    let total = self.tasks.length()
    let progress : ProgressInfo = {
      completed,
      total,
      current_task_id: task.task_id,
      percentage: if total > 0 {
        completed.to_double() * 100.0 / total.to_double()
      } else {
        0.0
      },
    }
    progress_callback(progress)
  }
}

///|
/// 获取所有执行结果
pub fn TaskScheduler::get_results(
  self : TaskScheduler,
) -> Array[TaskExecResult] {
  self.results
}

///|
/// 获取指定任务的状态
pub fn TaskScheduler::get_status(
  self : TaskScheduler,
  task_id : String,
) -> TaskStatus? {
  match self.status.get(task_id) {
    Some(s) => Some(s)
    None => None
  }
}

///|
/// 生成进度报告
pub fn TaskScheduler::progress_report(self : TaskScheduler) -> String {
  let total = self.tasks.length()
  let completed = self.completed_count()
  let mut failed = 0
  for _, status in self.status {
    if status is Failed {
      failed = failed + 1
    }
  }
  let percentage = if total > 0 {
    completed.to_double() * 100.0 / total.to_double()
  } else {
    0.0
  }
  "总数=\{total}, 完成=\{completed}, 失败=\{failed}, 进度=\{percentage}%"
}

///|
/// 从流域案例创建任务
pub fn create_task_from_basin(task_id : String, case : BasinCase) -> SimTask {
  {
    task_id,
    basin_name: case.name,
    params: case.params,
    forcings: case.forcings,
    area: case.area,
    dt: case.dt,
    observed: [],
  }
}

///|
/// 批量创建流域任务
pub fn create_basin_tasks(basins : Array[BasinCase]) -> Array[SimTask] {
  let tasks : Array[SimTask] = []
  for i in 0..<basins.length() {
    tasks.push(create_task_from_basin("task_\{i}", basins[i]))
  }
  tasks
}
