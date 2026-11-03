# Windows → iPhone: build and install (no Mac needed)

## Part 1 — Build the IPA in the cloud (GitHub Actions, macOS runner)
1. Create a free account at github.com and a new repository (e.g. `lojaiga`). Public repos get free macOS build minutes; private repos use your monthly allowance (macOS minutes cost more than Linux — check Settings → Billing).
2. Unzip the project. Upload **everything**, including the hidden `.github` folder, to the repo (GitHub Desktop is easiest; or drag the folder contents onto the repo page). Make sure `.github/workflows/build-ios.yml` is in the repo.
3. Open the **Actions** tab → "Build Lo Jaiga (unsigned IPA)" → **Run workflow**. Takes roughly 10–15 minutes.
4. When it finishes, open the run and download the artifact **LoJaiga-unsigned-ipa** (a zip containing `LoJaiga-unsigned.ipa`). Also download **logs**.
5. If the run is red: open `build.log`, copy the lines containing `error:` and send them to Claude. Fixes are usually one-line edits. Re-run after each fix.
6. The "Unit tests" step is allowed to fail without blocking the IPA, but please send me `test.log` if it's red — it tells us whether the scoring rules behave.

## Part 2 — Install on your iPhone (free Apple ID)
Use **Sideloadly** (Windows):
1. Install iTunes and iCloud from apple.com (not the Microsoft Store versions), then Sideloadly from sideloadly.io.
2. iPhone: Settings → Privacy & Security → **Developer Mode** → On (restarts the phone).
3. Plug in the iPhone by USB, tap Trust.
4. Drag `LoJaiga-unsigned.ipa` into Sideloadly, enter your Apple ID, press **Start**. Use an Apple ID you're comfortable with, or a spare one.
5. iPhone: Settings → General → VPN & Device Management → your Apple ID → **Trust**.
6. Free accounts: the app stops opening after 7 days — repeat step 4 to refresh. (SideStore/AltStore can auto-refresh but need extra setup.)
7. Paid Apple Developer Program ($99/yr) gives 1-year signing and TestFlight, but needs a signing certificate added to the workflow. Ask when you're ready.

## Part 3 — First-run test checklist (report results back)
1. App opens; you see the mascot and "Manual mode" banner.
2. Analyze: enter 42.75 / pickup 9 min, 4.2 km / trip 38 min, 32 km → Good offer. Change fare to 12 → Bad offer with reasons.
3. Analyze → "From screenshot (beta)" with a real Uber offer screenshot of yours. Do the numbers fill correctly? (Tell me which are wrong; I'll tune the parser.)
4. Settings → Places: type a place, tap the pin; it should show a ✔ located name. Turn off "Accept any destination" and test a drop-off inside/outside the radius.
5. Voice tab: allow Microphone + Speech; record the 10 commands; toggle Listen; say "Offer Dekha", "Baad Dey", "Map ON Kor".
6. History: log an offer as taken/skipped; export CSV.
7. Optional: Shortcuts app → new shortcut: Take Screenshot → Check Offer Screenshot → Speak Text; assign to Back Tap.

## Alternative: rented cloud Mac (MacinCloud etc.)
`brew install xcodegen && xcodegen generate && open LoJaiga.xcodeproj`, pick your team, Product → Archive, export, then sideload the IPA from Windows. A cable can't reach your iPhone from a remote Mac, so GitHub Actions is simpler.

## Safety
Never operate the phone while driving. Verify every number before accepting any trip in Uber. Check Uber's current terms before relying on any screenshot-based workflow.
