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

## Run locally

```sh
python3 -m http.server 8000
# open http://localhost:8000
```

When you change files, bump `CACHE` in `sw.js` so installed copies pick up the update.
