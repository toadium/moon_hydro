///|
/// 河网处理测试

///|
test "RiverNetwork::compute_strahler_orders - 简单河网" {
  let network = RiverNetwork::new()
  // 源头1 -> 汇流点 -> 出口
  // 源头2 -> 汇流点
  network.add_node({
    id: 1,
    point: { x: 0.0, y: 100.0 },
    elevation: 100.0,
    node_type: Source,
  })
  network.add_node({
    id: 2,
    point: { x: 0.0, y: 200.0 },
    elevation: 100.0,
    node_type: Source,
  })
  network.add_node({
    id: 3,
    point: { x: 50.0, y: 150.0 },
    elevation: 80.0,
    node_type: Confluence,
  })
  network.add_node({
    id: 4,
    point: { x: 100.0, y: 150.0 },
    elevation: 60.0,
    node_type: Outlet,
  })
  network.add_reach({
    id: 1,
    from_node: 1,
    to_node: 3,
    length: 100.0,
    slope: 0.2,
    order: 0,
  })
  network.add_reach({
    id: 2,
    from_node: 2,
    to_node: 3,
    length: 100.0,
    slope: 0.2,
    order: 0,
  })
  network.add_reach({
    id: 3,
    from_node: 3,
    to_node: 4,
    length: 50.0,
    slope: 0.4,
    order: 0,
  })
  network.compute_strahler_orders()
  // 两条1级河段汇合 -> 2级
  assert_eq(network.reaches[0].order, 1)
  assert_eq(network.reaches[1].order, 1)
  assert_eq(network.reaches[2].order, 2)
}

///|
test "RiverNetwork::topological_order" {
  let network = RiverNetwork::new()
  network.add_node({
    id: 1,
    point: { x: 0.0, y: 0.0 },
    elevation: 100.0,
    node_type: Source,
  })
  network.add_node({
    id: 2,
    point: { x: 100.0, y: 0.0 },
    elevation: 90.0,
    node_type: Outlet,
  })
  network.add_reach({
    id: 1,
    from_node: 1,
    to_node: 2,
    length: 100.0,
    slope: 0.1,
    order: 1,
  })
  let order = network.topological_order()
  assert_eq(order.length(), 1)
  assert_eq(order[0], 1)
}

///|
test "RiverNetwork::trace_to_sources" {
  let network = RiverNetwork::new()
  network.add_node({
    id: 1,
    point: { x: 0.0, y: 100.0 },
    elevation: 100.0,
    node_type: Source,
  })
  network.add_node({
    id: 2,
    point: { x: 0.0, y: 200.0 },
    elevation: 100.0,
    node_type: Source,
  })
  network.add_node({
    id: 3,
    point: { x: 50.0, y: 150.0 },
    elevation: 80.0,
    node_type: Confluence,
  })
  network.add_reach({
    id: 1,
    from_node: 1,
    to_node: 3,
    length: 100.0,
    slope: 0.2,
    order: 1,
  })
  network.add_reach({
    id: 2,
    from_node: 2,
    to_node: 3,
    length: 100.0,
    slope: 0.2,
    order: 1,
  })
  let sources = network.trace_to_sources(3)
  assert_eq(sources.length(), 2)
}

///|
test "RiverNetwork::trace_to_outlet" {
  let network = RiverNetwork::new()
  network.add_node({
    id: 1,
    point: { x: 0.0, y: 0.0 },
    elevation: 100.0,
    node_type: Source,
  })
  network.add_node({
    id: 2,
    point: { x: 50.0, y: 0.0 },
    elevation: 80.0,
    node_type: Intermediate,
  })
  network.add_node({
    id: 3,
    point: { x: 100.0, y: 0.0 },
    elevation: 60.0,
    node_type: Outlet,
  })
  network.add_reach({
    id: 1,
    from_node: 1,
    to_node: 2,
    length: 50.0,
    slope: 0.4,
    order: 1,
  })
  network.add_reach({
    id: 2,
    from_node: 2,
    to_node: 3,
    length: 50.0,
    slope: 0.4,
    order: 1,
  })
  let path = network.trace_to_outlet(1)
  assert_eq(path.length(), 3)
  assert_eq(path[0], 1)
  assert_eq(path[2], 3)
}

///|
test "RiverNetwork::stats" {
  let network = RiverNetwork::new()
  network.add_node({
    id: 1,
    point: { x: 0.0, y: 0.0 },
    elevation: 100.0,
    node_type: Source,
  })
  network.add_node({
    id: 2,
    point: { x: 100.0, y: 0.0 },
    elevation: 60.0,
    node_type: Outlet,
  })
  network.add_reach({
    id: 1,
    from_node: 1,
    to_node: 2,
    length: 100.0,
    slope: 0.4,
    order: 1,
  })
  let s = network.stats()
  assert_true(s.contains("节点数=2"))
  assert_true(s.contains("河段数=1"))
}

///|
test "extract_network_from_dem" {
  let dem = synthetic_dem(nx=10, ny=10, dx=100.0, dy=100.0)
  let fd = compute_flow_direction(dem)
  let fa = compute_flow_accumulation(fd)
  let network = extract_network_from_dem(dem, fa, threshold=5)
  let s = network.stats()
  assert_true(s.contains("节点数="))
}
