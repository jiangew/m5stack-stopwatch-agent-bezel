#include <ArduinoJson.h>

#include <cassert>

#include "HostRpcRequest.h"

namespace {

host_rpc::Method classify(const char* json) {
  StaticJsonDocument<256> request;
  if (deserializeJson(request, json) || !request.is<JsonObjectConst>()) {
    return host_rpc::Method::Unsupported;
  }
  return host_rpc::classify(request.as<JsonObjectConst>());
}

}  // namespace

int main() {
  using host_rpc::Method;
  using host_rpc::RpcDisposition;

  assert(classify(R"({"method":"sys.version","id":1})") ==
         Method::SystemVersion);
  assert(classify(R"({"method":"device.status","params":{},"id":2})") ==
         Method::DeviceStatus);
  assert(classify(R"({"method":"v.oai.thstatus","params":[],"id":3})") ==
         Method::ThreadStatus);
  assert(classify(R"({"method":"v.oai.rgbcfg","params":{},"id":4})") ==
         Method::RgbConfig);
  assert(classify(R"({"method":"lights.preview","id":5})") ==
         Method::LightsPreview);
  assert(classify(R"({"method":"host.focused_app","id":6})") ==
         Method::HostFocusedApp);
  assert(classify(
             R"({"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":7})") ==
         Method::WorkspaceMode);

  // Once the exact method is recognized, parameter validation belongs to the
  // workspace parser so malformed calls receive Invalid params, not Method not
  // found.
  assert(classify(
             R"({"method":"host.workspace_mode","params":[],"id":8})") ==
         Method::WorkspaceMode);

  // A parseable method name is not enough to establish trusted host activity.
  assert(classify(R"({"method":"attacker.probe","params":{},"id":9})") ==
         Method::Unsupported);
  assert(classify(R"({"method":"v.oai.thstatus","params":{},"id":10})") ==
         Method::Unsupported);
  assert(classify(R"({"method":"v.oai.rgbcfg","params":[],"id":11})") ==
         Method::Unsupported);
  assert(classify(R"({"method":42,"params":{},"id":12})") ==
         Method::Unsupported);
  assert(classify(R"(["device.status"])") == Method::Unsupported);

  assert(host_rpc::disposition(Method::WorkspaceMode) ==
         RpcDisposition::ControlOnly);
  assert(host_rpc::disposition(Method::DeviceStatus) ==
         RpcDisposition::HostActivity);
  assert(host_rpc::disposition(Method::SystemVersion) ==
         RpcDisposition::HostActivity);
  assert(host_rpc::disposition(Method::ThreadStatus) ==
         RpcDisposition::HostActivity);
  assert(host_rpc::disposition(Method::RgbConfig) ==
         RpcDisposition::HostActivity);
  assert(host_rpc::disposition(Method::LightsPreview) ==
         RpcDisposition::HostActivity);
  assert(host_rpc::disposition(Method::HostFocusedApp) ==
         RpcDisposition::HostActivity);
  assert(host_rpc::disposition(Method::Unsupported) ==
         RpcDisposition::Unsupported);
#if defined(CODEX_STOPWATCH_HOME_IMU)
  assert(host_rpc::disposition(classify(R"({"method":"device.imu","id":20})"))==RpcDisposition::ControlOnly);
#else
  assert(classify(R"({"method":"device.imu","id":20})")==Method::Unsupported);
#endif
}
