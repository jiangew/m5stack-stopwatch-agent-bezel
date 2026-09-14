#include <ArduinoJson.h>
#include <cassert>
#include "WorkspaceMode.h"
using namespace workspace_mode;
Command command(const char* json) {
  StaticJsonDocument<256> doc;
  assert(!deserializeJson(doc, json));
  return parse(doc.as<JsonObjectConst>());
}
int main() {
  // Rejecting Home prevents startup synchronization with the new companion.
  assert(command("{\"mode\":\"home\"}") != Command::Invalid);
  assert(command("{\"mode\":\"codex\",\"ttl_ms\":15000}") != Command::Invalid);
  for (const char* json : {"{\"mode\":\"home\",\"ttl_ms\":15000}",
       "{\"mode\":\"home\",\"state\":\"idle\"}",
       "{\"mode\":\"codex\",\"ttl_ms\":15000.0}",
       "{\"mode\":\"codex\",\"ttl_ms\":true}",
       "{\"mode\":\"codex\",\"ttl_ms\":-1}",
       "{\"mode\":\"codex\",\"ttl_ms\":4294967296}",
       "{\"mode\":\"codex\",\"ttl_ms\":15001}"}) {
    assert(command(json) == Command::Invalid);
  }
  Lease lease(Mode::Home);
  assert(lease.mode() == Mode::Home && lease.needsHomeSync());
  assert(!lease.apply(Command::Super, 1, 0));
  assert(!lease.apply(Command::Home, 1, 1));
  assert(lease.hostReady() && !lease.needsHomeSync());
  assert(!lease.apply(Command::Super, 2, 2));
  assert(lease.apply(Command::CodexLeased, 1, 3));
  assert(!lease.apply(Command::CodexLeased, 1, 4));
  assert(!lease.expire(15003));
  assert(lease.expire(15004) && lease.mode() == Mode::Home);
  assert(!lease.hostReady() && lease.needsHomeSync());
  assert(!lease.apply(Command::Super, 1, 15005));
  lease.apply(Command::Home, 1, 15006);
  assert(lease.apply(Command::Hermes, 1, 15007));
  assert(!lease.disconnect(2));
  assert(lease.disconnect(1) && lease.mode() == Mode::Home);
  lease.apply(Command::Home, 3, 0xfffffff0u);
  lease.apply(Command::Super, 3, 0xfffffff0u);
  assert(!lease.expire(14983));
  assert(lease.expire(14984));
  lease.apply(Command::Home, 3, 15000);
  assert(!lease.expire(30000));
  assert(!lease.hostReady() && lease.needsHomeSync());
  Lease legacy;
  assert(legacy.mode() == Mode::Codex);
  assert(!legacy.apply(Command::Home, 1, 0));
  assert(!legacy.apply(Command::CodexLeased, 1, 0));
  assert(legacy.apply(Command::Super, 1, 0));
  assert(legacy.apply(Command::Codex, 2, 1));
}
