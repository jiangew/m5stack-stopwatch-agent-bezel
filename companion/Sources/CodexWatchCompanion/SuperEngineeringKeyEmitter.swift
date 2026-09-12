import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation

struct ProcessKeyStroke: Equatable {
    let keyCode: CGKeyCode
    let keyDown: Bool
    let flags: CGEventFlags
}

@MainActor
protocol ProcessKeySequencePosting: AnyObject {
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool
}

@MainActor
protocol ProcessTargetedKeyEmitting: AnyObject {
    func cancel()
    func stop()
    func emit(
        _ command: WorkspaceNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool
}

extension ProcessTargetedKeyEmitting {
    func cancel() {}
    func stop() { cancel() }
}

@MainActor
final class CoreGraphicsProcessKeySequencePoster: ProcessKeySequencePosting {
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        var events: [CGEvent] = []
        events.reserveCapacity(strokes.count)
        for stroke in strokes {
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: stroke.keyCode,
                keyDown: stroke.keyDown
            ) else { return false }
            event.flags = stroke.flags
            events.append(event)
        }
        for event in events {
            event.postToPid(processIdentifier)
        }
        return true
    }
}

@MainActor
final class SystemProcessTargetedKeyEmitter: ProcessTargetedKeyEmitting {
    typealias FrontmostIdentity = () -> ApplicationIdentity?
    typealias IdentityForProcess = (pid_t) -> ApplicationIdentity?

    private let frontmostIdentity: FrontmostIdentity
    private let identityForProcess: IdentityForProcess
    private let poster: ProcessKeySequencePosting
    private let diagnose: (NavigationDiagnosticStage) -> Void
    private let scheduler: WorkspaceModeScheduling
    private let uptime: () -> TimeInterval
    private let trusted: () -> Bool
    private var timer: WorkspaceModeScheduledTask?
    private var generation: UInt64 = 0
    private var owner: ApplicationIdentity?
    private var held: [CGKeyCode] = []
    private var pending: [ProcessKeyStroke] = []
    private var lastStrokeAt: TimeInterval?
    private var cleaning = false
    private var stopped = false

    convenience init(diagnose: @escaping (NavigationDiagnosticStage) -> Void = { _ in }) {
        self.init(
            frontmostIdentity: {
                Self.identity(for: NSWorkspace.shared.frontmostApplication)
            },
            identityForProcess: { processIdentifier in
                Self.identity(for: NSRunningApplication(processIdentifier: processIdentifier))
            },
            poster: CoreGraphicsProcessKeySequencePoster(),
            trusted: { AXIsProcessTrusted() },
            diagnose: diagnose
        )
    }

    init(
        frontmostIdentity: @escaping FrontmostIdentity,
        identityForProcess: @escaping IdentityForProcess,
        poster: ProcessKeySequencePosting,
        scheduler: WorkspaceModeScheduling? = nil,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        trusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        diagnose: @escaping (NavigationDiagnosticStage) -> Void = { _ in }
    ) {
        self.frontmostIdentity = frontmostIdentity
        self.identityForProcess = identityForProcess
        self.poster = poster
        self.diagnose = diagnose
        self.scheduler = scheduler ?? SystemWorkspaceModeScheduler()
        self.uptime = uptime
        self.trusted = trusted
    }

    func emit(
        _ command: WorkspaceNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool {
        guard !stopped else { return false }
        guard identity.bundleIdentifier == command.profile.bundleIdentifier,
              frontmostIdentity() == identity,
              identityForProcess(identity.processIdentifier) == identity else {
            diagnose(.identityRejected)
            cancel()
            return false
        }
        guard trusted() else { diagnose(.accessibilityRejected); cancel(); return false }
        guard pending.isEmpty, !cleaning else { diagnose(.sequenceBusy); return false }
        if let owner, owner != identity { cancel(); return false }
        let strokes = WorkspaceKeySequence.strokes(for: command, controlHeld: held.contains(CGKeyCode(kVK_Control)))
        guard !strokes.isEmpty else { return true }
        owner = identity
        pending = strokes
        diagnose(.sequenceAccepted)
        armTimer()
        return advance()
    }

    private func invalidateTimer() {
        generation &+= 1; timer?.cancel(); timer = nil
    }

    private func armTimer() {
        guard timer == nil else { return }
        let epoch = generation
        timer = scheduler.scheduleRepeating(every: 0.01) { [weak self] in
            guard let self, !self.stopped, self.generation == epoch else { return }
            _ = self.advance()
        }
    }

    private func forget() {
        invalidateTimer(); owner = nil; held.removeAll(); pending.removeAll(); cleaning = false
    }

    @discardableResult private func advance() -> Bool {
        guard let owner else { return true }
        guard identityForProcess(owner.processIdentifier) == owner, trusted() else {
            diagnose(.identityRejected); forget(); return false
        }
        if !cleaning, frontmostIdentity() != owner { cancel(); return false }
        guard !pending.isEmpty else { return true }
        let now = uptime()
        guard now.isFinite else { cancel(); return false }
        if let lastStrokeAt, now - lastStrokeAt < 0.03 { return true }
        let stroke = pending.removeFirst()
        guard poster.post([stroke], to: owner.processIdentifier) else {
            diagnose(.submissionFailed)
            if cleaning { forget() } else { cancel() }
            return false
        }
        lastStrokeAt = uptime()
        if stroke.keyDown {
            if !held.contains(stroke.keyCode) { held.append(stroke.keyCode) }
        } else { held.removeAll { $0 == stroke.keyCode } }
        if pending.isEmpty {
            if !cleaning { diagnose(.submitted) }
            cleaning = false
            if held.isEmpty { forget() }
        }
        return true
    }

    func cancel() {
        guard !stopped, !cleaning else { return }
        invalidateTimer()
        pending = WorkspaceKeySequence.releases(held: held)
        guard !pending.isEmpty else { forget(); return }
        cleaning = true
        armTimer()
        _ = advance()
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        invalidateTimer()
        if let owner, identityForProcess(owner.processIdentifier) == owner, trusted() {
            // RunLoop may be exiting: best-effort immediate release, never new downs.
            for stroke in WorkspaceKeySequence.releases(held: held) {
                _ = poster.post([stroke], to: owner.processIdentifier)
            }
        }
        forget()
    }

    private static func identity(for application: NSRunningApplication?) -> ApplicationIdentity? {
        guard let application,
              let bundleIdentifier = application.bundleIdentifier,
              !application.isTerminated else { return nil }
        return ApplicationIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: bundleIdentifier
        )
    }
}
