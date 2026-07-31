# Stride — personal GPS running tracker for iOS

A private, no-account, no-subscription running app. Everything is recorded and stored on your phone only.

**Features:** live map with your route drawn as you run · big timer with moving time · distance, current pace, average pace, elevation gain, cadence (steps/min), calorie estimate · auto-pause at traffic lights · automatic km/mile splits with haptic buzz · full run history · per-run detail page with route map, splits chart, pace chart, elevation profile · all-time / 7-day / 30-day totals · personal records (longest run, fastest pace, biggest climb, best 1K/5K/10K efforts found inside any run) · GPX export per run (importable into Strava or anything else) · km/miles setting, weight setting for calories · dark UI built for outdoor readability · works with the screen locked (background GPS).

---

## Getting the IPA

An IPA has to be compiled with Apple's toolchain (Xcode, macOS only), so the source here can't be turned into an IPA on a phone directly. Two ways to get it:

### Path A — GitHub builds it for you (no Mac needed, ~10 min one-time setup)

This repo includes a GitHub Actions workflow that compiles the app on GitHub's free macOS servers and hands you an unsigned IPA.

1. Go to github.com and create a **new repository**. Make it **Public** (public repos get unlimited free build minutes; private ones have a small monthly macOS quota).
2. Upload everything in this folder to the repo. Easiest reliable way:
   - Upload `project.yml`, `README.md`, and the whole `Sources` folder via **Add file → Upload files** (drag the folder in from a computer, or select files on mobile).
   - The `.github` folder is hidden and sometimes gets skipped by drag-and-drop. If it didn't upload: **Add file → Create new file**, type the filename as `.github/workflows/build.yml` (the slashes create the folders), and paste in the contents of `.github/workflows/build.yml` from this zip.
   - If you're comfortable with git instead: `git init`, commit, push. Same result.
3. Open the **Actions** tab of your repo. The "Build unsigned IPA" workflow either already ran on your push, or you can press **Run workflow**.
4. Wait ~5–10 minutes for the green checkmark. Open the run, scroll to **Artifacts**, download **Stride-unsigned-ipa**. Inside the zip is `Stride.ipa`.

To update the app later: edit the code in the repo, the workflow rebuilds automatically, download the new IPA and re-sign.

### Path B — you have access to a Mac

1. Install Xcode from the App Store, then `brew install xcodegen`.
2. In this folder run `xcodegen generate`, open `Stride.xcodeproj`.
3. Either run it straight onto your plugged-in iPhone with your free Apple ID (Product → Run; this is the simplest option of all, 7-day resign), or Product → Archive with signing disabled and zip the `.app` into a `Payload/` folder as `Stride.ipa` for your signer.

---

## Signing & installing

1. Open the IPA in your signing app (ESign, Feather, KravaSigner, GBox — whatever you use with your certificate).
2. Sign with your certificate and install. If you ever get a bundle-ID conflict, just let the signer change the bundle ID — nothing in the app depends on it.
3. First launch: allow **Location While Using the App** with **Precise: On**, and allow **Motion & Fitness** (that's the cadence sensor). During a run with the screen locked you'll see the blue/pill location indicator — that's iOS confirming background tracking is active.

## Good to know

- **Battery:** GPS at best-for-navigation accuracy costs roughly 8–12% per hour of running. Normal.
- **Accuracy:** the first fix can take ~10–30 s outdoors. The GPS dot on the map screen shows fix quality (green = good). Runs under 50 m are discarded as GPS noise.
- **Data:** runs live in the app's Documents folder as JSON. Deleting the app deletes your runs — export GPX files (share icon on any run) if you want backups. If your signing certificate gets revoked, re-signing and reinstalling with the same bundle ID normally keeps your data.
- **Auto-pause** can be turned off in Settings if you do interval training and want the clock to keep counting during standing rest.

## Customizing

- Rename the app: `CFBundleDisplayName` in `project.yml`.
- Accent color: `ember` in `Sources/Models.swift`.
- Bundle ID: `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`.
