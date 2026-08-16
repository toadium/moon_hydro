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
/// 将字符串写入文件
///
/// 成功返回Unit，失败抛出FileError
pub fn write_file(path : String, content : String) -> Unit raise {
  let path_bytes = @utf8.encode(path)
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
/// 成功返回文件内容，失败抛出FileError
pub fn read_file(path : String) -> String raise {
  let path_bytes = @utf8.encode(path)
  let content_bytes = hydro_read_file(path_bytes)
  if content_bytes.length() == 0 {
    raise FileError::FileNotFound(path)
  }
  @utf8.decode(content_bytes)
}

///|
/// 检查文件是否存在
pub fn file_exists(path : String) -> Bool {
  let path_bytes = @utf8.encode(path)
  let content_bytes = hydro_read_file(path_bytes)
  content_bytes.length() > 0
}

///|
/// 将DataStore保存到JSON文件
pub fn DataStore::save_to_file(self : DataStore, path : String) -> Unit raise {
  let json_str = self.to_json_string()
  write_file(path, json_str)
}

///|
/// 从JSON文件加载DataStore
pub fn DataStore::load_from_file(path : String) -> DataStore raise {
  let json_str = read_file(path)
  DataStore::from_json_string(json_str)
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
