#pragma once
#include <string>
#include <cwchar>
class wxString {
  std::wstring v_;
public:
  wxString() = default;
  wxString(const wchar_t* s): v_(s) {}
  explicit wxString(const std::string& s): v_(s.begin(), s.end()) {}
  std::string str() const { return std::string(v_.begin(),v_.end()); }
  wxString operator+(const wxString& rhs) const { wxString r; r.v_=v_+rhs.v_; return r; }
  static wxString Format(const wchar_t* fmt,int n) { wchar_t buf[256]{}; std::swprintf(buf,256,fmt,n); return wxString(buf); }
};
