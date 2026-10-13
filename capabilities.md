# Capabilities Configuration

## Analysis
Based on guide + us.md analysis:
- "HealthKit sync (weight/sleep/steps)" → HealthKit entitlement + usage strings
- "Reminders / notifications / Shot Day ritual / Live Activity" → Notifications (local; no push cert needed at runtime, aps-environment added for CloudKit connectivity)
- "SnapLog: camera scan vial labels / meal photos" → Camera usage string
- "Face ID app lock" → NSFaceIDUsageDescription
- "iCloud optional sync (local-first, CloudKit optional enhancement)" → iCloud/CloudKit entitlements + graceful degradation
- "Privacy-first, no data collection" → PrivacyInfo.xcprivacy, no tracking
- "PDF export" → no capability needed
- "StoreKit 2 three tiers" → In-App Purchase (no entitlement needed for StoreKit 2; configured at ASC app record creation)

## Auto-Configured Capabilities
| Capability | Status | Method |
|------------|--------|--------|
| Bundle ID com.zzoutuo.ShotJoy registration | ✅ Configured | ASC API (App ID 6U3633YXYK) |
| HealthKit | ✅ Configured | ASC API capability + entitlements + 4 usage strings (camera/FaceID/health read/health write) |
| iCloud (CloudKit, XCODE_6) | ✅ Entitlements + ASC capability | Container iCloud.com.zzoutuo.ShotJoy — ASC API cannot create containers; Xcode auto-registers container at first Archive/device build |
| Push Notifications (aps-environment) | ✅ Configured | ASC API capability + aps-environment: development entitlement |
| Background Modes (remote-notification) | ✅ Configured | Info.plist UIBackgroundModes (required by CloudKit push) |
| Camera | ✅ Configured | NSCameraUsageDescription |
| Face ID | ✅ Configured | NSFaceIDUsageDescription |
| Privacy manifest | ✅ Configured | PrivacyInfo.xcprivacy (no tracking, no collection; UserDefaults CA92.1, FileTimestamp C617.1) |
| Outgoing network (GLM worker) | ✅ No entitlement needed | ATS default allows HTTPS |
| App Icon | ✅ Configured | Agnes Image 2.1 Flash, RGB no-alpha, single 1024 catalog |

## Manual Configuration Required
| Capability | Status | Steps |
|------------|--------|-------|
| iCloud container registration | ⏳ One-time auto | Container `iCloud.com.zzoutuo.ShotJoy` auto-registers by Xcode at first Archive or device build with user's Apple ID logged in (ASC API cannot create containers). App works 100% local without it (graceful degradation). |
| CloudKit schema deployment | ⏳ Later | After TestFlight usage, deploy Dev schema to Production via CloudKit Dashboard (can be browser-automated on request). |
| ASC app record + IAP products | ⏳ PHASE 3/upload | Created at upload time via ios-appstore-upload / ios-asc-metadata-pricing |

## No Configuration Needed
- Location, Siri, Family Controls, App Groups (no widget target in MVP)

## Verification
- Build succeeded after configuration: ✅ (simulator, iOS 26.4 iPhone 16)
- All entitlements correct: ✅ (xcodegen-generated ShotJoy.entitlements)
- Signing verification (generic/platform=iOS): ✅ PASSED — Manual signing, real identity "Apple Development: he zhou (VX3Q75X27B)" (SHA-1 856B30D5E... matches ASC cert L93DL58WM3), profile "ShotJoy Dev" 5Q66GDKU7A with HealthKit+aps+iCloud-services
- Signing note: automatic signing via xcodebuild API-key auth hits known "Authentication failed" limitation on this machine (documented in ios-appstore-upload SKILL.md); Manual-signing verification exercises the identical codesign path. Archive-time: Xcode auto-provisioning (user account) or exportArchive re-sign via API key.
- DEVELOPMENT_TEAM: JP4TN5PTS3 baked at project level (all targets inherit)
- PrivacyInfo.xcprivacy: App target covered
- Bundle ID: com.zzoutuo.ShotJoy (user-mandated; overrides guide's app.shotjoy.ios)
