# DS Video Player — Business Model & Monetization

## Two SKUs, one codebase
A single app; entitlement decided at runtime by `PremiumProvider` (IAP). No separate APK.

### Free (ad-supported) — **implemented** in `feature/admob-ads`
- Adaptive **banner** (`BannerAdView`) only on library/list screens — never
  over the player. Lives in the home shell between the IndexedStack body
  and the bottom NavigationBar.
- **Rewarded** ads (`RewardedUnlockButton`) strictly user-initiated; the
  Equalizer's premium "Rock" preset is the first opt-in slot.
- **Zero ads during active playback.** No interstitials, no forced full-screen.
- Ad load is gated on `PremiumProvider.showAds` in widget `initState`, so
  paying users never make a single ad request.
- Frequency cap + first-session grace = next polish item (remote-config-
  driven).

### Premium
- One-time **lifetime** unlock (primary, highest LTV for utility apps).
- Optional **monthly / yearly** subscription with free trial.
- Removes all ads, unlocks: equalizer custom presets, AMOLED + custom themes, vault unlimited, cloud sync, floating player, priority feature flags.

## Product IDs (Play Billing)
| ID | Type |
|---|---|
| `ds_premium_lifetime` | one-time (non-consumable) |
| `ds_premium_monthly` | subscription |
| `ds_premium_yearly` | subscription (best value badge) |

## Entitlement & anti-piracy

**Implemented (`feature/iap-billing`):**
- `IapService` boundary (`GoogleIapService` impl) wraps `in_app_purchase`.
  Product loading, purchase, restore, billing-event stream, plugin types
  translated to `IapPurchase` so the UI never imports the plugin.
- `PremiumProvider.init()` reads the Keystore-cached token first (offline
  grace), then connects billing and loads products. New
  purchases/restores write a fresh tamper-evident token via
  `SecureStorageService` and flip `isPremium`.
- Token = `productID|purchaseID|serverVerificationData|sha256(...)`
  packed string. Cached in Android Keystore via `flutter_secure_storage`.

**Production hardening (next step, not in this branch):**
- Server-side receipt validation against the Google Play Developer API
  (`purchases.products.get` / `purchases.subscriptions.get`). The current
  local hash is tamper-evident at rest but does not defend against a
  rooted device replaying a stolen Play receipt — only Google's API can.
- Periodic re-verify on a cadence (e.g. weekly); revoke on negative.
- Grace window so a transient network failure doesn't downgrade a paying
  user mid-flight.

## Pricing strategy (tunable per market via remote config)
- Lifetime priced as ~3–4× monthly; yearly ≈ 50% of 12×monthly to push annual.
- Localized pricing tiers; intro offer on yearly.

## Revenue mix targets (utility-app benchmarks)
- Ads ≈ 60–70% of revenue at scale, IAP ≈ 30–40%, IAP higher LTV/user.
- North-star: ad ARPDAU + premium conversion ≥ 1.5–3% of MAU.

## UX guardrails (retention > short-term ARPU)
- Never interrupt playback. Never dark-pattern the upsell.
- Premium screen reachable but not nagging; contextual upsell only at the gated feature.
