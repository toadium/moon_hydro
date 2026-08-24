///|
/// 文件I/O模块（native后端专用）
///
/// 使用C FFI实现文件读写，仅native后端可用。
/// wasm/js后端需通过浏览器API（localStorage等）实现持久化。

///|
/// 文件操作错误
pub(all) suberror FileError {
  FileNotFound(String)
  WriteFailed(String)
  ReadFailed(String)
  DeleteFailed(String)
  InvalidPath(String)
} derive(Debug, ToJson, FromJson)

///|
/// C FFI: 写入文件
#borrow(path, content)
extern "c" fn hydro_write_file(
  path : Bytes,
  content : Bytes,
  content_len : Int,
) -> Int = "hydro_write_file"

///|
/// C FFI: 读取文件
#borrow(path)
extern "c" fn hydro_read_file(path : Bytes) -> Bytes = "hydro_read_file"

///|
/// C FFI: 检查文件是否存在
#borrow(path)
extern "c" fn hydro_file_exists(path : Bytes) -> Int = "hydro_file_exists"

///|
/// C FFI: 获取文件大小
#borrow(path)
extern "c" fn hydro_file_size(path : Bytes) -> Int = "hydro_file_size"

///|
/// 路径遍历防护：拒绝包含 ".." 或绝对路径的路径
fn validate_path(path : String) -> Unit raise FileError {
  // 空路径检查
  if path.length() == 0 {
    raise FileError::InvalidPath("empty path")
  }
  // P1修复：拒绝包含null字节的路径，防止C FFI null字节注入
  if path.contains("\u0000") {
    raise FileError::InvalidPath("null byte in path: " + path)
  }
  // 按路径分隔符拆分检查各分量是否恰好为".."，避免误拒含连续点的合法文件名
  if path.split("/").any(fn(s) { s.equal_to_string("..") }) {
    raise FileError::InvalidPath("path traversal detected: " + path)
  }
  if path[0] == 47 {
    raise FileError::InvalidPath("absolute path not allowed: " + path)
  }
}

///|
/// T11: 将路径字符串编码为null终止的Bytes（供C FFI使用）
fn encode_path(path : String) -> Bytes {
  @utf8.encode(path) + Bytes::make(1, b'\x00')
}

///|
/// 将字符串写入文件
///
/// 成功返回Unit，失败抛出FileError
pub fn write_file(path : String, content : String) -> Unit raise FileError {
  validate_path(path)
  let path_bytes = encode_path(path)
  let content_bytes = @utf8.encode(content)
  let result = hydro_write_file(
    path_bytes,
    content_bytes,
    content_bytes.length(),
  )
  if result != 0 {
    raise FileError::WriteFailed(path)
  }
}

///|
/// 从文件读取字符串
///
/// 成功返回文件内容，失败抛出FileError。
/// 空文件返回空字符串，文件不存在抛出FileNotFound。
pub fn read_file(path : String) -> String raise FileError {
  validate_path(path)
  let path_bytes = encode_path(path)
  // P2-40：此处存在TOCTOU竞态（file_exists与read_file之间文件可能被删除），单线程环境下无实际风险
  if hydro_file_exists(path_bytes) == 0 {
    raise FileError::FileNotFound(path)
  }
  let file_size = hydro_file_size(path_bytes)
  // P1修复：file_size < 0 表示stat失败，不应静默返回空字符串
  if file_size < 0 {
    raise FileError::ReadFailed(path)
  }
  let content_bytes = hydro_read_file(path_bytes)
  if file_size > 0 && content_bytes.length() == 0 {
    raise FileError::ReadFailed(path)
  }
  // P3修复：包装UTF-8解码异常为FileError，保持错误处理契约一致
  @utf8.decode(content_bytes) catch {
    _ => raise FileError::ReadFailed(path)
  }
}

///|
/// 检查文件是否存在
///
/// P2-3: 使用专用C函数检查，空文件也返回true
pub fn file_exists(path : String) -> Bool raise FileError {
  validate_path(path)
  let path_bytes = encode_path(path)
  hydro_file_exists(path_bytes) == 1
}

///|
/// C FFI: 删除文件
#borrow(path)
extern "c" fn hydro_delete_file(path : Bytes) -> Int = "hydro_delete_file"

///|
/// 删除文件
///
/// P2-4: 用于测试清理，成功返回Unit，失败抛出FileError
pub fn delete_file(path : String) -> Unit raise FileError {
  validate_path(path)
  let path_bytes = encode_path(path)
  let result = hydro_delete_file(path_bytes)
  if result != 0 {
    raise FileError::DeleteFailed(path)
  }
}

///|
/// 将DataStore保存到JSON文件
pub fn DataStore::save_to_file(self : DataStore, path : String) -> Unit raise {
  let json_str = self.to_json_string()
  write_file(path, json_str)
}

///|
/// 从JSON文件加载DataStore
///
/// T57: 错误包装为StoreError，区分文件I/O错误和JSON解析错误
pub fn DataStore::load_from_file(path : String) -> DataStore raise {
  let json_str = read_file(path) catch { e => raise StoreError::FileError(e) }
  DataStore::from_json_string(json_str) catch {
    e => raise StoreError::JsonError(e.to_string())
  }
}

///|
/// 将仿真方案保存到JSON文件
pub fn SimulationScheme::save_to_file(
  self : SimulationScheme,
  path : String,
) -> Unit raise {
  let json_str = self.to_json().stringify()
  write_file(path, json_str)
}

///|
/// 从JSON文件加载仿真方案
///
/// P3修复：错误包装为StoreError，与DataStore::load_from_file策略一致
pub fn SimulationScheme::load_from_file(
  path : String,
) -> SimulationScheme raise {
  let json_str = read_file(path) catch { e => raise StoreError::FileError(e) }
  try {
    let json = @json.parse(json_str)
    @json.from_json(json)
  } catch {
    e => raise StoreError::JsonError(e.to_string())
  }
}

///|
/// 将参数集保存到JSON文件
pub fn ParameterSet::save_to_file(
  self : ParameterSet,
  path : String,
) -> Unit raise {
  let json_str = self.to_json().stringify()
  write_file(path, json_str)
}

///|
/// 从JSON文件加载参数集
///
/// P3修复：错误包装为StoreError，与DataStore::load_from_file策略一致
pub fn ParameterSet::load_from_file(path : String) -> ParameterSet raise {
  let json_str = read_file(path) catch { e => raise StoreError::FileError(e) }
  try {
    let json = @json.parse(json_str)
    @json.from_json(json)
  } catch {
    e => raise StoreError::JsonError(e.to_string())
  }
}
