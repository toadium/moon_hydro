///|
/// 权限框架测试

///|
test "Role::to_string" {
  assert_eq(Role::Admin.to_string(), "管理员")
  assert_eq(Role::Engineer.to_string(), "工程师")
  assert_eq(Role::Viewer.to_string(), "查看者")
}

///|
test "Permission::to_string" {
  assert_eq(Permission::SimRun.to_string(), "运行仿真")
  assert_eq(Permission::Calibrate.to_string(), "参数率定")
  assert_eq(Permission::SchemeRead.to_string(), "读取方案")
  assert_eq(Permission::SchemeWrite.to_string(), "写入方案")
  assert_eq(Permission::SchemeDelete.to_string(), "删除方案")
  assert_eq(Permission::UserManage.to_string(), "用户管理")
  assert_eq(Permission::BenchmarkRun.to_string(), "性能基准")
}

///|
test "role_has_permission - Admin全部权限" {
  assert_true(role_has_permission(Role::Admin, SimRun))
  assert_true(role_has_permission(Role::Admin, Calibrate))
  assert_true(role_has_permission(Role::Admin, SchemeRead))
  assert_true(role_has_permission(Role::Admin, SchemeWrite))
  assert_true(role_has_permission(Role::Admin, SchemeDelete))
  assert_true(role_has_permission(Role::Admin, UserManage))
  assert_true(role_has_permission(Role::Admin, BenchmarkRun))
}

///|
test "role_has_permission - Engineer" {
  assert_true(role_has_permission(Role::Engineer, SimRun))
  assert_true(role_has_permission(Role::Engineer, Calibrate))
  assert_true(role_has_permission(Role::Engineer, SchemeRead))
  assert_true(role_has_permission(Role::Engineer, SchemeWrite))
  assert_true(role_has_permission(Role::Engineer, SchemeDelete))
  assert_false(role_has_permission(Role::Engineer, UserManage))
  assert_true(role_has_permission(Role::Engineer, BenchmarkRun))
}

///|
test "role_has_permission - Viewer只读" {
  assert_true(role_has_permission(Role::Viewer, SimRun))
  assert_true(role_has_permission(Role::Viewer, SchemeRead))
  assert_false(role_has_permission(Role::Viewer, Calibrate))
  assert_false(role_has_permission(Role::Viewer, SchemeWrite))
  assert_false(role_has_permission(Role::Viewer, SchemeDelete))
  assert_false(role_has_permission(Role::Viewer, UserManage))
  assert_false(role_has_permission(Role::Viewer, BenchmarkRun))
}

///|
test "hash_password - 相同密码可通过verify_password验证" {
  let h = hash_password("secret123")
  assert_true(verify_password("secret123", h))
  assert_false(verify_password("wrong", h))
}

///|
test "hash_password - 不同密码不同哈希" {
  let h1 = hash_password("password1")
  let h2 = hash_password("password2")
  assert_not_eq(h1, h2)
}

///|
test "generate_token - 不同种子不同token" {
  let t1 = generate_token(seed=42UL)
  let t2 = generate_token(seed=43UL)
  assert_not_eq(t1, t2)
}

///|
test "generate_token - 相同种子相同token" {
  let t1 = generate_token(seed=42UL)
  let t2 = generate_token(seed=42UL)
  assert_eq(t1, t2)
}

///|
test "AuthManager::register - 注册成功" {
  let auth = AuthManager::new()
  let user_id = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  assert_true(user_id.length() > 0)
  assert_eq(auth.users.length(), 1)
  assert_eq(auth.usernames.length(), 1)
}

///|
test "AuthManager::register - 重复用户名失败" {
  let auth = AuthManager::new()
  let _ = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  try {
    let _ = auth.register(
      username="alice",
      password="pass456",
      role=Viewer,
      timestamp=2000UL,
    )
    (fail("应抛出UserAlreadyExists") : Unit)
  } catch {
    AuthError::UserAlreadyExists(_) => assert_true(true)
    _ => (fail("应抛出UserAlreadyExists") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::login - 登录成功" {
  let auth = AuthManager::new()
  let _ = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  let token = auth.login(username="alice", password="pass123", timestamp=2000UL)
  assert_true(token.length() > 0)
  assert_eq(auth.sessions.length(), 1)
}

///|
test "AuthManager::login - 错误密码失败" {
  let auth = AuthManager::new()
  let _ = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  try {
    let _ = auth.login(username="alice", password="wrong", timestamp=2000UL)
    (fail("应抛出InvalidPassword") : Unit)
  } catch {
    AuthError::InvalidPassword => assert_true(true)
    _ => (fail("应抛出InvalidPassword") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::login - 不存在用户失败" {
  let auth = AuthManager::new()
  try {
    let _ = auth.login(username="ghost", password="pass", timestamp=2000UL)
    (fail("应抛出UserNotFound") : Unit)
  } catch {
    AuthError::UserNotFound(_) => assert_true(true)
    _ => (fail("应抛出UserNotFound") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::verify_token - 有效Token" {
  let auth = AuthManager::new()
  let _ = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  let token = auth.login(username="alice", password="pass123", timestamp=2000UL)
  let user = auth.verify_token(token, current_time=3000UL)
  assert_eq(user.username, "alice")
}

///|
test "AuthManager::verify_token - 无效Token" {
  let auth = AuthManager::new()
  try {
    let _ = auth.verify_token("invalid_token", current_time=3000UL)
    (fail("应抛出InvalidToken") : Unit)
  } catch {
    AuthError::InvalidToken(_) => assert_true(true)
    _ => (fail("应抛出InvalidToken") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::verify_token - 过期Token" {
  let auth = AuthManager::new()
  let _ = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  let token = auth.login(
    username="alice",
    password="pass123",
    timestamp=2000UL,
    ttl_seconds=1UL,
  )
  try {
    let _ = auth.verify_token(token, current_time=5000UL)
    (fail("应抛出TokenExpired") : Unit)
  } catch {
    AuthError::TokenExpired(_) => assert_true(true)
    _ => (fail("应抛出TokenExpired") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::logout" {
  let auth = AuthManager::new()
  let _ = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  let token = auth.login(username="alice", password="pass123", timestamp=2000UL)
  assert_true(auth.logout(token))
  assert_eq(auth.sessions.length(), 0)
  assert_false(auth.logout(token))
}

///|
test "AuthManager::check_permission - Engineer无UserManage权限" {
  let auth = AuthManager::new()
  let user_id = auth.register(
    username="alice",
    password="pass123",
    role=Engineer,
    timestamp=1000UL,
  )
  let user = auth.users[user_id]
  try {
    auth.check_permission(user, UserManage)
    (fail("应抛出PermissionDenied") : Unit)
  } catch {
    AuthError::PermissionDenied(_) => assert_true(true)
    _ => (fail("应抛出PermissionDenied") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::check_permission - Admin全部权限" {
  let auth = AuthManager::new()
  let user_id = auth.register(
    username="admin",
    password="pass",
    role=Admin,
    timestamp=1000UL,
  )
  let user = auth.users[user_id]
  auth.check_permission(user, UserManage)
  auth.check_permission(user, SimRun)
  auth.check_permission(user, SchemeDelete)
}

///|
test "AuthManager::grant_scheme_ownership 和 check_scheme_access" {
  let auth = AuthManager::new()
  let alice_id = auth.register(
    username="alice",
    password="pass",
    role=Engineer,
    timestamp=1000UL,
  )
  let bob_id = auth.register(
    username="bob",
    password="pass",
    role=Engineer,
    timestamp=2000UL,
  )
  auth.grant_scheme_ownership(user_id=alice_id, scheme_id="scheme_1")
  let alice = auth.users[alice_id]
  let bob = auth.users[bob_id]
  // alice可以访问自己的方案
  auth.check_scheme_access(alice, "scheme_1")
  auth.check_scheme_access(alice, "scheme_1", write=true)
  // bob不能访问alice的方案
  try {
    auth.check_scheme_access(bob, "scheme_1")
    (fail("应抛出SchemeNotOwned") : Unit)
  } catch {
    AuthError::SchemeNotOwned(_) => assert_true(true)
    _ => (fail("应抛出SchemeNotOwned") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::make_scheme_public - 公开方案Viewer可读" {
  let auth = AuthManager::new()
  let alice_id = auth.register(
    username="alice",
    password="pass",
    role=Engineer,
    timestamp=1000UL,
  )
  let _ = auth.register(
    username="viewer1",
    password="pass",
    role=Viewer,
    timestamp=2000UL,
  )
  auth.grant_scheme_ownership(user_id=alice_id, scheme_id="scheme_pub")
  assert_true(auth.make_scheme_public("scheme_pub"))
  let viewer = auth.users[auth.usernames["viewer1"]]
  // Viewer可以读公开方案
  auth.check_scheme_access(viewer, "scheme_pub")
  // Viewer不能写公开方案
  try {
    auth.check_scheme_access(viewer, "scheme_pub", write=true)
    (fail("应抛出SchemeNotOwned") : Unit)
  } catch {
    AuthError::SchemeNotOwned(_) => assert_true(true)
    _ => (fail("应抛出SchemeNotOwned") : Unit)
  } noraise {
    _ => (fail("应抛出错误而非abort") : Unit)
  }
}

///|
test "AuthManager::list_user_schemes" {
  let auth = AuthManager::new()
  let alice_id = auth.register(
    username="alice",
    password="pass",
    role=Engineer,
    timestamp=1000UL,
  )
  auth.grant_scheme_ownership(user_id=alice_id, scheme_id="s1")
  auth.grant_scheme_ownership(user_id=alice_id, scheme_id="s2")
  auth.grant_scheme_ownership(user_id=alice_id, scheme_id="s3")
  let schemes = auth.list_user_schemes(alice_id)
  assert_eq(schemes.length(), 3)
}

///|
test "AuthManager::delete_user - 清理会话和方案" {
  let auth = AuthManager::new()
  let alice_id = auth.register(
    username="alice",
    password="pass",
    role=Engineer,
    timestamp=1000UL,
  )
  let _ = auth.login(username="alice", password="pass", timestamp=2000UL)
  auth.grant_scheme_ownership(user_id=alice_id, scheme_id="s1")
  assert_eq(auth.users.length(), 1)
  assert_eq(auth.sessions.length(), 1)
  assert_eq(auth.scheme_owners.length(), 1)
  assert_true(auth.delete_user(alice_id))
  assert_eq(auth.users.length(), 0)
  assert_eq(auth.usernames.length(), 0)
  assert_eq(auth.sessions.length(), 0)
  assert_eq(auth.scheme_owners.length(), 0)
}

///|
test "AuthManager::stats" {
  let auth = AuthManager::new()
  let alice_id = auth.register(
    username="alice",
    password="pass",
    role=Engineer,
    timestamp=1000UL,
  )
  let _ = auth.login(username="alice", password="pass", timestamp=2000UL)
  auth.grant_scheme_ownership(user_id=alice_id, scheme_id="s1")
  let s = auth.stats()
  assert_true(s.contains("用户数=1"))
  assert_true(s.contains("活跃会话=1"))
  assert_true(s.contains("方案所有权=1"))
}

///|
test "AuthManager - Admin可访问任何方案" {
  let auth = AuthManager::new()
  let _ = auth.register(
    username="alice",
    password="pass",
    role=Engineer,
    timestamp=1000UL,
  )
  let admin_id = auth.register(
    username="admin",
    password="pass",
    role=Admin,
    timestamp=2000UL,
  )
  auth.grant_scheme_ownership(user_id=auth.usernames["alice"], scheme_id="s1")
  let admin = auth.users[admin_id]
  // Admin可以访问任何方案
  auth.check_scheme_access(admin, "s1")
  auth.check_scheme_access(admin, "s1", write=true)
  // Admin可以访问无所有权记录的方案
  auth.check_scheme_access(admin, "unknown_scheme")
}
