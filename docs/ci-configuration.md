# Native CI availability

Linux repository validation does not qualify the iOS app. The native workflow reports an unavailable gate on an ordinary Linux runner instead of waiting indefinitely for an unregistered label.

Register a trusted `macos-latest` runner for this repository and verify Xcode, CoreSimulator and the quality toolchain before setting the repository variable `IOS_RUNNER_ENABLED=true`. The native job then retains SwiftFormat lint, SwiftLint, simulator tests and unsigned archive validation. The availability flag alone is not native qualification; the native job must also pass.
