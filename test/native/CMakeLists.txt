cmake_minimum_required(VERSION 3.14)
project(BetterNotesNativeTests LANGUAGES CXX)
enable_testing()
add_executable(flutter_accessibility_guard_test
  flutter_accessibility_guard_test.cpp
  ../../windows/runner/flutter_accessibility_guard.cpp
)
target_compile_features(flutter_accessibility_guard_test PRIVATE cxx_std_17)
target_link_libraries(flutter_accessibility_guard_test PRIVATE comctl32 user32)
add_test(NAME flutter_accessibility_guard COMMAND flutter_accessibility_guard_test)
