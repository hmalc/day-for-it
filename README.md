# Day For It iOS Infrastructure

This repository is split into:

- `dayforitKit/`: Swift Package containing domain logic (`PleasantnessEngine`, `WeatherCore`).
- `dayforitApp/`: SwiftUI iOS app target source, resources, and tests.
- `project.yml`: XcodeGen manifest for generating the `.xcodeproj`.

## Generate the Xcode project

1. Install XcodeGen (`brew install xcodegen`) if not already installed.
2. From this folder run:

```bash
xcodegen generate
```

3. Open `dayforit.xcodeproj` in Xcode.

## Notes

- Deployment target is iOS 17.
- App depends on local Swift package products `PleasantnessEngine` and `WeatherCore`.
- If command-line builds fail, accept Xcode license first:

```bash
sudo xcodebuild -license
```
