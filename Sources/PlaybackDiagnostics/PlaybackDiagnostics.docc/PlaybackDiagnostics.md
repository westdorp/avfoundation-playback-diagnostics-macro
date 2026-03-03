# ``PlaybackDiagnostics``

Aggregate `AVPlayerItem` failure and log surfaces into one diagnostics stream.

## Overview

`@PlaybackDiagnostics` normalizes diagnostics across:

- `AVPlayerItem.error`
- failed-to-end notifications
- error/access logs

Generated members expose both stream and snapshot access:

- `playbackDiagnostics`
- `latestDiagnosticsContext`
- `latestFailureContext`

## Usage

```swift
@PlaybackDiagnostics
@MainActor
final class ItemDiagnostics {
    let item: AVPlayerItem
}
```

## Contract

`@PlaybackDiagnostics` requires:

- `@MainActor final class`
- stored `let item: AVPlayerItem`
- no existing `init(item: AVPlayerItem)`
- no existing `deinit`
- all additional stored properties initialized at declaration time (optional `var` properties can rely on implicit `nil` initialization)

## Availability

`@PlaybackDiagnostics` is available on macOS 26+, iOS 26+, tvOS 26+, watchOS 26+, and visionOS 26+.

## Topics

- ``PlaybackDiagnostics()``
