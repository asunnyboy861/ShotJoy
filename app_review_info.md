# App Review Information

## Demo Account for Apple Review

### AI Features — How They Work Without Any Key
- Apple Intelligence (on-device Foundation Models) is the DEFAULT AI backend. On reviewer devices (iPhone 15 Pro+, iOS 26+), the weekly insight and AI features work immediately with zero configuration (free tier: 5 on-device tasks/day, Pro: unlimited).
- Optional cloud AI (Pro tier) goes through our managed proxy — no key handling by users.
- Optional "BYO" mode: users may configure their own API key (GLM, OpenAI, DeepSeek, Gemini, Claude, or any OpenAI-compatible endpoint) in Settings → AI Engine (BYO). Keys are stored in the iOS Keychain only. On the simulator Apple Intelligence is unavailable, so configure a BYO key there:
  1. Settings → AI → "AI Engine (BYO)"
  2. Tap "OpenAI" → paste a demo key → Test connection → Enable → Save
  3. Today → Meal photo, or Meds → Scan vial, or Weekly insight

### Dose-Safety Engine (DrawGuard)
- DrawGuard is a deterministic unit-conversion engine for the user's OWN prescribed dose (mg→mcg, concentration, syringe units). It NEVER suggests, recommends, or optimizes doses.
- Every calculation screen, the plasma curve, the weekly insight and the PDF report display: "Educational only — not medical advice. Always follow your prescriber's instructions."

### HealthKit Integration
- Clearly identified in Settings: "Apple Health (HealthKit)" section header with HealthKit icon, "HealthKit Integration" row with Learn More page (HealthKitInfoView), footer explaining exactly what is written (body-mass) and read (weight, steps, sleep), toggles labeled "Sync weight to HealthKit".
- Nothing is accessed without the permission dialog; the app works fully without HealthKit.

### Subscription Testing
- Product IDs: com.zzoutuo.shotjoy.pro.monthly ($9.99/mo), com.zzoutuo.shotjoy.pro.yearly ($49.99/yr, 7-day free trial), com.zzoutuo.shotjoy.pro.lifetime ($39.99 non-consumable)
- The Paywall shows prices, length, auto-renewal disclosure, functional Privacy Policy and Terms of Use links, and Restore Purchases.
- Free tier is genuinely usable without any purchase: calculator, logging, body map, reminders, inventory, symptoms, goals, HealthKit, on-device AI (5/day).

### Required Links (In-App)
- Privacy Policy: https://asunnyboy861.github.io/ShotJoy/privacy.html
- Terms of Use: https://asunnyboy861.github.io/ShotJoy/terms.html
- Support Page: https://asunnyboy861.github.io/ShotJoy/support.html

These links are accessible from: Settings → Legal & Support, and inside the Paywall below the purchase options.

## Review Notes

### Medical Compliance (Guideline 1.4)
- ShotJoy is a recording and education tool, NOT a medical device and NOT a drug dosage calculator/recommender. It performs arithmetic unit conversion on user-entered, prescriber-defined doses only.
- No dose recommendations, no diagnosis, no treatment advice anywhere in the app. Medical disclaimer is shown on calculation results, the plasma curve ("Educational visualization — not for dosing decisions"), weekly insights, the PDF report (every page footer), the pricing page and the About section.
- Category: Health & Fitness. Age rating: 16+.

### AI Features
- Apple Intelligence is the default free backend; no key required on supported devices.
- The app does NOT sell API keys or AI usage; BYO mode is optional and unlimited for users with their own keys.
- No free-generation counting; no AI button dead-ends (graceful fallbacks to manual entry are built in).

### Privacy
- Privacy manifest (PrivacyInfo.xcprivacy) included: no tracking, no data collection.
- Photos from vial-label and meal scanning are processed in memory only and never stored or uploaded to second locations.
- Weekly AI insights send aggregated statistics only (means/counts), never identity data, photos, or location.
- API keys are stored exclusively in the iOS Keychain.

### Data Collection
- The app collects NO data (see privacy nutrition label: Data Not Collected). The contact-support form is user-initiated and only used to respond to feedback.
