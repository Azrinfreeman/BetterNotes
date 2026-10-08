#include "startup_registration.h"

#include <cwchar>
#include <string>

namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kValueName[] = L"BetterNotes";

std::optional<std::wstring> StartupCommand(LSTATUS* error) {
  std::wstring executable(32768, L'\0');
  const DWORD length = GetModuleFileNameW(
      nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0 || length >= executable.size()) {
    *error = length == 0 ? GetLastError() : ERROR_FILENAME_EXCED_RANGE;
    return std::nullopt;
  }
  executable.resize(length);
  std::wstring command = L"\"" + executable + L"\"";
  // Windows limits Run value command lines to 260 characters.
  if (command.size() > 260) {
    *error = ERROR_FILENAME_EXCED_RANGE;
    return std::nullopt;
  }
  *error = ERROR_SUCCESS;
  return command;
}

}  // namespace

std::optional<bool> IsAutoStartEnabled(LSTATUS* error) {
  const auto expected = StartupCommand(error);
  if (!expected) return std::nullopt;

  DWORD bytes = 0;
  LSTATUS status = RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName,
                                RRF_RT_REG_SZ, nullptr, nullptr, &bytes);
  if (status == ERROR_FILE_NOT_FOUND) {
    *error = ERROR_SUCCESS;
    return false;
  }
  if (status != ERROR_SUCCESS) {
    *error = status;
    return std::nullopt;
  }

  std::wstring command(bytes / sizeof(wchar_t), L'\0');
  status = RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName, RRF_RT_REG_SZ,
                        nullptr, command.data(), &bytes);
  if (status != ERROR_SUCCESS) {
    *error = status;
    return std::nullopt;
  }
  command.resize(std::wcslen(command.c_str()));
  *error = ERROR_SUCCESS;
  return _wcsicmp(command.c_str(), expected->c_str()) == 0;
}

LSTATUS SetAutoStartEnabled(bool enabled) {
  if (!enabled) {
    const LSTATUS status =
        RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kValueName);
    return status == ERROR_FILE_NOT_FOUND ? ERROR_SUCCESS : status;
  }

  LSTATUS error = ERROR_SUCCESS;
  const auto command = StartupCommand(&error);
  if (!command) return error;

  HKEY key = nullptr;
  error = RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                          KEY_SET_VALUE, nullptr, &key, nullptr);
  if (error != ERROR_SUCCESS) return error;
  error = RegSetValueExW(
      key, kValueName, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command->c_str()),
      static_cast<DWORD>((command->size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
  return error;
}
