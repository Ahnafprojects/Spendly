# Spendly CI/CD Setup Guide

Panduan ini menjelaskan cara mengonfigurasi GitHub Actions dan Google Play Store untuk pipeline CI/CD Spendly.

## 1. Persiapan Keystore (Android)

Keystore digunakan untuk menandatangani aplikasi Android. Jangan pernah commit file .jks ke repository.

1. Generate keystore di terminal:

```bash
keytool -genkey -v -keystore keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Catat password keystore dan password key.

3. Encode file keystore.jks menjadi Base64:

```bash
# macOS/Linux
base64 -i keystore.jks -o keystore_base64.txt

# Windows (Git Bash)
base64 keystore.jks > keystore_base64.txt
```

## 2. Persiapan Google Play Service Account JSON

1. Buka Google Play Console.
2. Masuk ke Setup > API access.
3. Klik Create new service account dan lanjutkan di Google Cloud Console.
4. Buat service account dan generate key JSON.
5. Encode file JSON ke Base64 seperti langkah keystore.
6. Kembali ke Play Console, grant access ke service account untuk aplikasi Spendly dengan izin manage releases.

## 3. GitHub Secrets Configuration

Buka repository Spendly di GitHub, lalu masuk ke Settings > Secrets and variables > Actions.

Tambahkan secrets berikut:

- SUPABASE_URL
- SUPABASE_ANON_KEY
- KEYSTORE_BASE64
- KEYSTORE_PASSWORD
- KEY_ALIAS
- KEY_PASSWORD
- PLAY_STORE_JSON_KEY
- SLACK_WEBHOOK_URL

## 4. Cara Menjalankan Pipeline Deployment

1. Pastikan perubahan sudah di-merge ke branch main.
2. Buat tag baru dengan format semver diawali v.

```bash
git tag v1.0.0
git push origin v1.0.0
```

3. GitHub Actions otomatis build, sign AAB, dan upload ke internal track.

## 5. Validasi Penting Sebelum Deploy

- Pastikan `fastlane/Appfile` `package_name(...)` sama persis dengan
  `android/app/build.gradle.kts` `applicationId`.
- Pastikan seluruh secrets release sudah terisi pada GitHub Environment
  `production`.
