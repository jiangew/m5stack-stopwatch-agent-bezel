// SPDX-License-Identifier: MIT
#pragma once

#include <ArduinoJson.h>

#include <cstdint>
#include <cstring>

namespace host_rpc {

enum class Method : std::uint8_t {
  Unsupported,
  SystemVersion,
  DeviceStatus,
  ThreadStatus,
  RgbConfig,
  LightsPreview,
  HostFocusedApp,
  WorkspaceMode,
  DeviceImu,
};

enum class RpcDisposition : std::uint8_t {
  Unsupported,
  ControlOnly,
  HostActivity,
};

inline Method classify(JsonObjectConst request) {
  const char* method = request["method"] | "";
  const JsonVariantConst params = request["params"];

  if (std::strcmp(method, "sys.version") == 0) {
    return Method::SystemVersion;
  }
  if (std::strcmp(method, "device.status") == 0) {
    return Method::DeviceStatus;
  }
#if defined(CODEX_STOPWATCH_HOME_IMU)
  if (std::strcmp(method, "device.imu") == 0) return Method::DeviceImu;
#endif
  if (std::strcmp(method, "v.oai.thstatus") == 0 &&
      params.is<JsonArrayConst>()) {
    return Method::ThreadStatus;
  }
  if (std::strcmp(method, "v.oai.rgbcfg") == 0 &&
      params.is<JsonObjectConst>()) {
    return Method::RgbConfig;
  }
  if (std::strcmp(method, "lights.preview") == 0) {
    return Method::LightsPreview;
  }
  if (std::strcmp(method, "host.focused_app") == 0) {
    return Method::HostFocusedApp;
  }
  if (std::strcmp(method, "host.workspace_mode") == 0) {
    return Method::WorkspaceMode;
  }
  return Method::Unsupported;
}

inline RpcDisposition disposition(Method method) {
  if (method == Method::Unsupported) return RpcDisposition::Unsupported;
  if (method == Method::WorkspaceMode || method == Method::DeviceImu)
    return RpcDisposition::ControlOnly;
  return RpcDisposition::HostActivity;
}

}  // namespace host_rpc
