import Darwin
import Foundation

enum NavigationDiagnosticStage: String {
    case nativeInput = "native_input", superInput = "super_input", hermesInput = "hermes_input"
    case centerInput = "center_input"
    case up, down, left, right
    case selectionRejected = "selection_rejected"
    case waitingRejected = "waiting_rejected"
    case foregroundRejected = "foreground_rejected"
    case accessibilityRejected = "accessibility_rejected"
    case accessibilityAllowed = "accessibility_allowed"
    case identityRejected = "identity_rejected"
    case submissionFailed = "submission_failed"
    case submitted
    case sequenceAccepted = "sequence_accepted", sequenceBusy = "sequence_busy"
}

@MainActor
final class NavigationDiagnostics {
    private let uptime: () -> TimeInterval
    private let log: (String) -> Void
    private var startedAt: TimeInterval?
    private var count = 0
    private var stopped = false

    init(uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         log: @escaping (String) -> Void) {
        self.uptime = uptime
        self.log = log
    }

    func arm() {
        guard !stopped, startedAt == nil else { return }
        let now = uptime()
        guard now.isFinite else { return }
        startedAt = now
    }

    func stop() { stopped = true }

    func record(_ stage: NavigationDiagnosticStage) {
        guard !stopped, let startedAt, count < 120 else { return }
        let elapsed = uptime() - startedAt
        guard elapsed.isFinite, elapsed >= 0, elapsed < 300 else { return }
        count += 1
        log("NAV \(stage.rawValue)")
    }

    func recordInput(_ event: CompanionShortcutEvent) {
        switch event {
        case .openHermes: record(.centerInput)
        case let .navigation(origin, direction):
            record(origin == .super ? .superInput : .hermesInput)
            switch direction {
            case .up: record(.up)
            case .down: record(.down)
            case .left: record(.left)
            case .right: record(.right)
            }
        case .up, .down, .left, .right: record(.nativeInput)
        }
    }
}

// Created and retained only by the real watch lifecycle. No second watch or
// LaunchAgent argument changes are needed to opt into a bounded trace.
@MainActor
final class NavigationDiagnosticSignal {
    private var source: DispatchSourceSignal?
    private let diagnostics: NavigationDiagnostics
    private var stopped = false

    init(diagnostics: NavigationDiagnostics) { self.diagnostics = diagnostics }

    func start() {
        guard !stopped, source == nil else { return }
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.stopped else { return }
                self.diagnostics.arm()
            }
        }
        self.source = source
        source.resume()
    }

    func stop() {
        stopped = true
        diagnostics.stop()
        source?.cancel()
        source = nil
        // Keep SIGUSR1 ignored during shutdown, so queued signals cannot kill
        // the process while quota/HID cleanup is completing.
    }
}
