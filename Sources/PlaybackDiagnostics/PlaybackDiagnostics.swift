/// Stable marker namespace for the `PlaybackDiagnostics` module.
///
/// Use this type when you need a concrete symbol reference to verify module linking
/// without triggering macro expansion.
public enum PlaybackDiagnosticsModule: Sendable {
    /// Human-readable module identifier for compile-time contract checks.
    public static let name = "PlaybackDiagnostics"
}

/// Generates unified playback diagnostics aggregation for `AVPlayerItem` failure and log surfaces.
///
/// Use this macro when you want one diagnostics event stream and one latest-context snapshot
/// instead of reading `error`, failure notifications, and logs independently.
///
/// ```swift
/// @PlaybackDiagnostics
/// @MainActor
/// final class ItemDiagnostics {
///     let item: AVPlayerItem
/// }
/// ```
///
/// Role map:
/// - `item`: Source `AVPlayerItem`.
/// - `playbackDiagnostics`: Stream of normalized diagnostics events.
/// - `latestDiagnosticsContext`: Always-updating snapshot.
/// - `latestFailureContext`: Failure-only snapshot (`nil` until failure).
///
/// Contract:
/// - Apply to a `@MainActor final class`.
/// - Declare a stored `let item: AVPlayerItem`.
/// - Note: This macro is unavailable on platform versions earlier than the listed availability
///   and will fail at compile time when used there.
@available(macOS 26, iOS 26, tvOS 26, watchOS 26, visionOS 26, *)
// Private generated implementation details are emitted with an underscore prefix.
@attached(member, names: named(PlaybackDiagnosticEvent), named(PlaybackFailureContext), named(playbackDiagnostics), named(latestDiagnosticsContext), named(latestFailureContext), named(init), named(deinit), prefixed(_))
@attached(extension, conformances: Sendable)
public macro PlaybackDiagnostics() = #externalMacro(
    module: "PlaybackDiagnosticsMacroPlugin",
    type: "PlaybackDiagnosticsMacro"
)
