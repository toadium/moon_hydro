///|
/// CLI白盒测试 - 测试各子命令函数

///|
test "cli_sim 仿真子命令" {
  let result = cli_sim()
  assert_true(result.success)
  assert_eq(result.command, "sim")
}

///|
test "cli_calibrate 率定子命令" {
  let result = cli_calibrate()
  assert_true(result.success)
  assert_eq(result.command, "calibrate")
}

///|
test "cli_dds DDS子命令" {
  let result = cli_dds()
  assert_true(result.success)
  assert_eq(result.command, "dds")
}

///|
test "cli_validate 校验子命令" {
  let result = cli_validate()
  assert_eq(result.command, "validate")
}

///|
test "cli_batch 批量子命令" {
  let result = cli_batch()
  assert_eq(result.command, "batch")
}

///|
test "cli_ensemble 集合子命令" {
  let result = cli_ensemble()
  assert_eq(result.command, "ensemble")
}

///|
test "cli_uncertainty 不确定性子命令" {
  let result = cli_uncertainty()
  assert_true(result.success)
  assert_eq(result.command, "uncertainty")
}

///|
test "cli_sensitivity 敏感性子命令" {
  let result = cli_sensitivity()
  assert_true(result.success)
  assert_eq(result.command, "sensitivity")
}

///|
test "cli_swe 浅水方程子命令" {
  let result = cli_swe()
  assert_eq(result.command, "swe")
}

///|
test "cli_coupling 耦合子命令" {
  let result = cli_coupling()
  assert_eq(result.command, "coupling")
}

///|
test "cli_timeseries 时间序列子命令" {
  let result = cli_timeseries()
  assert_true(result.success)
  assert_eq(result.command, "timeseries")
}

///|
test "cli_metrics 指标子命令" {
  let result = cli_metrics()
  assert_true(result.success)
  assert_eq(result.command, "metrics")
}

///|
test "cli_json JSON子命令" {
  let result = cli_json()
  assert_true(result.success)
  assert_eq(result.command, "json")
}

///|
test "cli_bench 基准测试子命令" {
  let result = cli_bench()
  assert_true(result.success)
  assert_eq(result.command, "bench")
}

///|
test "cli_persistence 持久化子命令" {
  let result = cli_persistence()
  assert_true(result.success)
  assert_eq(result.command, "persistence")
}

///|
test "repeat_str 字符串重复" {
  assert_eq(repeat_str("ab", 3), "ababab")
  assert_eq(repeat_str("x", 0), "")
  assert_eq(repeat_str("", 5), "")
}

///|
test "print_cli_result 结果打印" {
  let r : CliResult = {
    command: "test",
    success: true,
    message: "测试消息",
    details: "",
  }
  print_cli_result(r)
}

///|
test "print_cli_result 带详情" {
  let r : CliResult = {
    command: "test",
    success: false,
    message: "失败消息",
    details: "错误详情",
  }
  print_cli_result(r)
}
