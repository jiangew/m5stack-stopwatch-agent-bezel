import Darwin
import Foundation

/// Installed only for real watch mode; cleanup executes on the main RunLoop.
@MainActor
final class WatchTerminationSignal {
    private let handler: @MainActor () -> Void
    private var sources: [DispatchSourceSignal] = []
    private var stopped = false

    init(handler: @MainActor @escaping () -> Void) { self.handler = handler }

    func start() {
        guard sources.isEmpty, !stopped else { return }
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal:number,queue:.main)
            source.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, !self.stopped else { return }
                    self.stop()
                    self.handler()
                }
            }
            sources.append(source)
            source.resume()
        }
    }

    func stop() {
        stopped = true
        sources.forEach { $0.cancel() }; sources.removeAll()
        // Ignore pending signals until exit so they cannot interrupt key cleanup.
    }
}
