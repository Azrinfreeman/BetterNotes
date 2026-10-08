#include "jump_list.h"

#include <windows.h>
#include <shobjidl.h>
#include <propkey.h>
#include <propvarutil.h>
#include <wrl/client.h>

#include <string>

using Microsoft::WRL::ComPtr;

void RegisterNewNoteTask() {
  std::wstring executable(32768, L'\0');
  const DWORD length =
      GetModuleFileNameW(nullptr, executable.data(),
                         static_cast<DWORD>(executable.size()));
  if (length == 0 || length >= executable.size()) {
    return;
  }
  executable.resize(length);

  ComPtr<ICustomDestinationList> list;
  if (FAILED(CoCreateInstance(CLSID_DestinationList, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&list))) ||
      FAILED(list->SetAppID(kBetterNotesAppId))) {
    return;
  }

  UINT slots = 0;
  ComPtr<IObjectArray> removed;
  if (FAILED(list->BeginList(&slots, IID_PPV_ARGS(&removed)))) {
    return;
  }

  ComPtr<IObjectCollection> collection;
  ComPtr<IShellLinkW> link;
  ComPtr<IPropertyStore> properties;
  bool success =
      SUCCEEDED(CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                                 CLSCTX_INPROC_SERVER,
                                 IID_PPV_ARGS(&collection))) &&
      SUCCEEDED(CoCreateInstance(CLSID_ShellLink, nullptr,
                                 CLSCTX_INPROC_SERVER,
                                 IID_PPV_ARGS(&link))) &&
      SUCCEEDED(link->SetPath(executable.c_str())) &&
      SUCCEEDED(link->SetArguments(L"--new-note")) &&
      SUCCEEDED(link->SetIconLocation(executable.c_str(), 0)) &&
      SUCCEEDED(link->SetDescription(L"Create a new BetterNotes note")) &&
      SUCCEEDED(link.As(&properties));

  if (success) {
    PROPVARIANT title;
    if (SUCCEEDED(InitPropVariantFromString(L"New note", &title))) {
      success = SUCCEEDED(properties->SetValue(PKEY_Title, title)) &&
                SUCCEEDED(properties->Commit());
      PropVariantClear(&title);
    } else {
      success = false;
    }
  }

  ComPtr<IObjectArray> tasks;
  if (success) {
    success = SUCCEEDED(collection->AddObject(link.Get())) &&
              SUCCEEDED(collection.As(&tasks)) &&
              SUCCEEDED(list->AddUserTasks(tasks.Get())) &&
              SUCCEEDED(list->CommitList());
  }
  if (!success) {
    list->AbortList();
  }
}
