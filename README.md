# ShieldPay

ShieldPay is a web-first Flutter app to scan invoices and flag suspicious payments, built to be privacy-first and client-side.

Quick steps to push this project to GitHub (recommended):

1. Create a repository on GitHub (via web UI or GitHub CLI `gh`).
2. Add a remote and push:

```powershell
git remote add origin git@github.com:<your-username>/shieldpay.git
git branch -M main
git push -u origin main
```

If you prefer using HTTPS:

```powershell
git remote add origin https://github.com/<your-username>/shieldpay.git
git branch -M main
git push -u origin main
```

CI is already configured to run `flutter analyze`, `flutter test`, and `flutter build web` on pushes.

If you want me to create the GitHub repository for you automatically, install the GitHub CLI (`gh`) and authenticate (`gh auth login`), then I can run `gh repo create --public --source=. --remote=origin --push` for you.
# ShieldPay (inside this repo)

This folder contains the ShieldPay Flutter web module — a client-side invoice/payment scanner that highlights potential fraud and suspicious payments.

Quick start (Windows PowerShell):

```powershell
# fetch dependencies
flutter pub get

# run in Chrome (recommended for Flutter web development)
flutter run -d chrome

# build optimized web bundle
flutter build web
```

Notes:
- Chrome is recommended for web debugging; Edge can work but must be visible to `flutter devices` and configured.
- The app persists history to `localStorage` on the web and provides CSV/PDF export from the dashboard.
- CSV import: use headers `payeeName,accountNumber,amount,email,vendorDomain,invoiceDate`.

PDF import:
- Automatic extraction of structured fields from arbitrary PDFs in-browser is not reliably available without a server-side extractor or embedding a heavy JS library (e.g. pdf.js) with interop. The current UI provides a paste-text/CSV path for batch import and stubs to add PDF parsing later.

Tests:

```powershell
flutter test
```

Deployment:
- Host the `build/web` folder on any static hosting (Netlify, Vercel, GitHub Pages, S3 + CloudFront).

Next steps:
- Add CI workflow to run tests and publish web builds.
- Add optional server-side verification integrations (bank validation APIs) to increase accuracy.
# tax

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
