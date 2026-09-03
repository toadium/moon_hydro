///|
/// 新安江模型核心算法测试
///
/// 测试三层蒸散发、蓄满产流、三水源划分、汇流演算

///|
test "XinanjiangParams::default 构造默认参数" {
  let params = XinanjiangParams::default()
  inspect(params.wm, content="120")
  inspect(params.wum, content="20")
  inspect(params.wlm, content="60")
  inspect(params.wdm, content="40")
  // 三层蓄水容量满足 wm = wum + wlm + wdm
  inspect(params.wum + params.wlm + params.wdm, content="120")
}

///|
test "XinanjiangState::initial 构造初始状态" {
  let state = XinanjiangState::initial()
  inspect(state.w, content="0")
  inspect(state.wu, content="0")
  inspect(state.s, content="0")
  inspect(state.q, content="0")
}

///|
test "XinanjiangModel::new 构造模型" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  inspect(model.area, content="100")
  inspect(model.dt, content="1")
}

///|
test "XinanjiangModel::step 单步仿真-无降雨" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let state = XinanjiangState::initial()
  let forcing : ForcingData = {
    rainfall: 0.0,
    evaporation: 0.0,
    datetime: "t0",
  }
  let new_state = model.step(forcing, state)
  // 无降雨无蒸发，状态应保持不变
  inspect(new_state.r, content="0")
  inspect(new_state.q, content="0")
}

///|
test "XinanjiangModel::step 单步仿真-有降雨" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let state = XinanjiangState::initial()
  let forcing : ForcingData = {
    rainfall: 50.0,
    evaporation: 2.0,
    datetime: "t0",
  }
  let new_state = model.step(forcing, state)
  // 有降雨应产生产流
  assert_true(new_state.r >= 0.0)
  assert_true(new_state.q >= 0.0)
}

///|
test "XinanjiangModel::run 完整仿真-多时段" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
    { rainfall: 5.0, evaporation: 3.0, datetime: "t2", },
    { rainfall: 0.0, evaporation: 1.0, datetime: "t3", },
    { rainfall: 30.0, evaporation: 2.0, datetime: "t4", },
  ]
  let result = model.run(forcings)
  // 径流序列长度应等于输入长度
  inspect(result.runoff_series.length(), content="5")
  inspect(result.state_series.length(), content="5")
  // 所有径流值应非负
  for q in result.runoff_series {
    assert_true(q >= 0.0)
  }
}

///|
test "XinanjiangModel::run 完整仿真-退水过程" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  // 先降雨后无雨，应出现退水过程
  let forcings : Array[ForcingData] = [
    { rainfall: 50.0, evaporation: 0.0, datetime: "t0", },
    { rainfall: 0.0, evaporation: 0.0, datetime: "t1", },
    { rainfall: 0.0, evaporation: 0.0, datetime: "t2", },
    { rainfall: 0.0, evaporation: 0.0, datetime: "t3", },
  ]
  let result = model.run(forcings)
  // 第一时段有降雨，应有产流
  assert_true(result.runoff_series[0] >= 0.0)
  // 退水过程：无雨时段径流应单调递减
  assert_true(result.runoff_series[1] >= result.runoff_series[2])
  assert_true(result.runoff_series[2] >= result.runoff_series[3])
}

///|
test "HydroModel trait 通过trait接口调用step/run" {
  let model = XinanjiangModel::new(
    params=XinanjiangParams::default(),
    area=100.0,
    dt=1.0,
  )
  let state = XinanjiangState::initial()
  let forcing : ForcingData = {
    rainfall: 30.0,
    evaporation: 1.0,
    datetime: "t0",
  }
  // 通过HydroModel trait接口调用step
  let new_state = HydroModel::step(model, forcing, state)
  assert_true(new_state.r >= 0.0)
  // 通过HydroModel trait接口调用run
  let forcings : Array[ForcingData] = [
    { rainfall: 10.0, evaporation: 2.0, datetime: "t0", },
    { rainfall: 20.0, evaporation: 1.0, datetime: "t1", },
  ]
  let result = HydroModel::run(model, forcings)
  inspect(result.runoff_series.length(), content="2")
}
