#pragma once
#include "wx/string.h"
#include <fstream>
#include <cstddef>
class wxFile {
  mutable std::ifstream file_;
public:
  explicit wxFile(const wxString& path): file_(path.str(),std::ios::binary) {}
  bool IsOpened() const { return file_.is_open(); }
  std::size_t Length() { if(!file_)return 0; auto at=file_.tellg(); file_.seekg(0,std::ios::end); auto len=file_.tellg(); file_.seekg(at); return len<0?0:static_cast<std::size_t>(len); }
  std::size_t Read(void* p,std::size_t n) { file_.read(static_cast<char*>(p),static_cast<std::streamsize>(n)); return static_cast<std::size_t>(file_.gcount()); }
};
