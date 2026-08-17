# Play listing screenshots — retake guide

The listing shots in `assets/store/screenshots/` predate the Night Shift
redesign and the 2026-07 feature wave (stats, costs, stations, timeline), so
they no longer represent the app. `01-sign-in-dark.png` is already retaken
(dark auth screen); the rest need a signed-in session.

## What to capture (dark mode, phone)

1. **Dashboard** — metrics readouts, due-soonest gauges, recent activity card.
2. **Stats → Costs** — comparison cards + donut + monthly bars.
3. **Fuel stations** — nearby list with prices (crop/blur location if needed).
4. **Timeline** — a few months of mixed history.
5. **Maintenance** — reminder list with progress bars and "Previously" lines.
6. **Vehicle detail → Economy** — odometer readout + economy gauge + chart.

## Option A — real device (best quality)

Dark mode on, take normal Android screenshots of the screens above. Any
modern phone yields ≥1080×2340 PNG, which Play accepts as-is.

## Option B — web release build

```bash
CHROME_EXECUTABLE="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
  flutter run -d chrome --release --web-port 5757 --dart-define-from-file=env/prod.json
```

- `--release` removes the DEBUG ribbon.
- Sign in, then in DevTools device toolbar set **412 × 915 @ DPR 2.625**
  (= 1081 × 2401 physical) and use "Capture screenshot".
- macOS/Brave follows the system theme; the app can be forced dark in
  Settings → Theme.

## Play requirements (phone slot)

- 2–8 PNG/JPEG, ≥1080 px on the short side, 16:9–9:16 ratio.
- Keep filenames `NN-name.png` in `assets/store/screenshots/` so the listing
  order stays obvious.
