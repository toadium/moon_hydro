///|
/// 文件I/O测试（native后端专用）

///|
test "write_file/read_file 基本文件读写" {
  let path = "test_hydro_basic.json"
  let content = "{\"name\":\"测试\",\"value\":42}"
  write_file(path, content)
  let read_back = read_file(path)
  assert_eq(read_back, content)
  // P2-4: 测试清理
  try delete_file(path) catch { _ => () } noraise { _ => () }
}

///|
test "file_exists 文件存在检查" {
  let path = "test_hydro_exists.json"
  write_file(path, "hello")
  assert_true(file_exists(path))
  assert_false(file_exists("nonexistent_file_xyz.json"))
  // P2-4: 测试清理
  try delete_file(path) catch { _ => () } noraise { _ => () }
}

///|
test "read_file 文件不存在抛出错误" {
  try read_file("nonexistent_file_xyz.json") catch {
    FileError::FileNotFound(path) =>
      assert_eq(path, "nonexistent_file_xyz.json")
    _ => fail("应该抛出FileNotFound错误")
  } noraise {
    _ => fail("应该抛出FileNotFound错误")
  }
}

///|
test "DataStore save_to_file/load_from_file" {
  let store = DataStore::new()
  let scheme : SimulationScheme = {
    id: "file_test_scheme",
    name: "文件持久化测试方案",
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
  let result : ResultRecord = {
    id: "file_test_result",
    scheme_id: "file_test_scheme",
    basin_name: "闽江竹岐",
    peak_flow: 1500.0,
    peak_time: 3,
    nse: 0.85,
    kge: 0.82,
    pbias: -5.2,
    runoff_series: [100.0, 500.0, 1500.0, 800.0],
    created_at: 1723000001,
  }
  store.save_result(result)
  let param_set : ParameterSet = {
    id: "file_test_param",
    name: "文件测试参数集",
    basin_name: "闽江竹岐",
    params: @shared.XinanjiangParams::default(),
    description: "文件持久化测试",
    created_at: 1723000000,
  }
  store.save_param_set(param_set)
  // 保存到文件
  let file_path = "test_hydro_store.json"
  store.save_to_file(file_path)
  // 从文件加载
  let loaded_store = DataStore::load_from_file(file_path)
  assert_eq(loaded_store.schemes.length(), 1)
  assert_eq(loaded_store.results.length(), 1)
  assert_eq(loaded_store.param_sets.length(), 1)
  // 验证方案数据
  let loaded_scheme = loaded_store.load_scheme("file_test_scheme")
  guard loaded_scheme is Some(s) else { fail("方案未找到") }
  assert_eq(s.name, "文件持久化测试方案")
  assert_true((s.area - 54500.0).abs() < 0.001)
  // 验证结果数据
  let results = loaded_store.list_results("file_test_scheme")
  assert_eq(results.length(), 1)
  assert_true((results[0].peak_flow - 1500.0).abs() < 0.001)
  // 验证参数集数据
  let loaded_param = loaded_store.load_param_set("file_test_param")
  guard loaded_param is Some(p) else { fail("参数集未找到") }
  assert_eq(p.name, "文件测试参数集")
  // P2-4: 测试清理
  try delete_file(file_path) catch { _ => () } noraise { _ => () }
}

///|
test "SimulationScheme save_to_file/load_from_file" {
  let scheme : SimulationScheme = {
    id: "scheme_file_io",
    name: "单方案文件测试",
    basin_name: "飞云江",
    area: 1930.0,
    dt: 3.0,
    params: @shared.XinanjiangParams::default(),
    forcings: [{ rainfall: 15.0, evaporation: 1.5, datetime: "t0" }],
    created_at: 1723000000,
    updated_at: 1723000000,
  }
  let path = "test_hydro_scheme.json"
  scheme.save_to_file(path)
  let loaded = SimulationScheme::load_from_file(path)
  assert_eq(loaded.id, "scheme_file_io")
  assert_eq(loaded.basin_name, "飞云江")
  assert_true((loaded.area - 1930.0).abs() < 0.001)
  // P2-4: 测试清理
  try delete_file(path) catch { _ => () } noraise { _ => () }
}

///|
test "ParameterSet save_to_file/load_from_file" {
  let param_set : ParameterSet = {
    id: "param_file_io",
    name: "单参数集文件测试",
    basin_name: "青弋江",
    params: @shared.XinanjiangParams::default(),
    description: "青弋江流域参数",
    created_at: 1723000000,
  }
  let path = "test_hydro_param.json"
  param_set.save_to_file(path)
  let loaded = ParameterSet::load_from_file(path)
  assert_eq(loaded.id, "param_file_io")
  assert_eq(loaded.basin_name, "青弋江")
  assert_eq(loaded.description, "青弋江流域参数")
  // P2-4: 测试清理
  try delete_file(path) catch { _ => () } noraise { _ => () }
}

///|
/// P3-7: 边界测试 — 空文件读写
test "write_file/read_file 空文件读写" {
  let path = "test_hydro_empty.json"
  write_file(path, "")
  // 空文件应该存在
  assert_true(file_exists(path))
  // 读取空文件应返回空字符串，而非抛出FileNotFound
  let content = read_file(path)
  assert_eq(content, "")
  // 测试清理
  try delete_file(path) catch { _ => () } noraise { _ => () }
}

///|
/// P3-7: 边界测试 — file_exists 对空文件返回true
test "file_exists 空文件返回true" {
  let path = "test_hydro_empty_exists.json"
  write_file(path, "")
  assert_true(file_exists(path))
  // 测试清理
  try delete_file(path) catch { _ => () } noraise { _ => () }
}

///|
/// P3-7: 边界测试 — 大内容读写
test "write_file/read_file 大内容读写" {
  let path = "test_hydro_large.json"
  // 构造10KB内容
  let buf : Array[String] = []
  for i = 0; i < 1000; i = i + 1 {
    buf.push("abcdefghij")
  }
  let content = buf.join("")
  write_file(path, content)
  let read_back = read_file(path)
  assert_eq(read_back.length(), content.length())
  // 测试清理
  try delete_file(path) catch { _ => () } noraise { _ => () }
}

///|
/// P3-7: 边界测试 — delete_file 删除文件
test "delete_file 删除文件" {
  let path = "test_hydro_delete.json"
  write_file(path, "to be deleted")
  assert_true(file_exists(path))
  delete_file(path)
  assert_false(file_exists(path))
}
