#include "note_clipboard.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cstring>
#include <string>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;

HGLOBAL AllocateClipboardData(const void* data, size_t bytes) {
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
  if (!memory) return nullptr;
  void* target = GlobalLock(memory);
  if (!target) {
    GlobalFree(memory);
    return nullptr;
  }
  std::memcpy(target, data, bytes);
  GlobalUnlock(memory);
  return memory;
}

std::string ReadUtf8(UINT format) {
  HANDLE memory = GetClipboardData(format);
  if (!memory) return {};
  const SIZE_T size = GlobalSize(memory);
  const auto* data = static_cast<const char*>(GlobalLock(memory));
  if (!data) return {};
  // Clipboard data belongs to other apps; do not assume a trailing zero.
  const auto* end = static_cast<const char*>(std::memchr(data, 0, size));
  std::string value(data, end ? static_cast<size_t>(end - data) : size);
  GlobalUnlock(memory);
  return value;
}
}  // namespace

void RegisterNoteClipboard(flutter::FlutterViewController* controller) {
  const HWND owner = controller->view()->GetNativeWindow();
  const UINT format = RegisterClipboardFormatW(L"BetterNotes.Document.v1");
  const UINT html_format = RegisterClipboardFormatW(L"HTML Format");
  flutter::MethodChannel<Value> channel(controller->engine()->messenger(),
                                       "betternotes/clipboard",
                                       &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler([owner, format, html_format](const auto& call, auto result) {
    if (call.method_name() != "write" && call.method_name() != "read" &&
        call.method_name() != "read_html") {
      result->NotImplemented();
      return;
    }
    if (!format || !OpenClipboard(owner)) {
      result->Error("clipboard_busy", "Windows clipboard is unavailable.");
      return;
    }
    if (call.method_name() == "read" || call.method_name() == "read_html") {
      const std::string data =
          ReadUtf8(call.method_name() == "read" ? format : html_format);
      CloseClipboard();
      result->Success(Value(data));
      return;
    }
    const auto* args = call.arguments() ? std::get_if<Map>(call.arguments()) : nullptr;
    const auto text_it = args ? args->find(Value("text")) : Map::const_iterator();
    const auto data_it = args ? args->find(Value("data")) : Map::const_iterator();
    const auto* text = args && text_it != args->end()
                           ? std::get_if<std::string>(&text_it->second) : nullptr;
    const auto* data = args && data_it != args->end()
                           ? std::get_if<std::string>(&data_it->second) : nullptr;
    if (!text || !data) {
      CloseClipboard();
      result->Error("invalid_argument", "Expected text and document data.");
      return;
    }
    const int length = MultiByteToWideChar(CP_UTF8, 0, text->data(),
                                           static_cast<int>(text->size()), nullptr, 0);
    std::wstring wide(length, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, text->data(), static_cast<int>(text->size()),
                        wide.data(), length);
    HGLOBAL plain = AllocateClipboardData(wide.c_str(), (wide.size() + 1) * sizeof(wchar_t));
    HGLOBAL rich = AllocateClipboardData(data->c_str(), data->size() + 1);
    const auto html_it = args->find(Value("html"));
    const auto* html = html_it != args->end()
                           ? std::get_if<std::string>(&html_it->second) : nullptr;
    HGLOBAL html_data = html && html_format && !html->empty()
                            ? AllocateClipboardData(html->c_str(), html->size() + 1)
                            : nullptr;
    // Allocate before replacing the clipboard, and publish both formats under
    // one lock with a real window owner (required by SetClipboardData).
    bool success = false;
    if (plain && rich && EmptyClipboard()) {
      if (SetClipboardData(CF_UNICODETEXT, plain)) {
        plain = nullptr;  // Windows now owns this allocation.
        success = true;
        if (SetClipboardData(format, rich)) rich = nullptr;
        if (html_data && SetClipboardData(html_format, html_data)) {
          html_data = nullptr;
        }
      }
    }
    if (plain) GlobalFree(plain);
    if (rich) GlobalFree(rich);
    if (html_data) GlobalFree(html_data);
    CloseClipboard();
    if (success) {
      result->Success();
    } else {
      result->Error("clipboard_write", "Could not copy the selected text.");
    }
  });
}
