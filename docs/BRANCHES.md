# Branch Strategy (Per Fitur)

Repository ini memakai branch per fitur agar pengembangan dan review lebih rapi.

## Active Branches

1. `main`
- Baseline/stable branch.

2. `feat-auth-splash-ui`
- Fokus: auth flow, splash screen, dan perombakan UI login/register.

3. `feat-offline-first-sync`
- Fokus: mode offline/online, cache lokal, dan pending sync operasi transaksi/budget.

4. `feat-goals-dashboard`
- Fokus: fitur Goals (pengganti Transfer) dan ringkasan goals di dashboard.

5. `feat-settings-export-theme`
- Fokus: settings fungsional (theme mode, export CSV/JSON/PDF, toggle, clear data).

6. `feat-cicd-playstore`
- Fokus: workflow PR check, deploy Play Store internal, signing, versioning, fastlane.

## Rules

- Setiap pekerjaan baru masuk ke branch fitur yang relevan.
- PR selalu diarahkan ke `main`.
- Gunakan `.github/pull_request_template.md` untuk deskripsi PR standar.
