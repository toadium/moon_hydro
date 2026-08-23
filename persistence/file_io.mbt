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
fn validate_path(path : String) -> Unit raise {
  if path.contains("..") {
    raise FileError::InvalidPath("path traversal detected: " + path)
  }
  if path.length() > 0 && path[0] == 47 {
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
pub fn write_file(path : String, content : String) -> Unit raise {
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
pub fn read_file(path : String) -> String raise {
  validate_path(path)
  let path_bytes = encode_path(path)
  // P2-40：此处存在TOCTOU竞态（file_exists与read_file之间文件可能被删除），单线程环境下无实际风险
  if hydro_file_exists(path_bytes) == 0 {
    raise FileError::FileNotFound(path)
  }
  let file_size = hydro_file_size(path_bytes)
  let content_bytes = hydro_read_file(path_bytes)
  if file_size > 0 && content_bytes.length() == 0 {
    raise FileError::ReadFailed(path)
  }
  @utf8.decode(content_bytes)
}

///|
/// 检查文件是否存在
///
/// P2-3: 使用专用C函数检查，空文件也返回true
pub fn file_exists(path : String) -> Bool raise {
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
pub fn delete_file(path : String) -> Unit raise {
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
  let json_str = try read_file(path) catch {
    e => raise StoreError::FileError(e.to_string())
  }
  try DataStore::from_json_string(json_str) catch {
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
pub fn SimulationScheme::load_from_file(
  path : String,
) -> SimulationScheme raise {
  let json_str = read_file(path)
  let json = @json.parse(json_str)
  @json.from_json(json)
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
pub fn ParameterSet::load_from_file(path : String) -> ParameterSet raise {
  let json_str = read_file(path)
  let json = @json.parse(json_str)
  @json.from_json(json)
}
