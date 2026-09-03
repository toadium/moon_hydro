///|
/// 权限框架模块
///
/// 提供用户管理、API鉴权、方案隔离三大功能：
/// - 用户注册/登录/登出（基于Token会话）
/// - 角色权限控制（Admin/Engineer/Viewer）
/// - 方案所有权隔离（用户只能访问自己的方案或公开方案）
///
/// 密码哈希使用FNV-1a + splitmix，Token使用splitmix伪随机生成。
/// 注意：这是轻量级实现，生产环境应使用bcrypt/argon2 + HTTPS。

///|
/// 用户角色
pub(all) enum Role {
  Admin // 管理员：全部权限
  Engineer // 工程师：仿真/率定/读写自己的方案
  Viewer // 查看者：只读公开方案
} derive(Debug, ToJson, FromJson, Eq)

///|
/// Show实现
pub impl Show for Role with fn to_string(self : Role) -> String {
  match self {
    Admin => "管理员"
    Engineer => "工程师"
    Viewer => "查看者"
  }
}

///|
/// 权限动作
pub(all) enum Permission {
  SimRun // 运行仿真
  Calibrate // 参数率定
  SchemeRead // 读取方案
  SchemeWrite // 写入方案
  SchemeDelete // 删除方案
  UserManage // 用户管理
  BenchmarkRun // 性能基准
} derive(Debug, ToJson, FromJson, Eq)

///|
/// Show实现
pub impl Show for Permission with fn to_string(self : Permission) -> String {
  match self {
    SimRun => "运行仿真"
    Calibrate => "参数率定"
    SchemeRead => "读取方案"
    SchemeWrite => "写入方案"
    SchemeDelete => "删除方案"
    UserManage => "用户管理"
    BenchmarkRun => "性能基准"
  }
}

///|
/// 用户
pub(all) struct User {
  id : String // 用户ID
  username : String // 用户名
  password_hash : String // 密码哈希（含salt，格式"salt:hash"）
  role : Role // 角色
  created_at : UInt64 // 创建时间戳
} derive(Debug, ToJson, FromJson)

///|
/// 会话
pub(all) struct Session {
  token : String // 会话Token
  user_id : String // 关联用户ID
  created_at : UInt64 // 创建时间戳
  expires_at : UInt64 // 过期时间戳
} derive(Debug, ToJson, FromJson)

///|
/// 方案所有权
pub(all) struct SchemeOwnership {
  scheme_id : String // 方案ID
  owner_id : String // 所有者用户ID
  is_public : Bool // 是否公开
} derive(Debug, ToJson, FromJson)

///|
/// 认证错误
pub(all) suberror AuthError {
  UserAlreadyExists(String) // 用户已存在
  UserNotFound(String) // 用户不存在
  InvalidPassword // 密码错误
  InvalidToken(String) // 无效Token
  TokenExpired(String) // Token过期
  PermissionDenied(String) // 权限不足
  SchemeNotOwned(String) // 方案不属于该用户
  RateLimited(String) // T37修复：登录频率限制
} derive(Debug, ToJson, FromJson)

///|
/// Show实现
pub impl Show for AuthError with fn to_string(self : AuthError) -> String {
  match self {
    UserAlreadyExists(name) => "用户已存在: \{name}"
    UserNotFound(name) => "用户不存在: \{name}"
    InvalidPassword => "密码错误"
    InvalidToken(t) => "无效Token: \{t}"
    TokenExpired(t) => "Token已过期: \{t}"
    PermissionDenied(perm) => "权限不足: \{perm}"
    SchemeNotOwned(id) => "方案不属于该用户: \{id}"
    RateLimited(name) => "登录频率受限: \{name}"
  }
}

///|
/// 认证管理器
pub(all) struct AuthManager {
  users : Map[String, User] // user_id -> User
  usernames : Map[String, String] // username -> user_id
  sessions : Map[String, Session] // token -> Session
  scheme_owners : Map[String, SchemeOwnership] // scheme_id -> ownership
  mut token_counter : UInt64 // 单调递增计数器，防Token碰撞
  mut user_counter : UInt64 // 单调递增计数器，防user_id碰撞
  login_attempts : Map[String, (Int, UInt64)] // T37修复：username -> (失败次数, 最后尝试时间)
} derive(Debug, ToJson, FromJson)

///|
/// 构造空AuthManager
pub fn AuthManager::new() -> AuthManager {
  {
    users: {},
    usernames: {},
    sessions: {},
    scheme_owners: {},
    token_counter: 0UL,
    user_counter: 0UL,
    login_attempts: {},
  }
}

///|
/// 默认实现
pub impl Default for AuthManager with fn default() {
  AuthManager::new()
}

///|
/// 字符串转UInt64种子（FNV-1a变体）
fn string_to_seed(s : String) -> UInt64 {
  let bytes = @utf8.encode(s)
  let mut hash : UInt64 = 14695981039346656037UL
  for i in 0..<bytes.length() {
    hash = hash ^ bytes[i].to_uint64()
    hash = hash * 1099511628211UL
  }
  hash
}

///|
/// 密码哈希内部函数：给定密码与salt字符串，计算"salt:hash"格式
fn hash_with_salt(password : String, salt_str : String) -> String {
  let salted = password + salt_str
  let seed = string_to_seed(salted)
  let mut hash = seed
  for i in 0..<1000 {
    let rng = @splitmix.new(seed=hash)
    hash = rng.next_uint64()
    hash = hash ^ (seed + i.to_uint64())
  }
  "\{salt_str}:\{hash}"
}

///|
/// 密码哈希（FNV-1a + splitmix多轮混淆 + 随机salt）
/// 返回格式 "salt:hash"，salt来自@env.now()纳秒时间戳
/// 注意：这是轻量级增强，生产环境仍应使用bcrypt/argon2
pub fn hash_password(password : String) -> String {
  let salt_str = @env.now().to_string()
  hash_with_salt(password, salt_str)
}

///|
/// 验证密码：解析存储的"salt:hash"格式，用同一salt重新计算并比较
pub fn verify_password(password : String, stored : String) -> Bool {
  let parts = stored.split(":").to_array()
  if parts.length() != 2 {
    return false
  }
  hash_with_salt(password, parts[0].to_owned()) == stored
}

///|
/// 生成Token（splitmix伪随机）
/// P2-12说明：当前使用splitmix伪随机数生成器，非加密安全级别
/// 生产环境应替换为加密安全的随机源（如crypto.random）
pub fn generate_token(seed~ : UInt64) -> String {
  let rng = @splitmix.new(seed~)
  let a = rng.next_uint64()
  let b = rng.next_uint64()
  "tok_\{a}_\{b}"
}

///|
/// 注册用户
///
/// 成功返回user_id，失败抛出AuthError
pub fn AuthManager::register(
  self : AuthManager,
  username~ : String,
  password~ : String,
  role~ : Role,
  timestamp~ : UInt64,
) -> String raise {
  if self.usernames.contains(username) {
    raise UserAlreadyExists(username)
  }
  self.user_counter = self.user_counter + 1UL
  let user_id = "user_\{timestamp}_\{self.user_counter}"
  let user : User = {
    id: user_id,
    username,
    password_hash: hash_password(password),
    role,
    created_at: timestamp,
  }
  self.users[user_id] = user
  self.usernames[username] = user_id
  user_id
}

///|
/// 登录
///
/// 成功返回token，失败抛出AuthError
pub fn AuthManager::login(
  self : AuthManager,
  username~ : String,
  password~ : String,
  timestamp~ : UInt64,
  ttl_seconds? : UInt64 = 86400UL,
) -> String raise {
  // T37修复：登录频率限制（60秒内最多5次失败尝试）
  let max_attempts = 5
  let cooldown_ms = 60000UL
  match self.login_attempts.get(username) {
    Some((failures, last_time)) => {
      if failures >= max_attempts && timestamp - last_time < cooldown_ms {
        raise RateLimited(username)
      }
      // 冷却期过后重置计数
      if timestamp - last_time >= cooldown_ms {
        self.login_attempts[username] = (0, timestamp)
      }
    }
    None => ()
  }
  let user_id = match self.usernames.get(username) {
    Some(id) => id
    None => raise UserNotFound(username)
  }
  let user = self.users[user_id]
  if !verify_password(password, user.password_hash) {
    // 记录失败尝试
    let new_count = match self.login_attempts.get(username) {
      Some((c, _)) => c + 1
      None => 1
    }
    self.login_attempts[username] = (new_count, timestamp)
    raise InvalidPassword
  }
  // 登录成功，清除失败计数
  self.login_attempts[username] = (0, timestamp)
  self.token_counter = self.token_counter + 1UL
  let token = generate_token(
    seed=timestamp + string_to_seed(user.password_hash) + self.token_counter,
  )
  let session : Session = {
    token,
    user_id,
    created_at: timestamp,
    expires_at: timestamp + ttl_seconds * 1000UL,
  }
  self.sessions[token] = session
  token
}

///|
/// 验证Token
///
/// 成功返回User，失败抛出AuthError
pub fn AuthManager::verify_token(
  self : AuthManager,
  token : String,
  current_time~ : UInt64,
) -> User raise {
  let session = match self.sessions.get(token) {
    Some(s) => s
    None => raise InvalidToken(token)
  }
  if current_time > session.expires_at {
    ignore(self.sessions.remove(token))
    raise TokenExpired(token)
  }
  match self.users.get(session.user_id) {
    Some(u) => u
    None => raise UserNotFound(session.user_id)
  }
}

///|
/// 登出
pub fn AuthManager::logout(self : AuthManager, token : String) -> Bool {
  if self.sessions.contains(token) {
    ignore(self.sessions.remove(token))
    true
  } else {
    false
  }
}

///|
/// 检查角色是否拥有某权限
pub fn role_has_permission(role : Role, perm : Permission) -> Bool {
  match role {
    Admin => true
    Engineer =>
      match perm {
        SimRun => true
        Calibrate => true
        SchemeRead => true
        SchemeWrite => true
        SchemeDelete => true
        UserManage => false
        BenchmarkRun => true
      }
    Viewer =>
      match perm {
        SchemeRead => true
        _ => false
      }
  }
}

///|
/// 检查用户权限
///
/// 成功返回Unit，失败抛出AuthError
pub fn AuthManager::check_permission(
  self : AuthManager,
  user : User,
  perm : Permission,
) -> Unit raise {
  // T30修复：利用self校验用户确实存在于管理器中
  if self.users.get(user.id) is None {
    raise UserNotFound(user.id)
  }
  if !role_has_permission(user.role, perm) {
    raise PermissionDenied(Show::to_string(perm))
  }
}

///|
/// 授予方案所有权
pub fn AuthManager::grant_scheme_ownership(
  self : AuthManager,
  user_id~ : String,
  scheme_id~ : String,
  is_public? : Bool = false,
  by? : User,
) -> Unit {
  // S7修复：校验请求者对具体方案的写权限（方案级），与make_scheme_public一致
  match by {
    Some(requester) =>
      self.check_scheme_access(requester, scheme_id, write=true) catch {
        _ => return
      }
    None => ()
  }
  self.scheme_owners[scheme_id] = { scheme_id, owner_id: user_id, is_public }
}

///|
/// 检查方案访问权限
///
/// Viewer只能访问公开方案，Engineer只能访问自己的或公开方案，Admin可访问所有
/// 成功返回Unit，失败抛出AuthError
pub fn AuthManager::check_scheme_access(
  self : AuthManager,
  user : User,
  scheme_id : String,
  write? : Bool = false,
) -> Unit raise {
  match self.scheme_owners.get(scheme_id) {
    Some(ownership) =>
      if ownership.is_public && !write {
        // 公开方案只读访问，任何角色都可读
        return
      } else if ownership.owner_id == user.id {
        // 所有者完全访问
        return
      } else if user.role is Admin {
        // 管理员完全访问
        return
      } else {
        raise SchemeNotOwned(scheme_id)
      }
    None =>
      // 无所有权记录，仅管理员可访问
      if user.role is Admin {
        return
      } else {
        raise SchemeNotOwned(scheme_id)
      }
  }
}

///|
/// 将方案设为公开
pub fn AuthManager::make_scheme_public(
  self : AuthManager,
  scheme_id : String,
  by? : User,
) -> Bool {
  // T31修复：提供by参数时校验请求者对方案有写权限，无权限则返回false
  match by {
    Some(requester) =>
      self.check_scheme_access(requester, scheme_id, write=true) catch {
        _ => return false
      }
    None => ()
  }
  match self.scheme_owners.get(scheme_id) {
    Some(ownership) => {
      self.scheme_owners[scheme_id] = { ..ownership, is_public: true }
      true
    }
    None => false
  }
}

///|
/// 获取用户的所有方案ID
pub fn AuthManager::list_user_schemes(
  self : AuthManager,
  user_id : String,
) -> Array[String] {
  let ids : Array[String] = []
  for _, ownership in self.scheme_owners {
    if ownership.owner_id == user_id {
      ids.push(ownership.scheme_id)
    }
  }
  ids
}

///|
/// 获取所有用户
pub fn AuthManager::list_users(self : AuthManager) -> Array[User] {
  let users : Array[User] = []
  for _, u in self.users {
    users.push(u)
  }
  users
}

///|
/// 删除用户
///
/// 同时清理其会话和方案所有权
pub fn AuthManager::delete_user(self : AuthManager, user_id : String) -> Bool {
  if !self.users.contains(user_id) {
    return false
  }
  let user = self.users[user_id]
  ignore(self.users.remove(user_id))
  ignore(self.usernames.remove(user.username))
  // 修复：清理登录失败计数，避免用户名复用继承历史失败计数
  ignore(self.login_attempts.remove(user.username))
  // 清理会话
  let tokens_to_remove : Array[String] = []
  for token, session in self.sessions {
    if session.user_id == user_id {
      tokens_to_remove.push(token)
    }
  }
  for token in tokens_to_remove {
    ignore(self.sessions.remove(token))
  }
  // 清理方案所有权
  let schemes_to_remove : Array[String] = []
  for sid, ownership in self.scheme_owners {
    if ownership.owner_id == user_id {
      schemes_to_remove.push(sid)
    }
  }
  for sid in schemes_to_remove {
    ignore(self.scheme_owners.remove(sid))
  }
  true
}

///|
/// 统计信息
pub fn AuthManager::stats(self : AuthManager) -> String {
  "用户数=\{self.users.length()}, 活跃会话=\{self.sessions.length()}, 方案所有权=\{self.scheme_owners.length()}"
}
