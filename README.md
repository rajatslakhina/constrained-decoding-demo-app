# Constrained Decoding — Demo App

**One model, one seed, one sampler, decoded twice. Unconstrained, it writes a friendly paragraph with a float, a `"yes"` and trailing commas. With a schema mask, it writes a ticket your app can decode. Every time.**

This is the runnable companion to [**constrained-decoding-kit**](https://github.com/rajatslakhina/constrained-decoding-kit), a grammar-constrained decoding engine for on-device LLMs, written in Swift. The app consumes the library as a **remote Swift package** with the requirement *from `1.0.0`, up to next major*, exactly as a product team would. `Package.resolved` is committed, so a fresh clone resolves the exact `v1.0.0` commit.

> **No screenshots yet, and that is deliberate.** The app has not been run on a Simulator (see [Verification](#verification)). There is no `Demo/Screenshots/` folder, and nothing on this page describes an image that doesn't exist.

## What you are looking at

The app owns a ticket-triage feature's contract:

```swift
Schema.object([
    .init("title", .string(minLength: 1, maxLength: 48)),
    .init("priority", .enumeration(["low", "medium", "high", "critical"])),
    .init("estimate_hours", .integer(maxDigits: 3)),
    .init("blocking", .boolean),
    .init("labels", .array(of: .enumeration(["crash", "editor", "ipad", "performance", "ui"]), minItems: 1, maxItems: 3)),
])
```

It also owns the text the stand-in model "learned": a chatty, almost-JSON answer. The library's playground runs that model through **two instances of the same decoding engine**, with the same model, seed and sampler. One uses an unconstrained baseline. The other uses the schema as a per-token mask:

| Lane | Greedy output (seed 0) | Independent validator |
|---|---|---|
| Unconstrained | `Sure! Here's the ticket as JSON. … {"title": "Crash when rotating the photo editor", "priority": "P1", "estimate_hours": 6.5, "blocking": "yes", "labels": ["crash", "editor", "ipad",],} …` | ✗ `expected { at $` (byte 0) |
| Schema-constrained | `{"title":"Crash when rotating the photo editor","priority":"high","estimate_hours":6,"blocking":true,"labels":["crash","editor","ipad"]}` | ✓ valid |

Each lane also shows its token count, model calls, **forced steps** (only one token was legal, so the model was skipped; 7 of the constrained lane's 41 decode steps, which are 40 tokens plus EOS) and mask-cache hit rate. A strip below shows the **probability mass the mask removed at each step**. That strip is how you see where the schema and the model disagree. Here the model wanted `"P1"`, `6.5` and `"yes"`, and the schema made it say `"high"`, `6` and `true`. Exactly four steps cross the strip's 99% guide line: those three, plus the very first, where the model wanted to open with prose. Property-name steps run high too (92–97%), so the guide line is what separates them from the four. Across the free-text title the strip stays under 6%. The output is valid. Whether it is *right* is a separate question, and the strip shows you where to ask it.

**Run sweep** decodes 20 seeds at temperature 1.4 in both lanes. The library's test suite pins the result: **0/20** valid unconstrained and **20/20** valid constrained.

## Why this matters

Apple's guided generation covers only Apple's system model. If your app ships an open-weights model, structured output becomes a component someone on your team owns, whether that means bridging an existing grammar engine (llama.cpp's GBNF grammars, XGrammar, llguidance) or owning one in Swift. You can retry and hope, or you can make invalid output unrepresentable. The library README covers the build-vs-buy trade-off, the guarantees (validity, termination, no dead ends, reproducibility, concurrency safety), how each is tested, and the alternatives it rejected.

## Design decisions

- **The app owns the contract; the library owns the mechanism.** The schema and the model's reference text live in `DemoApp.swift`. The library's `ConstrainedDecodingPlayground` takes them as a `PlaygroundScenario`. This is the split a product team would use: features declare what they need, and the platform team ships the engine. *Rejected:* a playground with a hard-coded scenario. That would show the library demoing itself, not being consumed.
- **A remote package with a version range plus a committed `Package.resolved`, not an exact pin, a branch or a local path.** `upToNextMajor` from `1.0.0` lets patch fixes in on purpose. `Package.resolved` keeps every clone on the reviewed `v1.0.0` commit until someone updates it. CI enforces this with `-onlyUsePackageVersionsFromResolvedFile`, so a missing or stale resolved file fails the build instead of quietly drifting to a newer 1.x. Tracking a branch would make every build resolve whatever `main` is that day. A local path would hide whether the published package actually works.
- **A deterministic stand-in model instead of a real one.** The point is the decoder's guarantees, and those have to be reproducible. Every number this README quotes is pinned by a library test: the launch-screen outputs of both lanes, the 41 / 7 / 34 step, forced-step and model-call counts, the masked-mass spike list and title bound, and the 0/20 vs 20/20 sweep. Other on-screen figures (the unconstrained lane's counts, cache hit rates, any other seed or sampler) are computed live and not pinned. A real on-device model would add download size, device variance and an unpinnable output. `TokenizerMapping`/`MappedModel` in the library is the seam where a real MLX, llama.cpp or Core ML backend plugs in.
- **Two decoder instances side by side, not a before/after toggle.** Both lanes run concurrently with the same model, seed and sampler. The only difference you can see is the mask.

## How to run it

1. `git clone https://github.com/rajatslakhina/constrained-decoding-demo-app.git`
2. Open `Demo.xcodeproj` in Xcode 16 or later. Xcode fetches `constrained-decoding-kit` `v1.0.0` from GitHub.
3. Select the **Demo** scheme and any iOS 17+ Simulator.
4. Build and Run (⌘R). Both lanes decode on launch. Change the sampler or seed and tap **Decode**, or tap **Run sweep**.

## Project layout

```
Demo.xcodeproj/                      # XCRemoteSwiftPackageReference → constrained-decoding-kit, upToNextMajor from 1.0.0
  xcshareddata/xcschemes/Demo.xcscheme
  project.xcworkspace/xcshareddata/swiftpm/Package.resolved   # exact v1.0.0 revision
Demo/DemoApp.swift                   # @main App: owns the schema + model reference, hosts the playground
.github/workflows/ci.yml             # resolve the remote package, build for generic iOS Simulator
```

## Verification

What has and has not been verified, stated separately:

- **Builds for iOS Simulator: yes, in CI.** The [Actions](../../actions) workflow runs on `macos-15` in two steps.
  - It resolves `constrained-decoding-kit` from GitHub with `-onlyUsePackageVersionsFromResolvedFile`, so it must use the committed `Package.resolved` revision `258e961` (tag `v1.0.0`).
  - It then runs `xcodebuild build -scheme Demo -destination 'generic/platform=iOS Simulator'`.

  That proves the remote package resolves and the app, including the library's SwiftUI module, compiles against it. It does not prove the app runs.
- **Ran on a Simulator: no.** Computer-use access to Xcode and Simulator was granted for this run. Xcode, however, had an unrelated project open, and this pipeline does not operate an IDE that holds someone else's work. So nobody has watched this app launch, and there are no screenshots.
- **What the launch screen shows: pinned by tests, not observed.** The outputs in the table above, the 41 / 7 / 34 counts, the masked-mass spikes and the 0/20 vs 20/20 sweep are asserted by the library's test suite. That suite runs on Linux and macOS in the library's CI, using the same schema and reference text as `DemoApp.swift`. This is a weaker claim than seeing it on a phone, and it is stated that way on purpose.
- **Review:** three rounds of independent review, applied before push. The third round's fixes were not reviewed again, because the process stops at three rounds. The library README lists what those fixes were.

## License

MIT
