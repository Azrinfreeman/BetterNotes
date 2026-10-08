#ifndef RUNNER_STARTUP_REGISTRATION_H_
#define RUNNER_STARTUP_REGISTRATION_H_

#include <windows.h>

#include <optional>

// Uses the current user's Run key, so this setting does not require elevation.
std::optional<bool> IsAutoStartEnabled(LSTATUS* error);
LSTATUS SetAutoStartEnabled(bool enabled);

#endif  // RUNNER_STARTUP_REGISTRATION_H_
