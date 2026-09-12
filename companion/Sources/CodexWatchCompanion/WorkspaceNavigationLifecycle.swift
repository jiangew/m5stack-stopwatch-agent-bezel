import Foundation

/// Owns the key emitter only during a real watch run.
@MainActor
final class WorkspaceNavigationLifecycle {
    private let observer: ForegroundApplicationObserving
    private let emitter: ProcessTargetedKeyEmitting
    private var started = false
    private var stopped = false

    init(observer: ForegroundApplicationObserving, emitter: ProcessTargetedKeyEmitting) {
        self.observer = observer
        self.emitter = emitter
    }

    func start() {
        guard !started, !stopped else { return }
        started = true
        observer.start { [weak self] _ in self?.cancel() }
    }

    func cancel() {
        guard started, !stopped else { return }
        emitter.cancel()
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        if started { observer.stop() }
        emitter.stop()
        started = false
    }
}
