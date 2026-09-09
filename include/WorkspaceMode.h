// SPDX-License-Identifier: MIT
#pragma once

#include <ArduinoJson.h>

#include <cstdint>
#include <cstring>

namespace workspace_mode {

constexpr std::uint32_t kLeaseMs = 15000;

enum class Mode : std::uint8_t { Codex, Super, Hermes, HermesIdle, HermesOpening, HermesError };
enum class Command : std::uint8_t { Invalid, Codex, Super, Hermes, HermesIdle, HermesOpening, HermesError };

constexpr bool isHermes(Mode mode) {
  return mode == Mode::Hermes || mode == Mode::HermesIdle ||
         mode == Mode::HermesOpening || mode == Mode::HermesError;
}

constexpr bool awaitingHermes(Mode mode) {
  return isHermes(mode) && mode != Mode::Hermes;
}

constexpr bool isDirectional(Mode mode) {
  return mode == Mode::Super || isHermes(mode);
}

constexpr bool silencesAgentTransitions(Mode previous, Mode next) {
  return isDirectional(previous) || isDirectional(next);
}

inline Command parse(JsonObjectConst params) {
  const JsonVariantConst modeValue = params["mode"];
  if (!modeValue.is<const char*>()) return Command::Invalid;

  const char* mode = modeValue.as<const char*>();
  if (std::strcmp(mode, "codex") == 0) {
    return params.size() == 1 ? Command::Codex : Command::Invalid;
  }
  const bool super = std::strcmp(mode, "super") == 0;
  const bool hermes = std::strcmp(mode, "hermes") == 0;
  const bool hasState = params.containsKey("state");
  if ((!super && !hermes) || (hasState && !hermes) ||
      params.size() != (hasState ? 3u : 2u)) {
    return Command::Invalid;
  }

  const JsonVariantConst ttl = params["ttl_ms"];
  if (!ttl.is<JsonInteger>() || ttl.as<JsonInteger>() != kLeaseMs) {
    return Command::Invalid;
  }
  if (hasState) {
    if (!params["state"].is<const char*>()) return Command::Invalid;
    const char* state = params["state"].as<const char*>();
    if (std::strcmp(state, "idle") == 0) return Command::HermesIdle;
    if (std::strcmp(state, "opening") == 0) return Command::HermesOpening;
    if (std::strcmp(state, "error") == 0) return Command::HermesError;
    return Command::Invalid;
  }
  return super ? Command::Super : Command::Hermes;
}

class Lease {
 public:
  bool apply(Command command, std::uint16_t connectionId,
             std::uint32_t nowMs) {
    if (command == Command::Invalid) return false;
    if (command == Command::Codex) return clear();

    if (mode_ != Mode::Codex &&
        (!ownerValid_ || ownerConnectionId_ != connectionId)) {
      return false;
    }

    Mode requested = Mode::Hermes;
    switch (command) {
      case Command::Super: requested = Mode::Super; break;
      case Command::HermesIdle: requested = Mode::HermesIdle; break;
      case Command::HermesOpening: requested = Mode::HermesOpening; break;
      case Command::HermesError: requested = Mode::HermesError; break;
      default: break;
    }
    const bool changed = mode_ != requested;
    mode_ = requested;
    ownerConnectionId_ = connectionId;
    ownerValid_ = true;
    refreshedAtMs_ = nowMs;
    return changed;
  }

  bool disconnect(std::uint16_t connectionId) {
    if (!ownerValid_ || ownerConnectionId_ != connectionId) return false;
    return clear();
  }

  bool expire(std::uint32_t nowMs) {
    if (mode_ == Mode::Codex ||
        static_cast<std::uint32_t>(nowMs - refreshedAtMs_) < kLeaseMs) {
      return false;
    }
    return clear();
  }

  Mode mode() const { return mode_; }

 private:
  bool clear() {
    const bool changed = mode_ != Mode::Codex;
    mode_ = Mode::Codex;
    ownerConnectionId_ = 0;
    ownerValid_ = false;
    refreshedAtMs_ = 0;
    return changed;
  }

  Mode mode_ = Mode::Codex;
  std::uint16_t ownerConnectionId_ = 0;
  bool ownerValid_ = false;
  std::uint32_t refreshedAtMs_ = 0;
};

}  // namespace workspace_mode
