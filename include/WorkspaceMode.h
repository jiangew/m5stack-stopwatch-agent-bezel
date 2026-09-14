// SPDX-License-Identifier: MIT
#pragma once

#include <ArduinoJson.h>

#include <cstdint>
#include <cstring>

namespace workspace_mode {

constexpr std::uint32_t kLeaseMs = 15000;

enum class Mode : std::uint8_t { Codex, Super, Hermes, HermesIdle, HermesOpening, HermesError, Home };
enum class Command : std::uint8_t { Invalid, Codex, Super, Hermes, HermesIdle, HermesOpening, HermesError, Home, CodexLeased };

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
  return previous == Mode::Home || next == Mode::Home ||
         isDirectional(previous) || isDirectional(next);
}

inline Command parse(JsonObjectConst params) {
  const JsonVariantConst modeValue = params["mode"];
  if (!modeValue.is<const char*>()) return Command::Invalid;

  const char* mode = modeValue.as<const char*>();
  if (std::strcmp(mode, "home") == 0) {
    return params.size() == 1 ? Command::Home : Command::Invalid;
  }
  if (std::strcmp(mode, "codex") == 0) {
    if (params.size() == 1) return Command::Codex;
    const JsonVariantConst ttl = params["ttl_ms"];
    return params.size() == 2 && ttl.is<JsonInteger>() &&
                   ttl.as<JsonInteger>() == kLeaseMs
               ? Command::CodexLeased : Command::Invalid;
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
  explicit Lease(Mode fallback = Mode::Codex)
      : fallback_(fallback), mode_(fallback), needsHomeSync_(fallback == Mode::Home) {}

  bool apply(Command command, std::uint16_t connectionId,
             std::uint32_t nowMs) {
    if (command == Command::Invalid) return false;
    if (fallback_ == Mode::Codex) {
      if (command == Command::Home || command == Command::CodexLeased) return false;
      if (command == Command::Codex) return clear();
    } else {
      if (ownerValid_ && ownerConnectionId_ != connectionId) return false;
      if (needsHomeSync_ && command != Command::Home) return false;
    }

    if (fallback_ == Mode::Codex && mode_ != Mode::Codex &&
        (!ownerValid_ || ownerConnectionId_ != connectionId)) {
      return false;
    }

    Mode requested = Mode::Hermes;
    switch (command) {
      case Command::Home: requested = Mode::Home; break;
      case Command::Codex:
      case Command::CodexLeased: requested = Mode::Codex; break;
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
    needsHomeSync_ = false;
    return changed;
  }

  bool disconnect(std::uint16_t connectionId) {
    if (!ownerValid_ || ownerConnectionId_ != connectionId) return false;
    return clear();
  }

  bool expire(std::uint32_t nowMs) {
    if (!ownerValid_ || (fallback_ == Mode::Codex && mode_ == Mode::Codex) ||
        static_cast<std::uint32_t>(nowMs - refreshedAtMs_) < kLeaseMs) {
      return false;
    }
    return clear();
  }

  Mode mode() const { return mode_; }
  bool needsHomeSync() const { return needsHomeSync_; }
  bool hostReady() const { return ownerValid_ && !needsHomeSync_; }

 private:
  bool clear() {
    const bool changed = mode_ != fallback_;
    mode_ = fallback_;
    ownerConnectionId_ = 0;
    ownerValid_ = false;
    refreshedAtMs_ = 0;
    needsHomeSync_ = fallback_ == Mode::Home;
    return changed;
  }

  Mode fallback_;
  Mode mode_;
  bool needsHomeSync_;
  std::uint16_t ownerConnectionId_ = 0;
  bool ownerValid_ = false;
  std::uint32_t refreshedAtMs_ = 0;
};

}  // namespace workspace_mode
