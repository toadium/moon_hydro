///|
/// 视图布局与组件描述(View)
///
/// 纯数据结构描述UI布局，不依赖具体渲染框架
/// 后续接入Rui时可将ViewNode转换为Rui组件树
/// 当前用于生成文本报表与JSON可视化

///|
/// 视图节点类型
pub(all) enum ViewNode {
  // 容器
  VDiv(Array[ViewNode]) // div容器
  VSection(String, Array[ViewNode]) // 带标题的section
  VRow(Array[ViewNode]) // 水平行
  VColumn(Array[ViewNode]) // 垂直列
  // 内容
  VText(String) // 文本
  VHeading(Int, String) // 标题(level, text)
  VLabel(String, String) // 标签值对
  VTable(Array[String], Array[Array[String]]) // 表格(表头, 数据行)
  VChart(ChartType, Array[Double], Array[Double]) // 图表(类型, x, y)
  VButton(String, Msg) // 按钮(文本, 点击消息)
  VInput(String, String) // 输入框(标签, 值)
  VSelect(String, Array[String], Int) // 下拉选择(标签, 选项, 当前索引)
  // 状态
  VLoading(String) // 加载中(提示)
  VError(String) // 错误(信息)
  VEmpty // 空节点
} derive(Debug, ToJson, FromJson)

///|
/// 主视图函数：Model -> View
///
///?根据当前模型状态生成完整页面布局
pub fn view(model : AppModel) -> ViewNode {
  match model.ui_state.current_page {
    HomePage => view_home(model)
    SimPage => view_simulation(model)
    CalibPage => view_calibration(model)
    EvalPage => view_evaluation(model)
    BatchPage => view_batch(model)
    SettingsPage => view_settings(model)
  }
}

///|
/// 首页视图
fn view_home(model : AppModel) -> ViewNode {
  VSection("沐澜水文 - 分布式洪水智能预报系统", [
    VHeading(2, "系统概览"),
    VText("基于MoonBit全栈多后端架构"),
    VText("新安江模型 + 浅水方程水动力耦合"),
    VHeading(3, "快速入口"),
    VRow([
      VButton("仿真", NavigateTo(SimPage)),
      VButton("率定", NavigateTo(CalibPage)),
      VButton("评价", NavigateTo(EvalPage)),
      VButton("批量", NavigateTo(BatchPage)),
    ]),
    VHeading(3, "最近历史"),
    view_history(model.history),
  ])
}

///|
/// 仿真页视图
fn view_simulation(model : AppModel) -> ViewNode {
  let sim = model.sim_params
  let result = model.sim_result
  // P1-2修复：函数式构建子节点列表，无push副作用
  let base_children : Array[ViewNode] = [
    VHeading(2, "新安江模型仿真"),
    VLabel("流域名称", sim.basin_name),
    VLabel("流域面积", "\{sim.area} km²"),
    VLabel("计算时段", "\{sim.dt} h"),
    VRow([
      VButton("运行仿真", RunSimulation),
      VButton("加载案例", LoadBasinCase(model.ui_state.selected_basin)),
      VButton("参数面板", ToggleParamsPanel),
    ]),
  ]
  let params_node = if model.ui_state.show_params_panel {
    [view_params_panel(sim.params)]
  } else {
    []
  }
  let result_node = if result.has_result {
    [view_sim_result(result)]
  } else {
    []
  }
  let loading_node = if result.is_running {
    [VLoading("仿真运行中...")]
  } else {
    []
  }
  let error_node = if model.error_message.length() > 0 {
    [VError(model.error_message)]
  } else {
    []
  }
  VSection(
    "仿真",
    base_children + params_node + result_node + loading_node + error_node,
  )
}

///|
/// 参数面板视图
fn view_params_panel(params : @shared.XinanjiangParams) -> ViewNode {
  VSection("新安江参数", [
    VTable(["参数", "值", "说明"], [
      ["wm", "\{params.wm}", "流域平均张力水蓄水容量(mm)"],
      ["wum", "\{params.wum}", "上层张力水蓄水容量(mm)"],
      ["wlm", "\{params.wlm}", "下层张力水蓄水容量(mm)"],
      ["wdm", "\{params.wdm}", "深层张力水蓄水容量(mm)"],
      ["b", "\{params.b}", "蓄水容量曲线指数"],
      ["im", "\{params.im}", "不透水面积比例"],
      ["c", "\{params.c}", "蒸散发系数"],
      ["sm", "\{params.sm}", "流域平均自由水蓄水容量(mm)"],
      ["ex", "\{params.ex}", "自由水容量曲线指数"],
      ["kg", "\{params.kg}", "地下水消退系数"],
      ["ki", "\{params.ki}", "壤中流消退系数"],
      ["cg", "\{params.cg}", "地下水汇流消退系数"],
      ["ci", "\{params.ci}", "壤中流汇流消退系数"],
      ["cs", "\{params.cs}", "地表水汇流消退系数"],
    ]),
  ])
}

///|
/// 仿真结果视图
fn view_sim_result(result : SimResultState) -> ViewNode {
  VSection("仿真结果", [
    VLabel("洪峰流量", "\{result.peak_flow} m³/s"),
    VLabel("洪峰时段", "\{result.peak_time}"),
    VLabel("NSE", "\{result.nse}"),
    VLabel("KGE", "\{result.kge}"),
    VLabel("PBIAS", "\{result.pbias}%"),
    VHeading(3, "径流过程"),
    VChart(Hydrograph, [], result.runoff_series),
  ])
}

///|
/// 率定页视图
fn view_calibration(model : AppModel) -> ViewNode {
  let result = model.sim_result
  // P3修复：率定完成后显示结果，参照view_evaluation模式
  let calib_result_node = if result.calib_metric.length() > 0 {
    [
      VHeading(3, "率定结果"),
      VLabel("率定指标", result.calib_metric),
      VLabel("最优值", "\{result.calib_value}"),
    ]
  } else {
    []
  }
  VSection(
    "参数率定",
    [
      VHeading(2, "全局优化算法"),
      VRow([
        VButton("DDS率定", StartCalibration("dds")),
        VButton("SCE-UA率定", StartCalibration("sceua")),
      ]),
      VLabel("当前流域", model.sim_params.basin_name),
      VText("DDS: 动态维度搜索，适合高维参数空间"),
      VText("SCE-UA: 洗牌复形进化，全局收敛性好"),
    ] +
    calib_result_node,
  )
}

///|
/// 评价页视图
fn view_evaluation(model : AppModel) -> ViewNode {
  // P3修复：读取评价专用字段eval_nse/eval_kge/eval_pbias
  let r = model.sim_result
  VSection("评价指标", [
    VHeading(2, "GB/T 22482预报等级判定"),
    VLabel("NSE", "\{r.eval_nse}"),
    VLabel("KGE", "\{r.eval_kge}"),
    VLabel("PBIAS", "\{r.eval_pbias}%"),
    VText("等级标准："),
    VText("  甲等: NSE≥0.9, |PBIAS|≤5%"),
    VText("  乙等: NSE≥0.7, |PBIAS|≤10%"),
    VText("  丙等: NSE≥0.5, |PBIAS|≤20%"),
  ])
}

///|
/// 批量页视图
fn view_batch(model : AppModel) -> ViewNode {
  // P3修复：显示batch_summary（当非空时）
  let batch_result_node = if model.sim_result.batch_summary.length() > 0 {
    [VHeading(3, "批量结果"), VText(model.sim_result.batch_summary)]
  } else {
    []
  }
  VSection(
    "批量仿真",
    [
      VHeading(2, "多流域批量调度"),
      VButton("运行全部流域", RunBatchSim([])), // P3-6：占位，V1.0改为加载实际流域任务
      VText("支持多流域、多情景集合批量仿真"),
      VText("含蒙特卡洛不确定性分析"),
    ] +
    batch_result_node,
  )
}

///|
/// 设置页视图
fn view_settings(model : AppModel) -> ViewNode {
  VSection("设置", [
    VHeading(2, "系统设置"),
    VLabel("当前页面", "\{model.ui_state.current_page}"),
    VLabel("选中流域", model.ui_state.selected_basin),
    VButton("重置", ResetToDefault),
    VButton("清空历史", ClearHistory),
  ])
}

///|
/// 历史记录视图
fn view_history(history : Array[HistoryEntry]) -> ViewNode {
  if history.length() == 0 {
    return VText("暂无历史记录")
  }
  let headers = ["时间", "操作", "流域", "状态"]
  // P1-2修复：使用map函数式构建行数据，无push副作用
  let rows = history.map(fn(h) {
    [
      h.timestamp,
      h.action,
      h.basin_name,
      if h.success {
        "成功"
      } else {
        "失败"
      },
    ]
  })
  VTable(headers, rows)
}

///|
/// 视图序列化为文本报表
///
/// 用于CLI输出或调试
pub fn view_to_text(node : ViewNode) -> String {
  let sb = StringBuilder()
  render_text(sb, node, 0)
  sb.to_string()
}

///|
/// 递归渲染视图为文本
fn render_text(sb : StringBuilder, node : ViewNode, indent : Int) -> Unit {
  let prefix = String::make(indent * 2, ' ')
  match node {
    VDiv(children) =>
      for c in children {
        render_text(sb, c, indent)
      }
    VSection(title, children) => {
      sb <+ "\{prefix}## \{title}\n"
      for c in children {
        render_text(sb, c, indent + 1)
      }
    }
    VRow(children) => {
      sb <+ "\{prefix}"
      for c in children {
        render_inline(sb, c)
        sb <+ "  "
      }
      sb <+ "\n"
    }
    VColumn(children) =>
      for c in children {
        render_text(sb, c, indent)
      }
    VText(text) => sb <+ "\{prefix}\{text}\n"
    VHeading(level, text) => {
      // P2-50修复：level <= 0 时钳制为1，避免无"#"前缀的异常输出
      let safe_level = if level < 1 { 1 } else { level }
      let hashes = String::make(safe_level, '#')
      sb <+ "\{prefix}\{hashes} \{text}\n"
    }
    VLabel(label, value) => sb <+ "\{prefix}- \{label}: \{value}\n"
    VTable(headers, rows) => {
      // P2-49修复：转义单元格中的"|"避免破坏Markdown表格
      let escape_cell = fn(s : String) -> String { s.replace(old="|", new="/") }
      // 表头
      sb <+ "\{prefix}| "
      for h in headers {
        sb <+ "\{escape_cell(h)} | "
      }
      sb <+ "\n"
      // 分隔行
      sb <+ "\{prefix}|"
      for _ in headers {
        sb <+ "---|"
      }
      sb <+ "\n"
      // 数据行
      for row in rows {
        sb <+ "\{prefix}| "
        for cell in row {
          sb <+ "\{escape_cell(cell)} | "
        }
        sb <+ "\n"
      }
    }
    VChart(ct, _x, y) =>
      sb <+ "\{prefix}[图表: \{ct}] 数据点数=\{y.length()}\n"
    VButton(text, _msg) => sb <+ "\{prefix}[按钮: \{text}]\n"
    VInput(label, value) => sb <+ "\{prefix}[输入: \{label}=\{value}]\n"
    VSelect(label, options, idx) => {
      let current = if idx >= 0 && idx < options.length() {
        options[idx]
      } else {
        ""
      }
      sb <+ "\{prefix}[选择: \{label}=\{current}]\n"
    }
    VLoading(msg) => sb <+ "\{prefix}[加载中] \{msg}\n"
    VError(msg) => sb <+ "\{prefix}[错误] \{msg}\n"
    VEmpty => ()
  }
}

///|
/// 内联渲染（用于行内元素）
fn render_inline(sb : StringBuilder, node : ViewNode) -> Unit {
  match node {
    VText(text) => sb <+ "\{text}"
    VButton(text, _) => sb <+ "[\{text}]"
    VLabel(label, value) => sb <+ "\{label}=\{value}"
    _ => ()
  }
}
