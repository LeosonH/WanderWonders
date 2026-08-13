# Wander Wonders V1 toolchain

This is the reproducible local toolchain recorded for Step 1. The project has no third-party Swift package dependency; `Package.resolved` records that empty dependency set.

| Tool | Observed version | Required use |
|---|---|---|
| Xcode | 26.6 (Build 17F113) | Project generation, simulator build, tests, archive later |
| Swift | 6.3.3 | Swift 6 language mode and strict concurrency |
| XcodeGen | 2.45.4 | Generate `WanderWonders.xcodeproj` from `project.yml` |
| iOS deployment target | 17.0 | Native iPhone target |

The final bundle identifier, team, provider values, and signing material remain owner inputs. The committed xcconfig files contain safe example values only.

## Reproduce

```bash
xcodegen generate --spec project.yml
WW_DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=26.0' Scripts/build_wander.sh
```

If the local simulator name or OS differs, choose an available iPhone destination and set `WW_DESTINATION`; this changes only the local test destination, not the project contract.
