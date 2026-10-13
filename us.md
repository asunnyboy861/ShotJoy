# ShotJoy - iOS Development Guide

> **App Name**: ShotJoy
> **Subtitle**: GLP-1 & Peptide Shot Tracker
> **Bundle ID**: `com.zzoutuo.ShotJoy` (per ios-app-developer skill preset: `${BUNDLE_PREFIX}<APP_NAME>` — overrides guide's suggestion)
> **Minimum iOS**: 26.0 (required by Foundation Models framework)
> **Target Market**: United States (global English users)
> **Category**: Health & Fitness, Age 16+
> **Slogan**: *Every shot, a win.*
> **Compliance Red Line**: This product is a "recording & education tool", NOT a medical device. NEVER give dose recommendations, diagnoses, or treatment advice. Every drug-related screen must carry the Medical Disclaimer. Comply with App Review Guidelines 1.4.1 (medical), 5.1.1 (privacy).

---

## Executive Summary

ShotJoy is a one-app journey tracker for GLP-1 pen users and peptide vial users: shots + peptides + meal photos + symptom insights + doctor-ready PDF reports. Dose math NEVER depends on the network — a deterministic local engine (DrawGuard) does all conversions; AI only does recognition and explanation.

**Key differentiators (vs Pep AI / Shotsy):**
1. **Full-journey aggregation** — pen + peptide + meal photo + symptoms + weight + bloodwork on one timeline
2. **DrawGuard dose-safety engine** — sub-5-unit draw warnings with re-watering suggestions, syringe mismatch detection, mg/mcg 1000x error checks, blend vial itemized math
3. **AI Insight** (GLM-5.3-Flash) — "nausea clusters on day 2 after up-titration, and when protein < 60g" with confidence + plain-language explanation
4. **SnapLog 3-second logging** — photo the vial label → AI reads concentration/total; photo the plate → AI macro estimates with confidence gating
5. **Site intelligence** — body map rotation + "nausea scores 31% lower when injecting in abdomen" style site-reaction correlation
6. **Transparent pricing** — price page in-app, on the web, and on the store listing; free tier is genuinely usable
7. **Privacy-first** — works with no account; SwiftData local + AES-256-GCM; Face ID; optional iCloud; AI photo processing in-memory only, never persisted server-side
8. **Shot Day ritual** — Friday injection done → confetti + victory share card ("Shot Day ✅ Week 14, -23 lb")

---

## Competitive Analysis (verified 2026-09/10)

| App | Strengths | Weaknesses | Our Advantage |
|-----|-----------|------------|---------------|
| Shotsy (head, 4.8★/29-32K) | Medication plasma-level curves, charts, maintenance mode; iPhone + Android | No food log (manual daily totals only), charges for level chart & Apple Health sync, opaque pricing page | Aggregation + transparent pricing + free core |
| MeAgain | Photo meal logging, 29K ratings | **No PDF export**, IAP up to $119.99, most features behind paywall, English only | Doctor-ready PDF, free tier, transparent pricing |
| Glapp | Six-phase pen-cycle model, clinical-trial baselines | Injection-only, newest, weak platform coverage | Full journey, peptides + GLP-1 |
| Pep ($9.99/mo, $39.99/yr) | Reconstitution calculator, 75+ compound library | Subscription required for full features, weak food/symptom correlation, no AI insight | Free calculator (traffic hook), AI insights, BYO lifetime tier |
| Dose AI ($9.99/mo) | Symptom pattern analysis (self-rated best) | Small community (982 ratings) | Larger feature set, BYO tier, aggregation |
| GlucoPal ($9.99/mo, $34.99/yr) | No account required, doctor export | iPhone-only, feature breadth | Cross-device depth, AI, peptides |
| DreamMe (IAP $0.99–69.99) | Virtual pet motivation | **No export at all**, analytics shallow | PDF/CSV export, deep analytics |
| Web calculators (Regimen/My Pep Calc/FormBlends) | Free reconstitution math | No tracking, no reminders, no history — single-point tools | Calculator free + full tracking around it |

**Pricing band validated**: monthly $9.99–19.99, yearly $29.99–59.99, top IAP $119.99. Pep AI hit $60K MRR in 7 weeks; users spend $500–1000+/month on medication, so tool pricing has no resistance.

---

## ⚠️ App Store Compliance — AI Features

### Apple Intelligence (Default Free AI Backend)
This app uses Apple Intelligence (on-device Foundation Models + Private Cloud Compute) as the default AI backend. On supported devices (iPhone 15 Pro+, iOS 26+), AI features work immediately after download with zero configuration.

**iOS Version Handling**:
- **iOS 26+**: Apple Intelligence is default. AI features work out-of-the-box (free tier: 5 on-device tasks/day).
- **Simulator**: Apple Intelligence is NOT available on simulators. For testing, configure a BYO API Key in Settings.

### GLM Cloud Shared Worker (Cloud AI for Pro tier)
- All cloud AI goes through the GLM-Cloudflare shared worker `https://cramjam-api.calcs.top` (backup: `https://cramjam-proxy.iocompile67692.workers.dev`), per the config standard at https://github.com/asunnyboy861/GLM-Cloudflare
- **NEVER connect directly to api.z.ai from the app.** No GLM API key may ever be embedded in the app.
- **Prerequisite**: register `com.zzoutuo.ShotJoy` into the worker's D1 `apps` whitelist via the config guide §8 self-registration curl (one command, effective immediately; unregistered apps get 401)
- Request spec (five mandatory elements): ① `appId: "shotjoy"` ② `userId` (UUID generated on first launch, stored in Keychain) ③ test period sends `devKey` (from config repo guide §1 — never hardcode in docs); production removes devKey and sends StoreKit 2 `appTransaction` JWS ④ payload follows GLM rules: `thinking: {"level": "low"}` MANDATORY (omitting = error 1210), `max_tokens` ≥4096 text / ≥8192 vision & structured, `response_format: {"type":"json_object"}` for structured output ⑤ ignore `reasoning_content`, read `choices[0].message.content`
- Rate limits enforced worker-side: 30/hour + 200/day per `appId:userId` (anti-abuse only; subscription users effectively unlimited). On 429, show a friendly message — no local quota logic.
- Production verification: worker validates StoreKit 2 JWS (ES256 + Apple Root CA-G3 + bundleId whitelist + subscription validity, Sandbox/TestFlight supported). Send `result.jwsRepresentation` from `Transaction.currentEntitlements` (NEVER `jsonRepresentation` — causes 401).
- Weekly insights send only aggregate statistics (means/counts/correlation matrices) — never names, photos, or location.

### BYO API Key (Lifetime Tier, Multi-Provider — MANDATORY multi-vendor)
Users who buy the $39.99 lifetime tier configure their own API key. **NEVER hardcode GLM as the only provider.** Supported: GLM (Z.ai), OpenAI, DeepSeek, Gemini, Claude, and custom OpenAI-compatible endpoints. Keys stored in iOS Keychain only. AI features are unlimited for BYO users with no quota counting.

### Guideline 2.1(a) — App Completeness
- Create `app_review_info.md` with demo API key configuration instructions
- NEVER show clickable AI buttons that lead to errors when no AI backend is available
- `canGenerate` logic: `isPremium || hasAPIKey || appleIntelligenceAvailable` — no free generation counting
- Graceful degradation: when cloud quota is exhausted, auto-switch to on-device mode with a clear message — features never hard-fail

### Dead Code Prevention
- ❌ NEVER add: `freeGenerationsUsed`, `maxFreeGenerations`, `canGenerateFree`, `incrementGenerationCount()`

---

## ⚠️ App Store Compliance — Subscriptions & Medical

### Guideline 3.1.2(c) — Subscription Information
The Paywall view MUST contain:
- Functional link to Privacy Policy
- Functional link to Terms of Use (EULA)
- Subscription title, length, and price for each tier
- Auto-renewal disclosure text
- Restore Purchases button
- `showManageSubscriptions` entry point in Settings

### Guideline 1.4 — Physical Harm / Dosage Calculator Risk (CRITICAL)
Apple's guideline 1.4.2 states drug dosage calculators must come from the drug manufacturer, a hospital, university, health insurer, pharmacy, or FDA-approved entity. **ShotJoy's compliance framing (bake into every screen and metadata):**
- DrawGuard is a **"unit conversion & tracking helper for your own prescribed dose"** — the user enters THEIR prescribed dose; the app performs arithmetic conversion only (mg→mcg, concentration, syringe units)
- NEVER suggest, recommend, or optimize doses. Never compare doses to "standard" or "recommended" values
- Every calculation result screen shows: "Educational only — not medical advice. Always follow your prescriber's instructions."
- The plasma curve is labeled "Educational visualization — not for dosing decisions"
- Category: Health & Fitness (NOT Medical), Age 16+
- No weight-loss outcome claims anywhere

### BYO Key + Subscription Model
- Subscription value: "Unlock Premium Features" — NOT "Unlimited AI Generations"
- Paywall feature list: Lead with app features, not AI usage
- AI generation is ALWAYS unlimited for users with their own key

---

## Feature Inventory (MANDATORY — Every Feature Must Be Listed)

### Primary Features

| # | Feature | User Operation Flow | Data Input | Processing | Data Output | Persistence | Acceptance Criteria |
|---|---------|--------------------|------------|------------|-------------|-------------|---------------------|
| 1 | Onboarding (60s activation) | 1. Launch → Welcome page "Every shot, a win." → 2. Pick drug from large cards (Ozempic/Zepbound/peptide/other) → 3. Pick form (pen: preset strength cards; vial: photo label or manual 3 fields) → 4. Preview "Next shot: Friday 9:00" + big Enable Reminders button → 5. Today home | Drug selection, strength, BAC water mL, syringe type | Preset library lookup; DrawGuard demo calc ("your 250mcg = 10 units ✅ safe zone") | Onboarding completes in ≤60s; Today screen shows big "Record my shot 🎯" button | Compound + Vial rows created in SwiftData | Fresh install → first shot logged with confetti within 60 seconds |
| 2 | Compound/Vial management | Settings → Medications → add/edit/archive compounds & vials | Compound name/kind/half-life; vial mg, BAC mL, syringe type, reconstitution date | Preset library (100+ compounds) + user-created; validation | Compound list with vial inventory summary | `Compound`, `Vial` models (SwiftData) | Preset library browsable/searchable; user compound creatable; edits reflect everywhere |
| 3 | DrawGuard calculator | Meds → Calculator → enter vial mg / BAC mL / target mcg / syringe → Calculate | 4 numeric inputs (Decimal) | Six guards: realistic input → concentration → units → draw-too-small (<5U) with 3 re-water suggestions → syringe capacity → U-40/U-100 mismatch → blend itemized conservation | Big number "10 units" + syringe diagram + safe-zone badge + warning cards + doses remaining | Calculation history (optional) | All 6 guards unit-tested; <5U shows 3 suggested water amounts landing on 10/15/20/25/30 marks; mg↔mcg 1000x error caught |
| 4 | One-tap shot logging | Today → Shot Day card (pre-filled: dose/site/syringe) → tap ✅ | Pre-filled dose, injection site (body map), optional notes | DrawGuard validation → inventory deduction → streak increment → plasma curve update | Confetti animation + "Shot #N logged! 🔥 streak N" + victory card offer | `DoseLog` row + `Vial.remainingMG` decrement | Logging takes ≤1 tap from Shot Day card; confetti plays; inventory decreases; streak updates |
| 5 | Body map site rotation | Log shot → Body Map → tap injection site (abdomen quadrants/thighs/arms) | Site selection | Heat coloring of recent sites; highlights recommended next site (longest-uninjected); site-reaction correlation stats | SVG body map with colored dots + pulsing "next site" suggestion | `DoseLog.site` coordinates | Recommended site pulses; site history colored; correlation card appears after ≥6 logs ("nausea 31% lower at abdomen") |
| 6 | Smart reminders / Shot Day ritual | Onboarding or Settings → enable reminder → weekly Shot Day notification | Schedule (day/time), pen cadence | UNUserNotificationCenter weekly schedule + Live Activity countdown | Notification "It's Shot Day 🎯" + Today card becomes Shot Day mode | Notification settings | Notification fires at set time; tapping opens app to pre-filled Shot Day card |
| 7 | Vial inventory + restock estimate | Meds → Vial detail | Automatic deduction per logged shot | remainingMG vs dose → doses remaining → days-to-empty at cadence → restock date estimate | "8 doses left · reorder by Oct 24" badge on Today + Meds | `Vial.remainingMG` | Estimate matches actual usage; warning when ≤2 doses remain |
| 8 | Symptom logging | Today → Log symptom → pick from 40+ presets → severity slider 1-5 → save | Symptom name + severity + timestamp | Linked to latest dose (doseRef) for correlation; optional quick presets | Symptom timeline; severity colors; correlation input data | `SymptomLog` rows | 3-second entry; linked to dose; visible on timeline & weekly report |
| 9 | Weight/protein/hydration goals | Today → protein ring; Progress tab → weight log (manual or HealthKit) | Weight kg/lb; protein g target; water | HealthKit observer + manual entries; target progress math | Protein progress ring; weight trend chart (Swift Charts); goal streaks | Weight entries + goal settings | Ring reflects today's meals+manual; weight syncs both directions with HealthKit |
| 10 | HealthKit sync | Onboarding permission prompt → Settings toggle | Weight/sleep/steps read+write | HKObserverQuery + background delivery | Charts enriched with HealthKit data | HealthKit store (external) | No crash without permission; graceful empty states; data flows into charts |
| 11 | Victory share card | After logging shot → Share button | Auto: week #, streak, total loss since start | Render poster (ImageRenderer): "Shot Day ✅ Week 14 · -23 lb · streak 🔥21" | Vertical share sheet + save to Photos | none (ephemeral render) | Card renders correctly; share sheet offers Save Image / share apps |
| 12 | Face ID + local encryption | Enable in Settings → app lock; always-on field encryption | LAContext biometrics | AES-256-GCM field encryption via CryptoKit + Secure Enclave key; LAContext gate on launch | Lock screen → unlock → app | Encrypted SwiftData store | Cold launch requires Face ID when enabled; DB unreadable without key |
| 13 | PDF doctor report | Progress → Export PDF | Date range picker | Aggregate dose/symptom/weight/inventory into PDFKit document with disclaimer footer | PDF preview + share sheet | exported file (ephemeral) | PDF contains all sections + disclaimer on every page; opens in Files/preview |
| 14 | SnapLog: vial label photo | Add vial → Scan label → camera → AI extraction → confirm/correct | JPEG photo (in-memory only) | GLM vision (Pro) or on-device fallback → ParsedVial JSON → **DrawGuard cross-validation** (local formula re-check, mismatch = red warning) | Pre-filled vial form | Vial row after user confirms | Photo never persisted; AI result never written without confirmation; mismatch shows red warning |
| 15 | SnapLog: meal photo | Today → camera → meal photo → AI macros → confirm (confidence <85% → top-3 choice cards; failure → manual search fallback) | JPEG photo (in-memory only) | GLM vision (Pro) / Apple on-device (free) → macro estimate + confidence | Meal row with calories/protein/carbs/fat | `MealLog` row | Never auto-saves without confirmation; <85% confidence shows 3 candidates; offline falls back to manual search |
| 16 | AI Insight weekly report | Friday → report card arrives → envelope open animation → 3 insight cards with "why" expandable | Aggregated week data (means/counts/correlations only) | GLM reasoning (Pro) or Apple on-device summary (free) | 3 insight cards + confidence + disclaimer | Report cache (local) | Free tier: 5 on-device AI tasks/day; Pro: unlimited insights via worker; disclaimer always visible |
| 17 | Plasma education curve | Today → drug level card | Half-life (compound PK), last dose time | concentration% = 100 × 0.5^(t/t½) drawn as curve | "Drug level 72% — steady phase" card + full curve view | computed on the fly | Curve math matches unit tests; "Educational only" label always visible |
| 18 | Titration companion | Meds → Titration mode → up-titration calendar | Step-up schedule | Day counter + education cards ("day-2 nausea is common") | Calendar view + reassurance cards | Titration schedule | Education cards match dose-increase days; no medical advice anywhere |
| 19 | Paywall & pricing transparency | Triggered value-first (2nd meal photo / 1st weekly report viewed) | Tier selection | StoreKit 2 products fetch | 3-tier cards + "free forever" banner + legal links + manage subscriptions | entitlement state | Prices display exactly $9.99/mo, $49.99/yr (7-day trial), $39.99 lifetime; restore works; legal links functional |
| 20 | BYO AI configuration | Settings → AI Engine (BYO) → provider cards (GLM/OpenAI/DeepSeek/Gemini/Claude/Custom) → paste key → test connection → set text/vision default | API key, base URL (custom), model names | Keychain save; connectivity test (1 minimal request, show ✅ latency / ❌ reason); vision-capability auto-detect | Provider list with defaults marked | Keychain (keys), UserDefaults (non-secret prefs) | Test button gives specific failure reason (401=key wrong, DNS=URL wrong, 429=quota); vision tasks silently skip non-vision providers; custom tier needs baseURL+model+vision checkbox |

### Sub-Features & Detail Interactions

| # | Parent | Sub-Feature | Detail | Interaction |
|---|--------|-------------|--------|-------------|
| 3.1 | DrawGuard | Blend vials | Multiple compounds in one vial: itemized per-compound math + total conservation check | Add/remove compound rows |
| 3.2 | DrawGuard | Re-water suggestions | Units <5 → 3 water amounts that land dose exactly on 10/15/20/25/30 marks | Tap suggestion to apply |
| 3.3 | DrawGuard | Two-draw warning | Units > syringe capacity → "requires two draws" + suggest re-watering | Warning card only |
| 4.1 | Shot logging | Backfill | Missed days can be logged retroactively (never punish) | Date picker in log sheet |
| 5.1 | Body map | Site heat decay | Colors fade with age of last injection | Automatic |
| 9.1 | Goals | Pre-fill from last | Every form pre-fills last used values | Automatic |
| 14.1 | SnapLog | Privacy | Photo processed in memory, discarded after request; never saved or uploaded elsewhere | Automatic |
| 19.1 | Paywall | Value-first | Show sample insight card before purchase prompt | Automatic |
| 19.2 | Paywall | Graceful degradation | Cloud quota exhausted → auto-switch on-device + toast message | Automatic |

### Cross-Feature Dependencies

| Dependency | Source | Target | Data Passed | Trigger |
|------------|--------|--------|-------------|---------|
| Shot logged → inventory | Shot logging | Vial inventory | dose units/mg | Every successful log |
| Shot logged → plasma curve | Shot logging | Plasma education curve | dose time + amount | Every successful log |
| Shot logged → streak/share | Shot logging | Victory share card | week #, streak, weight delta | Shot Day log |
| Symptom logged → AI insight | Symptom logging | Weekly report | aggregated correlations | Weekly generation |
| Meal logged → protein ring | Meal logging | Goals ring | protein grams | Meal confirm |
| Vial scan → DrawGuard | SnapLog vial | DrawGuard validation | parsed mg/concentration | Scan confirm |
| Entitlement → AI router | StoreKit | AI Router | Pro/BYO/Free state | Any AI call |
| Face ID → app gate | App lock | Launch flow | unlock state | Cold launch |

**VERIFICATION**: Guide §3.3 MUST list = 8 items → covered by features 1-8+12-13; SHOULD = 4 items → features 14-18; pricing §8 → features 19-20. ✅ All guide features mapped.

---

## Apple Design Guidelines Compliance

- **Liquid Glass / iOS 26 native feel**: large rounded cards, glass materials, dark-mode-first (night injection scenario)
- **Dynamic Type + VoiceOver**: health users skew older — large fonts everywhere, Dose big-number 64pt bold, full accessibility labels
- **Privacy manifests**: PrivacyInfo.xcprivacy with no tracking, no collection; usage strings for HealthKit/camera/notifications/FaceID
- **HIG navigation**: single-Task TabView (Today / Progress / Meds / Settings) — first screen always 1 primary action + 3 secondary cards max
- **Error prevention over error reporting**: auto-correct with before/after display ("You entered 5, computed as 5mg = 5000mcg"), never silent fixes

## Technical Architecture

- **Language**: Swift 5.10+ / Swift 6 concurrency-safe
- **UI**: SwiftUI + Swift Charts + UIComponents (confetti via Canvas/TimelineView)
- **Data**: SwiftData + AES-256-GCM field encryption (CryptoKit, Secure Enclave key) + optional CloudKit sync
- **Health**: HealthKit (weight/sleep/steps read+write)
- **On-device AI**: FoundationModels framework (iOS 26+) — free tier 5 tasks/day, unlimited for Pro
- **Cloud AI**: GLM-5.3-Flash via GLM-Cloudflare shared worker (appId `shotjoy`; userId UUID in Keychain; StoreKit 2 JWS in production)
- **Payments**: StoreKit 2 (Pro monthly $9.99 / Pro yearly $49.99 with 7-day trial / BYO lifetime $39.99 non-consumable)
- **Notifications**: UNUserNotificationCenter + Live Activity (shot-day countdown)
- **PDF**: PDFKit
- **Math**: `Decimal` everywhere in dose paths — `Double`/`Float` FORBIDDEN in dose chains

## Module Structure

```
ShotJoy/
├── App/
│   ├── ShotJoyApp.swift            // entry, SwiftData container, Face ID gate
│   └── AppTheme.swift              // Joy Coral #FF7A59, Mint #2EC4B6, dark-first
├── Models/
│   ├── Compound.swift              // @Model: name/kind/halfLife/isPreset
│   ├── Vial.swift                  // @Model: massMG/bacWaterML/remainingMG/...
│   ├── DoseLog.swift               // @Model: dose/units/syringe/site/loggedAt
│   ├── SymptomLog.swift            // @Model: name/severity/doseRef
│   ├── MealLog.swift               // @Model: macros/confidence/source
│   ├── WeightEntry.swift           // @Model
│   └── CompoundPresets.swift       // 100+ preset compounds static library
├── Engine/
│   ├── DrawGuard.swift             // pure deterministic engine, 6 guards
│   ├── DrawGuardTests.swift        // unit tests incl. cross-check fixtures
│   └── PlasmaCurve.swift           // education curve math
├── Services/
│   ├── AIRouter.swift              // task/entitlement/quota routing
│   ├── AppleOnDeviceAI.swift       // FoundationModels wrapper
│   ├── GLMCloudService.swift       // shared worker client (appId=shotjoy)
│   ├── BYOStore.swift              // multi-provider registry + Keychain
│   ├── OpenAICompatibleAdapter.swift
│   ├── AnthropicAdapter.swift
│   ├── HealthKitService.swift
│   ├── NotificationService.swift
│   ├── CryptoService.swift         // AES-256-GCM field encryption
│   ├── FaceIDService.swift         // LAContext
│   ├── PDFReportService.swift
│   ├── ShareCardRenderer.swift
│   └── StoreService.swift          // StoreKit 2 entitlements
├── Views/
│   ├── Onboarding/
│   ├── Today/                      // Shot Day card, plasma card, protein ring
│   ├── DrawGuard/                  // calculator + big number + warnings
│   ├── BodyMap/
│   ├── SnapLog/                    // camera + confidence UI
│   ├── Insights/                   // weekly report + envelope animation
│   ├── Progress/                   // charts + PDF export
│   ├── Meds/                       // compounds/vials/inventory/titration
│   ├── Paywall/                    // 3 tiers + legal links
│   └── Settings/                   // AI engine BYO, HealthKit, FaceID, about
└── Widgets/                        // (phase 3 roadmap: not in MVP)
```

## Data Flow Diagram

### Feature: DrawGuard calculation (the safety core)
```
User Input (vial mg / BAC mL / target mcg / syringe)
  └── DrawGuardView → CalculatorViewModel
       │ Decimal-only validation
  └── DrawGuard.calculate() [pure function]
       │ Guard1 realistic input → Guard2 concentration → Guard3 units
       │ Guard4 draw<5U + 3 water suggestions → Guard5 capacity → Guard6 mismatch/blend
  └── DoseResult {concentration, volumeML, units, dosesRemaining, warnings[]}
  └── Result UI: 64pt units number + syringe diagram + badges
       │ (on confirm from shot flow)
  └── DoseLog persisted → Vial.remainingMG decremented → plasma curve refresh
```

### Feature: SnapLog vial label
```
Camera frame (in-memory JPEG)
  └── AIRouter.route(.vialLabel, entitlement)
       │ Free → on-device (if capable) / Pro → GLM worker / BYO → user provider (vision only)
  └── ParsedVial JSON {compound, total_mg, formulation}
  └── VAL: DrawGuard cross-check vs user-entered values → mismatch = RED warning
  └── Confirmation UI → user edits/confirms → Vial persisted (photo NEVER saved)
```

### Feature: Weekly AI insight
```
Local aggregation (means/counts/correlations only — no PII, no photos, no location)
  └── AIRouter.route(.weeklyInsight, entitlement)
  └── GLM / Apple on-device → insight JSON with confidence
  └── Insight cards UI ("why" expandable) + "Educational only — not medical advice"
  └── Cached locally; envelope open animation on first view
```

### Feature: Shot logging
```
Shot Day card (pre-filled from last log + schedule)
  └── 1 tap ✅ → validation → DoseLog save → inventory decrement
  └── streak++ → confetti animation → victory card offer → share sheet
```

## Implementation Flow

1. Xcode project via xcodegen: SwiftUI + SwiftData, iOS 26.0 min, Bundle ID `com.zzoutuo.ShotJoy`, Team `JP4TN5PTS3`
2. Models + CompoundPresets library (100+ compounds with public PK half-lives: semaglutide ≈168h, tirzepatide ≈120h, etc.)
3. DrawGuard engine + full unit test suite (6 guards, Decimal, cross-check fixtures)
4. Today screen + shot logging flow + confetti + streak
5. Body map + site rotation logic
6. Inventory + restock estimator
7. Symptoms + goals + weight + Swift Charts
8. HealthKit integration + Info.plist usage strings
9. Notifications + Shot Day ritual + Live Activity
10. Face ID + AES-256-GCM crypto
11. AI layer: AIRouter + AppleOnDeviceAI + GLMCloudService + BYO multi-provider (both adapters) + Keychain
12. SnapLog camera flows with confidence gating
13. Weekly insight + titration mode
14. Paywall (StoreKit 2, 3 tiers) + pricing transparency page + restore + manage subscriptions
15. PDF report + victory share card
16. Medical disclaimer on: calculation results, insights, PDF export, About/pricing
17. app_review_info.md + PrivacyInfo.xcprivacy
18. Build & run on iPhone + iPad simulators, then push to GitHub

## UI/UX Design Specifications

- **Colors**: Joy Coral `#FF7A59` (primary action/celebration), Mint `#2EC4B6` (data/safety badges), deep-space dark background default
- **Typography**: SF Pro; Dose result 64pt bold ("10 units" is the screen protagonist); body supports Dynamic Type XXL
- **Layout**: first screen = 1 primary action + max 3 secondary cards; no dashboard clutter
- **Animations**: confetti 0.8s on log success (never excessive); streak flame; envelope-open on weekly report; pulsing next-site on body map; scan shimmer during AI recognition
- **Warnings**: yellow cards with concrete fix ("Add 2.5 mL water → dose lands exactly on 20 units"), never scary-red unless input invalid

## Code Generation Rules

1. **Dose chain is AI-free**: all math via pure-function DrawGuard; AI results must pass VAL cross-validation; local engine wins on any mismatch
2. **Decimal everywhere** in dose/money paths; no Double/Float
3. **AI three nevers**: never write to DB directly, never enter calculation chain, never display without confidence (<85% requires user confirmation)
4. **Privacy defaults**: network allowlist; photos in-memory only; aggregate before egress
5. **Local-first**: 100% core features work offline; cloud AI/sync are enhancements, never dependencies
6. **Disclaimer everywhere**: calc results, insight pages, PDF footer, store description
7. **Accessibility**: Dynamic Type, VoiceOver labels, 60fps animations, reduced-motion respect
8. Never hardcode app version — read from `Bundle.main.infoDictionary`
9. No GLM API key ever embedded in app; no direct api.z.ai calls

## Build & Deployment Checklist

- [x] Bundle ID `com.zzoutuo.ShotJoy`, Team `JP4TN5PTS3`, iOS 26.0 minimum
- [x] SwiftUI + SwiftData project via xcodegen (auto-create authorized if no .xcodeproj exists)
- [x] DrawGuard with 6 guards + unit tests
- [x] Data models + AES-256-GCM + Face ID (LAContext)
- [x] All user flows (Today/Body Map/DrawGuard/share card)
- [x] HealthKit with usage strings
- [x] Foundation Models on-device + free-tier counter (local)
- [x] GLM-Cloudflare shared worker integration per https://github.com/asunnyboy861/GLM-Cloudflare (appId `shotjoy`, userId Keychain, 3 GLM behavior rules)
- [x] Prerequisite: register `com.zzoutuo.ShotJoy` into worker D1 whitelist (§8 curl) — via glm-api-config skill
- [x] Test period: devKey in requests → production build: replace with StoreKit 2 `jwsRepresentation`
- [x] BYO multi-provider (GLM/OpenAI/DeepSeek/Gemini/Claude/custom) — never GLM-only
- [x] StoreKit 2: Pro monthly $9.99 / Pro yearly $49.99 (7-day trial) / BYO lifetime $39.99
- [x] PDF doctor report with disclaimer footer
- [x] Four-layer disclaimer coverage
- [x] App Store materials: screenshots (user-made), keywords (glp1, ozempic, wegovy, mounjaro, zepbound, semaglutide, tirzepatide, peptide, injection, dose, reconstitution, bpc157), 16+, privacy label "data not collected"
