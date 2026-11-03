# Windows 10: upload cleanly using GitHub Desktop

1. Extract `LoJaiga-v0.6-GitHub-Ready.zip` into a folder.
2. In GitHub Desktop, use **File > Clone repository** to clone `creationbd5/LoJaiga` or create a **new empty repository** to avoid old nested files.
3. Open cloned folder in File Explorer. If using old repo, first make a backup. Remove old app folders and files EXCEPT `.git` and anything you intentionally want to preserve. **Do not delete `.git`**.
4. Copy **the contents** of extracted v0.6 folder into the cloned repo ROOT. Do not copy the enclosing v0.6 folder itself. Turn on **View > Hidden items** so `.github` is copied.
5. Verify the exact files shown in `README.md`. You must see `LoJaiga/Services/TripStore.swift`, not `LoJaiga/LoJaiga/Services/TripStore.swift`.
6. GitHub Desktop: Changes > commit to main > Push origin.
7. GitHub Actions > latest workflow > Summary > Artifacts. If failed, download `logs` artifact and inspect first `error:` lines.

Use `CHECK_STRUCTURE.ps1` (right-click > Run with PowerShell or run from a PowerShell terminal) to detect missing or nested paths before upload.
