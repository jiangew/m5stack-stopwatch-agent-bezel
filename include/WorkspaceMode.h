// SPDX-License-Identifier: MIT
#pragma once

#include <ArduinoJson.h>

#include <cstdint>
#include <cstring>

namespace workspace_mode {

constexpr std::uint32_t kLeaseMs = 15000;

// Append values to preserve the existing firmware enum ordinals.
enum class Mode : std::uint8_t {
  Codex, Super, Hermes, HermesIdle, HermesOpening, HermesError, Home, Deepseek,
  CodexIdle, CodexOpening, CodexError, DeepseekIdle, DeepseekOpening,
  DeepseekError, SuperIdle, SuperOpening, SuperError
};
enum class Command : std::uint8_t {
  Invalid, Codex, Super, Hermes, HermesIdle, HermesOpening, HermesError, Home,
  CodexLeased, Deepseek, CodexIdle, CodexOpening, CodexError, DeepseekIdle,
  DeepseekOpening, DeepseekError, SuperIdle, SuperOpening, SuperError
};

constexpr bool isCodex(Mode mode) {
  return mode == Mode::Codex || mode == Mode::CodexIdle ||
         mode == Mode::CodexOpening || mode == Mode::CodexError;
}

constexpr bool isDeepseek(Mode mode) {
  return mode == Mode::Deepseek || mode == Mode::DeepseekIdle ||
         mode == Mode::DeepseekOpening || mode == Mode::DeepseekError;
}

constexpr bool isSuper(Mode mode) {
  return mode == Mode::Super || mode == Mode::SuperIdle ||
         mode == Mode::SuperOpening || mode == Mode::SuperError;
}

constexpr bool isIdle(Mode mode) {
  return mode == Mode::CodexIdle || mode == Mode::DeepseekIdle ||
         mode == Mode::SuperIdle || mode == Mode::HermesIdle;
}

constexpr bool isOpening(Mode mode) {
  return mode == Mode::CodexOpening || mode == Mode::DeepseekOpening ||
         mode == Mode::SuperOpening || mode == Mode::HermesOpening;
}

constexpr bool isError(Mode mode) {
  return mode == Mode::CodexError || mode == Mode::DeepseekError ||
         mode == Mode::SuperError || mode == Mode::HermesError;
}

constexpr bool awaitingLaunch(Mode mode) {
  return isIdle(mode) || isOpening(mode) || isError(mode);
}

constexpr bool canOpen(Mode mode) {
  return isIdle(mode) || isError(mode);
}

constexpr bool isHermes(Mode mode) {
  return mode == Mode::Hermes || mode == Mode::HermesIdle ||
         mode == Mode::HermesOpening || mode == Mode::HermesError;
}

constexpr bool awaitingHermes(Mode mode) {
  return isHermes(mode) && mode != Mode::Hermes;
}

constexpr bool isDirectional(Mode mode) {
  return isDeepseek(mode) || isSuper(mode) || isHermes(mode) ||
         awaitingLaunch(mode);
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
  const bool codex = std::strcmp(mode, "codex") == 0;
  const bool deepseek = std::strcmp(mode, "deepseek") == 0;
  const bool super = std::strcmp(mode, "super") == 0;
  const bool hermes = std::strcmp(mode, "hermes") == 0;
  const bool hasState = params.containsKey("state");
  if (codex && params.size() == 1) return Command::Codex;
  if ((!codex && !deepseek && !super && !hermes) ||
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
    if (std::strcmp(state, "idle") == 0)
      return codex ? Command::CodexIdle : deepseek ? Command::DeepseekIdle :
             super ? Command::SuperIdle : Command::HermesIdle;
    if (std::strcmp(state, "opening") == 0)
      return codex ? Command::CodexOpening : deepseek ? Command::DeepseekOpening :
             super ? Command::SuperOpening : Command::HermesOpening;
    if (std::strcmp(state, "error") == 0)
      return codex ? Command::CodexError : deepseek ? Command::DeepseekError :
             super ? Command::SuperError : Command::HermesError;
    return Command::Invalid;
  }
  return codex ? Command::CodexLeased : deepseek ? Command::Deepseek :
         super ? Command::Super : Command::Hermes;
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
      case Command::Deepseek: requested = Mode::Deepseek; break;
      case Command::Super: requested = Mode::Super; break;
      case Command::HermesIdle: requested = Mode::HermesIdle; break;
      case Command::HermesOpening: requested = Mode::HermesOpening; break;
      case Command::HermesError: requested = Mode::HermesError; break;
      case Command::CodexIdle: requested = Mode::CodexIdle; break;
      case Command::CodexOpening: requested = Mode::CodexOpening; break;
      case Command::CodexError: requested = Mode::CodexError; break;
      case Command::DeepseekIdle: requested = Mode::DeepseekIdle; break;
      case Command::DeepseekOpening: requested = Mode::DeepseekOpening; break;
      case Command::DeepseekError: requested = Mode::DeepseekError; break;
      case Command::SuperIdle: requested = Mode::SuperIdle; break;
      case Command::SuperOpening: requested = Mode::SuperOpening; break;
      case Command::SuperError: requested = Mode::SuperError; break;
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
