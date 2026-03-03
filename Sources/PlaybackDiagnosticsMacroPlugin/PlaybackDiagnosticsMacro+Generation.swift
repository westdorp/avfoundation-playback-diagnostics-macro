import MacroPluginUtilities
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// NOTE: This macro uses string-based declaration generation for readability of large
// synthesized blocks. Snapshot expansion tests act as the safety net for generated syntax.
extension PlaybackDiagnosticsMacro {
    /// Builds the generated event enum declaration.
    static func buildPlaybackDiagnosticEventDeclaration() -> String {
        """
        /// A normalized diagnostics event emitted from AVPlayerItem failure surfaces.
        enum PlaybackDiagnosticEvent: Sendable, CustomStringConvertible {
            /// Emitted when playback fails to reach end time.
            case failedToPlayToEnd(PlaybackFailureContext)
            /// Emitted when a new AVPlayerItem error-log entry is recorded.
            case newErrorLogEntry(PlaybackFailureContext)
            /// Emitted when a new AVPlayerItem access-log entry is recorded.
            case newAccessLogEntry(PlaybackFailureContext)

            /// The captured diagnostics context associated with this event.
            var context: PlaybackFailureContext {
                switch self {
                case let .failedToPlayToEnd(context),
                     let .newErrorLogEntry(context),
                     let .newAccessLogEntry(context):
                    return context
                }
            }

            /// A stable case label for UI and logging surfaces.
            var label: String {
                switch self {
                case .failedToPlayToEnd:
                    return "failedToPlayToEnd"
                case .newErrorLogEntry:
                    return "newErrorLogEntry"
                case .newAccessLogEntry:
                    return "newAccessLogEntry"
                }
            }

            var description: String {
                switch self {
                case let .failedToPlayToEnd(context):
                    return "failedToPlayToEnd(\\(context))"
                case let .newErrorLogEntry(context):
                    return "newErrorLogEntry(\\(context))"
                case let .newAccessLogEntry(context):
                    return "newAccessLogEntry(\\(context))"
                }
            }
        }
        """
    }

    /// Builds the generated diagnostics snapshot declaration.
    static func buildPlaybackFailureContextDeclaration() -> String {
        """
        /// Captures a diagnostics snapshot from AVPlayerItem failure and log surfaces.
        struct PlaybackFailureContext: Sendable, CustomStringConvertible {
            /// Canonical diagnostics health states.
            enum HealthState: String, Sendable {
                case healthy
                case failure
            }

            /// The current `item.error` value.
            let itemError: Error?
            /// The error payload received from failed-to-end notification user info.
            let failedToPlayToEndError: Error?
            /// Count of `errorLog` events at capture time.
            let errorLogEventCount: Int
            /// Count of `accessLog` events at capture time.
            let accessLogEventCount: Int

            /// Creates a diagnostics snapshot from the AVPlayerItem diagnostics surfaces.
            static func capture(item: AVPlayerItem, failedToPlayToEndError: Error?) -> Self {
                Self(
                    itemError: item.error,
                    failedToPlayToEndError: failedToPlayToEndError,
                    errorLogEventCount: item.errorLog()?.events.count ?? 0,
                    accessLogEventCount: item.accessLog()?.events.count ?? 0
                )
            }

            /// The first error to surface, preferring failed-to-end payloads.
            var primaryError: Error? {
                failedToPlayToEndError ?? itemError
            }

            /// Indicates whether any failure surface currently reports an error.
            var hasFailure: Bool {
                primaryError != nil
            }

            /// The strongly typed health state derived from current failure surfaces.
            var healthState: HealthState {
                hasFailure ? .failure : .healthy
            }

            /// A short health label for display surfaces.
            var healthLabel: String {
                healthState.rawValue
            }

            /// A compact summary suitable for diagnostics panels.
            var summary: String {
                "\\(healthLabel) | error log entries: \\(errorLogEventCount) | access log entries: \\(accessLogEventCount)"
            }

            /// A compact single-line error summary.
            var errorSummary: String {
                guard let primaryError else {
                    return "none"
                }
                return String(String(describing: primaryError).prefix(120))
            }

            var description: String {
                "PlaybackFailureContext(itemError: \\(String(describing: itemError)), failedToPlayToEndError: \\(String(describing: failedToPlayToEndError)), errorLogEventCount: \\(errorLogEventCount), accessLogEventCount: \\(accessLogEventCount))"
            }
        }
        """
    }

    /// Builds the generated event emission helper declaration.
    static func buildEmitDiagnosticsDeclaration() -> String {
        """
        private func _emitDiagnostics(_ event: PlaybackDiagnosticEvent) {
            let context = event.context
            latestDiagnosticsContext = context
            if context.hasFailure {
                latestFailureContext = context
            }
            _diagnosticsContinuation.yield(event)
        }
        """
    }

    /// Builds the generated initializer declaration that wires stream setup and observers.
    static func buildInitializerDeclaration() -> String {
        """
        init(item: AVPlayerItem) {
            // Phase 1: Stream setup.
            self.item = item
            let (playbackDiagnostics, diagnosticsContinuation) = AsyncStream<PlaybackDiagnosticEvent>.makeStream()
            self.playbackDiagnostics = playbackDiagnostics
            self._diagnosticsContinuation = diagnosticsContinuation

            // Phase 2: Initial snapshot capture.
            let initialContext = PlaybackFailureContext.capture(item: item, failedToPlayToEndError: nil)
            self.latestDiagnosticsContext = initialContext
            self.latestFailureContext = if initialContext.hasFailure {
                initialContext
            } else {
                nil
            }

            // Phase 3: Notification observers.
            let _failedToEndNotificationToken = NotificationCenter.default.addObserver(forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: item, queue: .main) { [weak self] notification in
                let failedToPlayToEndError = notification.userInfo.flatMap { userInfo in
                    userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
                }
                // Hop onto the main actor before mutating diagnostics state.
                Task { @MainActor [weak self, failedToPlayToEndError] in
                    guard let self else {
                        return
                    }
                    let context = PlaybackFailureContext.capture(item: self.item, failedToPlayToEndError: failedToPlayToEndError)
                    self._emitDiagnostics(.failedToPlayToEnd(context))
                }
            }
            self._notificationTokens.append(_failedToEndNotificationToken)
            let _newErrorLogEntryNotificationToken = NotificationCenter.default.addObserver(forName: AVPlayerItem.newErrorLogEntryNotification, object: item, queue: .main) { [weak self] _ in
                // Hop onto the main actor before mutating diagnostics state.
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    let failedToPlayToEndError = self.latestFailureContext?.failedToPlayToEndError
                    let context = PlaybackFailureContext.capture(item: self.item, failedToPlayToEndError: failedToPlayToEndError)
                    self._emitDiagnostics(.newErrorLogEntry(context))
                }
            }
            self._notificationTokens.append(_newErrorLogEntryNotificationToken)
            let _newAccessLogEntryNotificationToken = NotificationCenter.default.addObserver(forName: AVPlayerItem.newAccessLogEntryNotification, object: item, queue: .main) { [weak self] _ in
                // Hop onto the main actor before mutating diagnostics state.
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    let failedToPlayToEndError = self.latestFailureContext?.failedToPlayToEndError
                    let context = PlaybackFailureContext.capture(item: self.item, failedToPlayToEndError: failedToPlayToEndError)
                    self._emitDiagnostics(.newAccessLogEntry(context))
                }
            }
            self._notificationTokens.append(_newAccessLogEntryNotificationToken)
        }
        """
    }
}
