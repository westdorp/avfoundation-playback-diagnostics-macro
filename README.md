# PlaybackDiagnostics

`PlaybackDiagnostics` provides the `@PlaybackDiagnostics` macro for unified diagnostics aggregation from `AVPlayerItem` failure and log surfaces.

## What This Package Provides

- `@PlaybackDiagnostics` macro for generating:
  - normalized diagnostics event types,
  - `playbackDiagnostics` async event stream,
  - `latestDiagnosticsContext` snapshot,
  - `latestFailureContext` snapshot,
  - notification/log observation lifecycle scaffolding.

## Contract

`@PlaybackDiagnostics` must be applied to a declaration that satisfies all of the following:

- `@MainActor final class`
- stored instance property `let item: AVPlayerItem`
- no existing `init(item: AVPlayerItem)` declaration
- no existing `deinit` declaration
- any additional stored properties must be initialized at declaration time (implicit `nil` initialization for optional `var` properties is supported)

## Availability

`@PlaybackDiagnostics` is available on:

- macOS 26+
- iOS 26+
- tvOS 26+
- watchOS 26+
- visionOS 26+

## Example

```swift
import AVFoundation
import PlaybackDiagnostics

@PlaybackDiagnostics
@MainActor
final class ItemDiagnostics {
    let item: AVPlayerItem
}
```

## Package Integration

Add this package as a SwiftPM dependency and depend on the `PlaybackDiagnostics` product.
