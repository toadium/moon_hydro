///|
/// 持久化存储测试 - 内存操作与JSON序列化

///|
test "DataStore::new 空存储" {
  let store = DataStore::new()
  assert_eq(store.schemes.length(), 0)
  assert_eq(store.results.length(), 0)
  assert_eq(store.param_sets.length(), 0)
}

///|
test "DataStore 仿真方案CRUD" {
  let store = DataStore::new()
  let scheme : SimulationScheme = {
    id: "scheme_001",
    name: "闽江竹岐基准方案",
    basin_name: "闽江竹岐",
    area: 54500.0,
    dt: 6.0,
    params: @shared.XinanjiangParams::default(),
    forcings: [
      { rainfall: 10.0, evaporation: 2.0, datetime: "t0" },
      { rainfall: 20.0, evaporation: 1.0, datetime: "t1" },
    ],
    created_at: 1723000000,
    updated_at: 1723000000,
  }
  store.save_scheme(scheme)
  assert_eq(store.schemes.length(), 1)
  // 加载
  let loaded = store.load_scheme("scheme_001")
  guard loaded is Some(s) else { fail("方案未找到") }
  assert_eq(s.name, "闽江竹岐基准方案")
  assert_true((s.area - 54500.0).abs() < 0.001)
  // 列出
  let ids = store.list_schemes()
  assert_eq(ids.length(), 1)
  assert_eq(ids[0], "scheme_001")
  // 删除
  let deleted = store.delete_scheme("scheme_001")
  assert_true(deleted)
  assert_eq(store.schemes.length(), 0)
  // 删除不存在的
  let deleted2 = store.delete_scheme("not_exist")
  assert_false(deleted2)
}

///|
test "DataStore 仿真结果保存与查询" {
  let store = DataStore::new()
  let result1 : ResultRecord = {
    id: "result_001",
    scheme_id: "scheme_001",
    basin_name: "闽江竹岐",
    peak_flow: 1500.0,
    peak_time: 3,
    nse: 0.85,
    kge: 0.82,
    pbias: -5.2,
    runoff_series: [100.0, 500.0, 1500.0, 800.0, 200.0],
    created_at: 1723000000,
  }
  let result2 : ResultRecord = {
    id: "result_002",
    scheme_id: "scheme_001",
    basin_name: "闽江竹岐",
    peak_flow: 1800.0,
    peak_time: 4,
    nse: 0.88,
    kge: 0.85,
    pbias: -3.1,
    runoff_series: [120.0, 600.0, 1200.0, 1800.0, 300.0],
    created_at: 1723000001,
  }
  let result3 : ResultRecord = {
    id: "result_003",
    scheme_id: "scheme_002",
    basin_name: "飞云江",
    peak_flow: 900.0,
    peak_time: 2,
    nse: 0.78,
    kge: 0.75,
    pbias: 8.0,
    runoff_series: [50.0, 400.0, 900.0, 500.0],
    created_at: 1723000002,
  }
  store.save_result(result1)
  store.save_result(result2)
  store.save_result(result3)
  assert_eq(store.results.length(), 3)
  // 按方案查询
  let scheme1_results = store.list_results("scheme_001")
  assert_eq(scheme1_results.length(), 2)
  let scheme2_results = store.list_results("scheme_002")
  assert_eq(scheme2_results.length(), 1)
  // 不存在的方案
  let empty_results = store.list_results("not_exist")
  assert_eq(empty_results.length(), 0)
}

///|
test "DataStore 参数集CRUD" {
  let store = DataStore::new()
  let param_set : ParameterSet = {
    id: "param_001",
    name: "闽江默认参数",
    basin_name: "闽江竹岐",
    params: @shared.XinanjiangParams::default(),
    description: "闽江竹岐流域默认新安江参数",
    created_at: 1723000000,
  }
  store.save_param_set(param_set)
  assert_eq(store.param_sets.length(), 1)
  // 加载
  let loaded = store.load_param_set("param_001")
  guard loaded is Some(p) else { fail("参数集未找到") }
  assert_eq(p.name, "闽江默认参数")
  assert_eq(p.basin_name, "闽江竹岐")
  // 列出
  let ids = store.list_param_sets()
  assert_eq(ids.length(), 1)
  // 删除
  let deleted = store.delete_param_set("param_001")
  assert_true(deleted)
  assert_eq(store.param_sets.length(), 0)
}

///|
test "DataStore JSON序列化与反序列化" {
  let store = DataStore::new()
  let scheme : SimulationScheme = {
    id: "scheme_json",
    name: "JSON测试方案",
    basin_name: "合成基准",
    area: 100.0,
    dt: 1.0,
    params: @shared.XinanjiangParams::default(),
    forcings: [{ rainfall: 10.0, evaporation: 2.0, datetime: "t0" }],
    created_at: 1723000000,
    updated_at: 1723000000,
  }
  store.save_scheme(scheme)
  let result : ResultRecord = {
    id: "result_json",
    scheme_id: "scheme_json",
    basin_name: "合成基准",
    peak_flow: 500.0,
    peak_time: 1,
    nse: 0.9,
    kge: 0.88,
    pbias: 2.0,
    runoff_series: [100.0, 500.0, 200.0],
    created_at: 1723000001,
  }
  store.save_result(result)
  // 序列化
  let json_str = store.to_json_string()
  assert_true(json_str.contains("scheme_json"))
  assert_true(json_str.contains("JSON测试方案"))
  // 反序列化
  let store2 = DataStore::from_json_string(json_str)
  assert_eq(store2.schemes.length(), 1)
  let loaded = store2.load_scheme("scheme_json")
  guard loaded is Some(s) else { fail("反序列化方案未找到") }
  assert_eq(s.name, "JSON测试方案")
  assert_eq(store2.results.length(), 1)
}

///|
test "DataStore stats 统计信息" {
  let store = DataStore::new()
  let scheme : SimulationScheme = {
    id: "s1",
    name: "方案1",
    basin_name: "测试",
    area: 100.0,
    dt: 1.0,
    params: @shared.XinanjiangParams::default(),
    forcings: [],
    created_at: 0,
    updated_at: 0,
  }
  store.save_scheme(scheme)
  let result : ResultRecord = {
    id: "r1",
    scheme_id: "s1",
    basin_name: "测试",
    peak_flow: 100.0,
    peak_time: 0,
    nse: 0.8,
    kge: 0.7,
    pbias: 5.0,
    runoff_series: [100.0],
    created_at: 0,
  }
  store.save_result(result)
  let param_set : ParameterSet = {
    id: "p1",
    name: "参数1",
    basin_name: "测试",
    params: @shared.XinanjiangParams::default(),
    description: "",
    created_at: 0,
  }
  store.save_param_set(param_set)
  let stats_str = store.stats()
  assert_true(stats_str.contains("方案数=1"))
  assert_true(stats_str.contains("结果数=1"))
  assert_true(stats_str.contains("参数集数=1"))
}

///|
test "generate_id ID生成" {
  let id = generate_id("scheme", 1723000000)
  assert_eq(id, "scheme_1723000000")
}
