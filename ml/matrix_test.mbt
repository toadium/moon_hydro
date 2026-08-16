///|
/// 矩阵运算测试

///|
test "vec_zeros" {
  let v = vec_zeros(5)
  assert_eq(v.length(), 5)
  for i in 0..<5 {
    assert_eq(v[i], 0.0)
  }
}

///|
test "mat_zeros" {
  let m = mat_zeros(3, 4)
  assert_eq(m.length(), 3)
  assert_eq(m[0].length(), 4)
  assert_eq(m[2][3], 0.0)
}

///|
test "vec_add" {
  let a = [1.0, 2.0, 3.0]
  let b = [4.0, 5.0, 6.0]
  let c = vec_add(a, b)
  assert_eq(c[0], 5.0)
  assert_eq(c[1], 7.0)
  assert_eq(c[2], 9.0)
}

///|
test "vec_mul" {
  let a = [1.0, 2.0, 3.0]
  let b = [4.0, 5.0, 6.0]
  let c = vec_mul(a, b)
  assert_eq(c[0], 4.0)
  assert_eq(c[1], 10.0)
  assert_eq(c[2], 18.0)
}

///|
test "vec_concat" {
  let a = [1.0, 2.0]
  let b = [3.0, 4.0, 5.0]
  let c = vec_concat(a, b)
  assert_eq(c.length(), 5)
  assert_eq(c[0], 1.0)
  assert_eq(c[2], 3.0)
  assert_eq(c[4], 5.0)
}

///|
test "mat_vec_mul" {
  let m = [[1.0, 2.0], [3.0, 4.0]]
  let v = [5.0, 6.0]
  let r = mat_vec_mul(m, v)
  assert_eq(r[0], 17.0) // 1*5 + 2*6
  assert_eq(r[1], 39.0) // 3*5 + 4*6
}

///|
test "mat_transpose" {
  let m = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]
  let t = mat_transpose(m)
  assert_eq(t.length(), 3)
  assert_eq(t[0][0], 1.0)
  assert_eq(t[0][1], 4.0)
  assert_eq(t[2][1], 6.0)
}

///|
test "sigmoid" {
  let s0 = sigmoid(0.0)
  assert_true(s0 - 0.5 < 0.0001)
  let s_pos = sigmoid(10.0)
  assert_true(s_pos > 0.999)
  let s_neg = sigmoid(-10.0)
  assert_true(s_neg < 0.001)
}

///|
test "vec_sigmoid" {
  let v = [0.0, 0.0]
  let r = vec_sigmoid(v)
  assert_true(r[0] - 0.5 < 0.0001)
  assert_true(r[1] - 0.5 < 0.0001)
}

///|
test "vec_tanh" {
  let v = [0.0, 1.0]
  let r = vec_tanh(v)
  assert_true(r[0] < 0.0001)
  assert_true(r[1] > 0.7)
}

///|
test "vec_dot" {
  let a = [1.0, 2.0, 3.0]
  let b = [4.0, 5.0, 6.0]
  assert_eq(vec_dot(a, b), 32.0) // 4+10+18
}

///|
test "vec_mean" {
  let v = [1.0, 2.0, 3.0, 4.0, 5.0]
  assert_eq(vec_mean(v), 3.0)
}

///|
test "vec_normalize 和 denormalize" {
  let v = [1.0, 2.0, 3.0, 4.0, 5.0]
  let (normalized, mean, std) = vec_normalize(v)
  assert_true(vec_mean(normalized) - 0.0 < 0.0001)
  let restored = vec_denormalize(normalized, mean, std)
  for i in 0..<5 {
    assert_true(restored[i] - v[i] < 0.0001)
  }
}

///|
test "mat_flatten 和 vec_reshape" {
  let m = [[1.0, 2.0], [3.0, 4.0]]
  let flat = mat_flatten(m)
  assert_eq(flat.length(), 4)
  assert_eq(flat[0], 1.0)
  assert_eq(flat[3], 4.0)
  let m2 = vec_reshape(flat, 2, 2)
  assert_eq(m2[0][0], 1.0)
  assert_eq(m2[1][1], 4.0)
}

///|
test "mat_random" {
  let rng = @splitmix.new(seed=42)
  let m = mat_random(3, 4, rng)
  assert_eq(m.length(), 3)
  assert_eq(m[0].length(), 4)
}
