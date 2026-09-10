import AppKit
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
    func emit(
        _ command: WorkspaceNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool
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

    convenience init(diagnose: @escaping (NavigationDiagnosticStage) -> Void = { _ in }) {
        self.init(
            frontmostIdentity: {
                Self.identity(for: NSWorkspace.shared.frontmostApplication)
            },
            identityForProcess: { processIdentifier in
                Self.identity(for: NSRunningApplication(processIdentifier: processIdentifier))
            },
            poster: CoreGraphicsProcessKeySequencePoster(),
            diagnose: diagnose
        )
    }

    init(
        frontmostIdentity: @escaping FrontmostIdentity,
        identityForProcess: @escaping IdentityForProcess,
        poster: ProcessKeySequencePosting,
        diagnose: @escaping (NavigationDiagnosticStage) -> Void = { _ in }
    ) {
        self.frontmostIdentity = frontmostIdentity
        self.identityForProcess = identityForProcess
        self.poster = poster
        self.diagnose = diagnose
    }

    func emit(
        _ command: WorkspaceNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool {
        guard identity.bundleIdentifier == command.profile.bundleIdentifier,
              frontmostIdentity() == identity,
              identityForProcess(identity.processIdentifier) == identity else {
            diagnose(.identityRejected)
            return false
        }

        let keyCode: CGKeyCode
        let flags: CGEventFlags
        switch command {
        case .previousProject:
            keyCode = CGKeyCode(kVK_UpArrow)
            flags = [.maskControl, .maskAlternate]
        case .nextProject:
            keyCode = CGKeyCode(kVK_DownArrow)
            flags = [.maskControl, .maskAlternate]
        case .nextTab:
            keyCode = CGKeyCode(kVK_RightArrow)
            flags = [.maskControl, .maskAlternate]
        case .previousHermesTab:
            keyCode = CGKeyCode(kVK_Tab)
            flags = [.maskControl, .maskShift]
        case .nextHermesTab:
            keyCode = CGKeyCode(kVK_Tab)
            flags = [.maskControl]
        case .confirmHermesSelection:
            keyCode = CGKeyCode(kVK_Control)
            flags = [.maskControl]
        }
        // Hermes commits its session picker when Control is released. Clearing
        // this flag is essential for a modifier-up event; never use Return.
        let keyUpFlags: CGEventFlags = command == .confirmHermesSelection ? [] : flags
        let submitted = poster.post(
            [
                ProcessKeyStroke(keyCode: keyCode, keyDown: true, flags: flags),
                ProcessKeyStroke(keyCode: keyCode, keyDown: false, flags: keyUpFlags),
            ],
            to: identity.processIdentifier
        )
        diagnose(submitted ? .submitted : .submissionFailed)
        return submitted
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
