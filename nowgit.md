# Git Repositories

## Main App (iOS Application)

| Item | Value |
|------|-------|
| **Repository Name** | ShotJoy |
| **Git URL** | git@github.com:asunnyboy861/ShotJoy.git |
| **Repo URL** | https://github.com/asunnyboy861/ShotJoy |
| **Visibility** | Public |
| **Primary Language** | Swift |
| **GitHub Pages** | ✅ **ENABLED** (from `/docs` folder) |

## Policy Pages (Deployed from Main Repository /docs)

| Page | URL | Status |
|------|-----|--------|
| Landing Page | https://asunnyboy861.github.io/ShotJoy/ | ✅ Active |
| Support | https://asunnyboy861.github.io/ShotJoy/support.html | ✅ Active |
| Privacy Policy | https://asunnyboy861.github.io/ShotJoy/privacy.html | ✅ Active |
| Terms of Use | https://asunnyboy861.github.io/ShotJoy/terms.html | ✅ Active (subscription app) |

## Repository Structure

```
ShotJoy/
├── ShotJoy.xcodeproj/             # Xcode Project (xcodegen-generated)
├── ShotJoy/                       # Swift Source Files
│   ├── App/                       # Entry + theme
│   ├── Models/                    # SwiftData models + 100+ compound presets
│   ├── Engine/                    # DrawGuard + PlasmaCurve (pure, unit-tested)
│   ├── Services/                  # StoreKit2, HealthKit, AI router, GLM worker, BYO
│   ├── Views/                     # Today/DrawGuard/BodyMap/SnapLog/Insights/Meds/Paywall/Settings
│   ├── Assets.xcassets/           # AppIcon (Agnes-generated)
│   ├── PrivacyInfo.xcprivacy
│   └── GLMProxySecret.txt         # ⚠️ LOCAL ONLY (.gitignore) — devKey, excluded from Release builds
├── ShotJoyTests/                  # DrawGuard unit tests (10 cases)
├── docs/                          # Policy Pages (GitHub Pages source)
│   ├── index.html
│   ├── support.html
│   ├── privacy.html
│   └── terms.html
├── .github/workflows/
│   └── deploy.yml
├── project.yml                    # xcodegen source of truth
├── us.md
├── capabilities.md
├── icon.md
├── price.md
├── app_review_info.md
├── nowgit.md
├── keytext.md                     # ⚠️ EXCLUDED from repo (.gitignore — confidential ASO strategy)
├── improvement_plan_*.md          # ⚠️ EXCLUDED from repo (.gitignore)
└── COMPETITOR_REPORT.md           # ⚠️ EXCLUDED from repo (.gitignore)
```
