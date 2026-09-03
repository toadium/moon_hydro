///|
/// GIS 类型测试

///|
test "XYPoint 构造" {
  let p : XYPoint = { x: 100.0, y: 200.0, }
  assert_eq(p.x, 100.0)
  assert_eq(p.y, 200.0)
}

///|
test "xy_distance" {
  let a : XYPoint = { x: 0.0, y: 0.0, }
  let b : XYPoint = { x: 3.0, y: 4.0, }
  assert_eq(xy_distance(a, b), 5.0)
}

///|
test "polygon_area - 正方形" {
  let polygon : Polygon = {
    exterior: [
      { x: 0.0, y: 0.0, },
      { x: 100.0, y: 0.0, },
      { x: 100.0, y: 100.0, },
      { x: 0.0, y: 100.0, },
    ],
    holes: [],
    name: "正方形",
  }
  let area = polygon_area(polygon)
  assert_true((area - 10000.0).abs() < 0.001)
}

///|
test "polygon_centroid - 正方形" {
  let polygon : Polygon = {
    exterior: [
      { x: 0.0, y: 0.0, },
      { x: 100.0, y: 0.0, },
      { x: 100.0, y: 100.0, },
      { x: 0.0, y: 100.0, },
    ],
    holes: [],
    name: "正方形",
  }
  let c = polygon_centroid(polygon)
  assert_true((c.x - 50.0).abs() < 0.001)
  assert_true((c.y - 50.0).abs() < 0.001)
}

///|
test "BasinBoundary::from_polygon" {
  let polygon : Polygon = {
    exterior: [
      { x: 0.0, y: 0.0, },
      { x: 1000.0, y: 0.0, },
      { x: 1000.0, y: 1000.0, },
      { x: 0.0, y: 1000.0, },
    ],
    holes: [],
    name: "流域A",
  }
  let basin = BasinBoundary::from_polygon(name="流域A", polygon)
  assert_eq(basin.name, "流域A")
  assert_true(basin.area > 0.99 && basin.area < 1.01) // 1km²
}

///|
test "polyline_length" {
  let polyline : Polyline = {
    points: [{ x: 0.0, y: 0.0, }, { x: 3.0, y: 4.0, }, { x: 3.0, y: 9.0, }],
    name: "河流1",
  }
  let len = polyline_length(polyline)
  assert_eq(len, 10.0) // 5 + 5
}

///|
test "RiverNodeType::to_string" {
  assert_eq(RiverNodeType::Source.to_string(), "源头")
  assert_eq(RiverNodeType::Confluence.to_string(), "汇流点")
  assert_eq(RiverNodeType::Outlet.to_string(), "出口")
  assert_eq(RiverNodeType::Intermediate.to_string(), "中间点")
}

///|
test "RiverNetwork 基本操作" {
  let network = RiverNetwork::new()
  let node1 : RiverNode = {
    id: 1,
    point: { x: 0.0, y: 0.0, },
    elevation: 100.0,
    node_type: Source,
  }
  let node2 : RiverNode = {
    id: 2,
    point: { x: 100.0, y: 0.0, },
    elevation: 90.0,
    node_type: Outlet,
  }
  network.add_node(node1)
  network.add_node(node2)
  let reach : RiverReach = {
    id: 1,
    from_node: 1,
    to_node: 2,
    length: 100.0,
    slope: 0.1,
    order: 1,
  }
  network.add_reach(reach)
  assert_eq(network.nodes.length(), 2)
  assert_eq(network.reaches.length(), 1)
  // 上游河段
  let upstream = network.upstream_reaches(2)
  assert_eq(upstream.length(), 1)
  // 下游河段
  let downstream = network.downstream_reaches(1)
  assert_eq(downstream.length(), 1)
}
