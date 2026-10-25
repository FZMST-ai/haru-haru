# Haru-haru (하루하루)

A tiny daily-tasks web app you can install on your phone's home screen. "Haru-haru" is Korean for "day by day".

- **Every day** — habits that reset at midnight, with a 🔥 streak counter.
- **Today** — one-off tasks. Anything unfinished carries over to the next day.
- Progress ring for today and a 7-day strip of how your habits went.
- Works offline, no account, no build step. Data lives in your browser (`localStorage`); use **Export / Import** to back it up or move devices.
- **Edit** mode: reorder, delete (with undo), and tap a task to rename it.

## Install on your phone

The app has to be served over HTTPS. The included GitHub Actions workflow publishes it to GitHub Pages:

1. Merge to `main`.
2. In the repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. Open `https://<your-user>.github.io/haru-haru/` on your phone.

Then:

- **iPhone (Safari):** Share → **Add to Home Screen**.
- **Android (Chrome):** ⋮ menu → **Install app** / **Add to Home screen**. Long-press the icon for the *Add task* and *Add habit* shortcuts.

Shortcut URLs (handy for iOS Shortcuts or widgets): `…/haru-haru/?add=once` and `…/haru-haru/?add=daily` open straight to the add box.

> Note: on iOS, the home-screen app keeps its own storage separate from Safari, so add your tasks after installing.

## iOS app (SwiftUI)

There's also a native iPhone app in [`ios/`](ios). It works like the web app and adds:

- **Reminders** for any task (swipe right → Edit → *Remind me*). Habit reminders are skipped on days you've already done them, and each one has a **Mark done** button.
- **Evening check-in** (Settings) that lists what's left. It's skipped on days you finish everything.
- Backups use the same JSON format as the web app, so you can **Export** from one and **Import** into the other.

### Install with SideStore (free Apple ID)

Every push that changes `ios/` builds an unsigned `.ipa` on GitHub Actions and publishes it here:

**https://github.com/FZMST-ai/haru-haru/releases/download/ios-latest/HaruHaru.ipa**

1. Set up SideStore once by following the official guide at <https://docs.sidestore.io>. You'll need a computer for this one time, plus your Apple ID.
2. On your iPhone, open the link above in Safari and download `HaruHaru.ipa`.
3. In SideStore, go to **My Apps → +** and pick the downloaded file. SideStore signs it with your Apple ID.
4. Open Haru-haru and allow notifications when it asks (this happens when you turn on a reminder).

A free Apple ID's signature lasts 7 days. Open SideStore and tap **Refresh All** every few days, or automate it with a Shortcuts "When app is opened" or time-of-day automation. Your tasks are kept even if it lapses.

To update the app, download the new `.ipa` and install it again the same way. Your data stays.

### Build it yourself (Mac)

```sh
brew install xcodegen
cd ios && xcodegen generate && open HaruHaru.xcodeproj
```

## Run the web app locally

```sh
python3 -m http.server 8000
# open http://localhost:8000
```

When you change files, bump `CACHE` in `sw.js` so installed copies pick up the update.
