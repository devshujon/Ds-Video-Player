# DS Video Player — Brand Guidelines

## Brand personality
Fast · Modern · Premium · Reliable · Elegant · Professional

## Color palette

| Token | Hex | Usage |
|-------|-----|-------|
| Primary | `#6C5CE7` | App icon, CTAs, key accents |
| Secondary | `#8B5CF6` | Secondary buttons, highlights |
| Accent | `#A78BFA` | Chips, badges, subtle emphasis |
| Premium | `#C4B5FD` | Premium tier, soft highlights |
| Dark | `#0F1117` | Dark surfaces, splash backgrounds |
| White | `#FFFFFF` | Light surfaces, icon glyph |

## Typography

**Primary:** [Plus Jakarta Sans](https://fonts.google.com/specimen/Plus+Jakarta+Sans)  
Weights: 600 (UI labels), 700 (headlines), 800 (display)

**Alternates:** Outfit (marketing), DM Sans (body-heavy screens)

Plus Jakarta Sans is used in-app via `google_fonts`. It pairs cleanly with the geometric D mark and reads well at small sizes on Android.

## Logo concepts

Five concepts are in `assets/brand/concepts/`. See analysis below.

### Concept 01 — D merged with Play (recommended)
**File:** `concept_01_d_play.svg`

A bold geometric **D** with a play triangle cut from its bowl using negative space. Flat royal purple field, white symbol.

**Pros**
- Instantly ownable — not a generic play button
- Scales to 48×48 and adaptive icon safe zones
- Encodes “DS” (Dev Shujon / DS) without clutter
- Works in monochrome for Android 13 themed icons
- Premium flat aesthetic aligned with Nothing OS / Google apps

**Cons**
- Requires precise geometry to avoid looking like a generic media icon
- Less literal “video” cue than film-frame concepts

### Concept 02 — DS monogram
**File:** `concept_02_ds_monogram.svg`

Interlocked **D** and **S** letterforms with a subtle play accent.

**Pros**
- Strong brand initials for marketing lockups
- Distinct from single-letter competitors

**Cons**
- Too dense at 48×48 — details collapse on home screens
- Reads as “initials app” rather than “video player”
- Harder to adapt for notification and favicon

### Concept 03 — Rounded play in circular frame
**File:** `concept_03_rounded_play_frame.svg`

Concentric circles with a refined play triangle on dark ground.

**Pros**
- Clean, calm, very “premium media”
- Excellent symmetry for adaptive icons

**Cons**
- Closest to generic play-button territory
- Weak differentiation vs VLC, YouTube Music, countless templates
- Circular frame fights Android squircle masking

### Concept 04 — Media glyph
**File:** `concept_04_media_glyph.svg`

Rounded rectangle “screen” with play and subtle film cues.

**Pros**
- Immediately communicates “video”
- Friendly and approachable

**Cons**
- Feels clip-art adjacent at small sizes
- Competes visually with MX Player-style tropes
- Less elegant / premium than monogram approaches

### Concept 05 — Lens aperture
**File:** `concept_05_lens_aperture.svg`

Radial lines suggesting camera lens with central play.

**Pros**
- Unique, cinematic personality
- Strong dark-mode presence

**Cons**
- Busy strokes break down at notification size
- Suggests “camera” more than “player”
- Harder to tint as Android monochrome icon

## Recommendation

**Implement Concept 01 — D merged with Play.**

It is the strongest balance of recognition, scalability, premium flat design, and Google Play polish. The negative-space play inside the D is distinctive without relying on clichéd triangles-on-purple gradients.

## Asset inventory

| Asset | Path |
|-------|------|
| Primary mark | `assets/brand/logo_mark.svg` |
| Horizontal logo | `assets/brand/logo_primary.svg` |
| Splash mark | `assets/brand/logo_splash.svg` |
| Monochrome | `assets/brand/logo_monochrome.svg` |
| Notification | `assets/brand/notification_icon.svg` |
| Favicon | `assets/brand/favicon.svg` |
| Previews | `assets/brand/previews/` |
| Android foreground | `android/.../drawable/ic_launcher_foreground.xml` |
| Android monochrome | `android/.../drawable/ic_launcher_monochrome.xml` |

## Adaptive icon

- **Background:** `#6C5CE7` (`@color/ic_launcher_background`)
- **Foreground:** white D+play glyph, centered in 66dp safe zone
- **Legacy mipmaps:** full-bleed 512 master rasterized to all densities

## Clear space

Minimum clear space around the mark = 12.5% of icon width on all sides.

## Don’ts

- No gradients on the mark
- No drop shadows or 3D gloss
- Don’t place the glyph on busy photography
- Don’t stretch or rotate the mark
