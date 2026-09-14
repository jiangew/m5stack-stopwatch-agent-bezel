#include <ArduinoJson.h>

#include <cassert>
#include <cstdint>
#include <limits>

#include "WorkspaceMode.h"

namespace {

workspace_mode::Command parseParams(const char* json) {
  StaticJsonDocument<256> document;
  if (deserializeJson(document, json) ||
      !document.is<JsonObjectConst>()) {
    return workspace_mode::Command::Invalid;
  }
  return workspace_mode::parse(document.as<JsonObjectConst>());
}

void testHermesLeaseAndStrictParameters() {
  using namespace workspace_mode;
  const auto hermes = parseParams(R"({"mode":"hermes","ttl_ms":15000})");
  assert(hermes != Command::Invalid);
  const char* invalid[] = {
      R"({"mode":"hermes"})", R"({"mode":"hermes","ttl_ms":true})",
      R"({"mode":"hermes","ttl_ms":15000.0})",
      R"({"mode":"hermes","ttl_ms":-1})",
      R"({"mode":"hermes","ttl_ms":4294967296})",
      R"({"mode":"hermes","ttl_ms":"15000"})",
      R"({"mode":"hermes","ttl_ms":14999})",
      R"({"mode":"hermes","ttl_ms":15000,"extra":1})"};
  for (const auto* json : invalid) assert(parseParams(json) == Command::Invalid);
  Lease lease;
  assert(lease.apply(Command::Super, 7, 0));
  assert(!lease.apply(hermes, 8, 1));
  assert(lease.mode() == Mode::Super);
  assert(lease.apply(hermes, 7, 100));
  assert(lease.mode() != Mode::Super && lease.mode() != Mode::Codex);
  assert(!lease.apply(Command::Super, 8, 1000));
  assert(!lease.apply(hermes, 7, 2000));
  assert(!lease.disconnect(8));
  assert(!lease.expire(16999));
  assert(lease.expire(17000));
  assert(lease.apply(hermes, 8, 18000));
  assert(lease.apply(Command::Super, 8, 18001));
  assert(lease.apply(hermes, 8, 18002));
  assert(lease.apply(Command::Codex, 9, 18003));
  assert(lease.apply(hermes, 8, 18004));
  assert(lease.disconnect(8));
  const auto start = std::numeric_limits<std::uint32_t>::max() - 9999;
  assert(lease.apply(hermes, 8, start));
  assert(!lease.expire(4999));
  assert(lease.expire(5000));
}

void testStrictParsing() {
  using workspace_mode::Command;

  assert(parseParams(R"({"mode":"super","ttl_ms":15000})") ==
         Command::Super);
  assert(parseParams(R"({"mode":"codex"})") == Command::Codex);

  assert(parseParams(R"({})") == Command::Invalid);
  assert(parseParams(R"({"mode":"super"})") == Command::Invalid);
  assert(parseParams(R"({"mode":"codex","ttl_ms":15000})") ==
         Command::CodexLeased);
  assert(parseParams(
             R"({"mode":"super","ttl_ms":15000,"label":"SUPER"})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":"15000"})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":-1})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":15000.0})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":15000.5})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":4294967296})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"super","ttl_ms":14999})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":42,"ttl_ms":15000})") ==
         Command::Invalid);
  assert(parseParams(R"({"mode":"SUPER","ttl_ms":15000})") ==
         Command::Invalid);
  assert(parseParams(R"([])") == Command::Invalid);
}

void testOwnershipAndRefresh() {
  using workspace_mode::Command;
  using workspace_mode::Lease;
  using workspace_mode::Mode;

  Lease lease;
  assert(lease.mode() == Mode::Codex);
  assert(!lease.apply(Command::Invalid, 7, 100));

  assert(lease.apply(Command::Super, 7, 100));
  assert(lease.mode() == Mode::Super);

  // The owner can renew without requesting a redraw.
  assert(!lease.apply(Command::Super, 7, 10'000));
  assert(!lease.expire(24'999));

  // Another connection cannot take ownership or refresh the deadline.
  assert(!lease.apply(Command::Super, 8, 24'000));
  assert(lease.expire(25'000));
  assert(lease.mode() == Mode::Codex);

  // Any valid Codex command can fail closed out of SUPER mode.
  assert(lease.apply(Command::Super, 7, 30'000));
  assert(lease.apply(Command::Codex, 8, 30'001));
  assert(lease.mode() == Mode::Codex);
  assert(!lease.apply(Command::Codex, 7, 30'002));

  Lease invalidHeartbeatLease;
  assert(invalidHeartbeatLease.apply(Command::Super, 7, 100));
  assert(!invalidHeartbeatLease.apply(
      parseParams(R"({"mode":"super","ttl_ms":15000,"extra":true})"),
      7, 9'000));
  assert(!invalidHeartbeatLease.expire(15'099));
  assert(invalidHeartbeatLease.expire(15'100));
}

void testDisconnectAndExpiryBoundary() {
  using workspace_mode::Command;
  using workspace_mode::Lease;
  using workspace_mode::Mode;

  Lease lease;
  assert(lease.apply(Command::Super, 11, 1'000));
  assert(!lease.disconnect(12));
  assert(lease.mode() == Mode::Super);
  assert(!lease.expire(15'999));
  assert(lease.expire(16'000));
  assert(lease.mode() == Mode::Codex);

  assert(lease.apply(Command::Super, 11, 20'000));
  assert(lease.disconnect(11));
  assert(lease.mode() == Mode::Codex);
  assert(!lease.disconnect(11));
}

void testMillisRollover() {
  using workspace_mode::Command;
  using workspace_mode::Lease;
  using workspace_mode::Mode;

  constexpr std::uint32_t start =
      std::numeric_limits<std::uint32_t>::max() - 9'999;
  Lease lease;
  assert(lease.apply(Command::Super, 21, start));
  assert(!lease.expire(4'999));
  assert(lease.expire(5'000));
  assert(lease.mode() == Mode::Codex);
}

}  // namespace

int main() {
  assert(parseParams(R"({"mode":"hermes","ttl_ms":15000,"state":"idle"})") != workspace_mode::Command::Invalid);
  using namespace workspace_mode;
  for (const auto* invalid : {
      R"({"mode":"hermes","ttl_ms":15000,"state":null})",
      R"({"mode":"hermes","ttl_ms":15000,"state":"active"})",
      R"({"mode":"super","ttl_ms":15000,"state":"idle"})",
      R"({"mode":"codex","state":"idle"})",
      R"({"mode":"hermes","ttl_ms":15000,"state":"idle","extra":1})"}) {
    assert(parseParams(invalid) == Command::Invalid);
  }
  Lease presentation;
  const auto idle = parseParams(R"({"mode":"hermes","ttl_ms":15000,"state":"idle"})");
  const auto opening = parseParams(R"({"mode":"hermes","ttl_ms":15000,"state":"opening"})");
  const auto error = parseParams(R"({"mode":"hermes","ttl_ms":15000,"state":"error"})");
  assert(presentation.apply(idle, 7, 0));
  assert(presentation.mode() == Mode::HermesIdle);
  assert(!presentation.apply(opening, 8, 100));
  assert(presentation.apply(opening, 7, 100));
  assert(!presentation.apply(opening, 7, 200));
  assert(presentation.apply(error, 7, 300));
  assert(!presentation.expire(15299));
  assert(presentation.expire(15300));
  testHermesLeaseAndStrictParameters();
  testStrictParsing();
  testOwnershipAndRefresh();
  testDisconnectAndExpiryBoundary();
  testMillisRollover();
}
