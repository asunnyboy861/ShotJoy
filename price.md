# Pricing Configuration

## Monetization Model: Subscription (IAP) + One-Time BYO Buyout

Free tier is genuinely usable (full core tracking + limited on-device AI). Two auto-renewable subscriptions (monthly / annual with 7-day trial) unlock Pro features including platform-provided cloud AI. A separate $39.99 non-consumable lifetime tier unlocks all Pro features but routes AI through the user's own API keys (multi-provider) — no platform cloud AI quota included, so no consumable cost is baked into a buyout.

## Subscription Group
- **Group Name**: ShotJoy Pro
- **Reference Name**: ShotJoy Pro
- **Products in group**: com.zzoutuo.shotjoy.pro.monthly, com.zzoutuo.shotjoy.pro.yearly (auto-renewable ONLY)

## Subscription Tiers (Auto-Renewable)

### 1. Monthly Subscription
- **Reference Name**: ShotJoy Pro Monthly
- **Product ID**: `com.zzoutuo.shotjoy.pro.monthly`
- **Type**: Auto-renewable subscription
- **Price**: $9.99 USD per month
- **Display Name**: `ShotJoy Pro Monthly` (19 chars, ≤35 ✅)
- **Description**: `All Pro features with cloud AI, billed monthly` (46 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: ShotJoy Pro
- **Restore Purchases**: ✅ Required

### 2. Yearly Subscription (Primary)
- **Reference Name**: ShotJoy Pro Annual
- **Product ID**: `com.zzoutuo.shotjoy.pro.yearly`
- **Type**: Auto-renewable subscription
- **Price**: $49.99 USD per year (58% savings vs monthly)
- **Display Name**: `ShotJoy Pro Annual` (18 chars, ≤35 ✅)
- **Description**: `All Pro features with cloud AI, 7-day free trial` (48 chars, ≤55 ✅)
- **Localization**: English (US)
- **Subscription Group**: ShotJoy Pro (same group as monthly)
- **Restore Purchases**: ✅ Required

## One-Time Purchases (Non-Consumable)

### 1. BYO Lifetime
- **Reference Name**: ShotJoy BYO Lifetime
- **Product ID**: `com.zzoutuo.shotjoy.pro.lifetime`
- **Type**: Non-consumable (one-time purchase, permanently unlocked)
- **Price**: $39.99 USD (one-time)
- **Display Name**: `ShotJoy BYO Lifetime` (20 chars, ≤35 ✅)
- **Description**: `All Pro features forever, use your own AI keys` (46 chars, ≤55 ✅)
- **Localization**: English (US)
- **Restore Purchases**: ✅ Required
- **⚠️ DIFFERENTIATION NOTE**: BYO Lifetime unlocks the same Pro feature set as the subscriptions EXCEPT platform cloud AI: AI features run through the user's own API keys (GLM/OpenAI/DeepSeek/Gemini/Claude/custom OpenAI-compatible — never GLM-only), unlimited, no platform GLM quota. Choose it if you prefer owning your AI access; choose Pro subscriptions for managed cloud AI with zero setup. Rationale: platform cloud AI is a consumable cost and must never be sold as a lifetime buyout.

## Free Tier (Default)

- **Price**: Free, forever
- **Features**:
  - Full core tracking: DrawGuard calculator, shot logging, body-map rotation, smart reminders, vial inventory + restock estimates
  - Symptom logging (40+ presets), weight/protein/hydration goals, HealthKit sync
  - Apple on-device AI: 5 tasks/day (meal category estimates, weekly summary fallback)
  - GLM cloud AI: 1 free experience scan
  - Victory share card, Face ID + local AES-256-GCM encryption
- **Conversion hooks**:
  - Value-first paywall: appears only after the user's 2nd meal photo or after viewing the 1st AI weekly insight, and shows a sample insight card first (ShotJoy's own value only — no competitor prices anywhere)
  - "Core tracking is free forever" banner on the pricing transparency page
  - After the 1 free cloud experience, a friendly card: "Enjoying cloud recognition? Pro adds 30 scans/month + unlimited insights"

## Pro Features Unlocked (All Paid Tiers)

⚠️ Cross-referenced with capabilities.md (all listed features are implemented in PHASE 4; iCloud sync is optional enhancement with graceful degradation).

| Feature | Free | Pro (All Paid Tiers) |
|---------|:----:|:--------------------:|
| Core tracking (calculator, logging, body map, reminders, inventory) | ✅ Full | ✅ Full |
| Symptoms, goals, HealthKit sync | ✅ Full | ✅ Full |
| Face ID + AES-256-GCM local encryption | ✅ Full | ✅ Full |
| Apple on-device AI | 5 tasks/day | ✅ Unlimited |
| GLM cloud AI (vial label + meal photo recognition) | 1 experience scan | ✅ 30 scans/month (subscriptions only; Lifetime uses own keys instead) |
| AI Insight weekly report | On-device basic version | ✅ GLM-powered, unlimited |
| Titration companion mode | ❌ | ✅ |
| PDF doctor-ready report | ❌ | ✅ |
| BYO multi-provider AI engine (own keys) | ✅ Configure & use (unlimited) | ✅ (Lifetime: primary path) |
| iCloud sync (optional enhancement) | ✅ | ✅ |
| All future Pro features | ❌ | ✅ |

## Free Trial
- **Duration**: 7 days
- **Type**: Free trial (auto-converts to paid annual subscription)
- **Available for**: Yearly subscription only

## Policy Pages Required
- Support Page: ✅ (must include subscription management + cancellation instructions)
- Privacy Policy: ✅
- Terms of Use (EULA): ✅ (REQUIRED — subscription apps must have Terms)
- **Total policy pages**: 3

## Apple IAP Compliance Checklist
- [x] Auto-renewal terms will be included in Terms of Use
- [x] Cancellation instructions will be included in Support Page
- [x] Pricing clearly stated in PaywallView ($9.99/mo, $49.99/yr with 7-day trial, $39.99 once)
- [x] Free trial terms included (yearly only)
- [x] Restore purchases functionality implemented (StoreKit 2 `Transaction.currentEntitlements`)
- [x] `showManageSubscriptions` entry point in Settings
- [x] No external payment links (Guideline 3.1.1)
- [x] No price references to outside-App-Store options (paywall shows this app's prices only)
- [x] All IAP descriptions ≤ 55 characters
- [x] All IAP display names ≤ 35 characters
- [x] BYO Key model: AI generation always unlimited for users with own keys — no generation counting (`freeGenerationsUsed` / `maxFreeGenerations` forbidden)
- [x] Lifetime tier never bundles consumable cloud AI quota (differentiation note present)
