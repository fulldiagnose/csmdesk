# CSMDESK

Remote desktop internal untuk tim IT: teknisi bisa mengendalikan PC user yang
tersebar di banyak lokasi, sementara user hanya perlu menjalankan satu file
portable tanpa hak administrator.

CSMDESK adalah **fork dari RustDesk**. Semua kredit, notice lisensi, dan
copyright asli dipertahankan.

```
RustDesk — Copyright (C) Purslane Tech Pte. Ltd.
Licensed under AGPL-3.0. https://github.com/rustdesk/rustdesk
CSMDESK source: https://github.com/fulldiagnose/csmdesk
```

## Kenapa fork, bukan pakai RustDesk langsung

| Masalah | Solusi di CSMDESK |
|---|---|
| Client RustDesk publik bisa dipakai siapa saja | Client hanya menunjuk ke server sendiri; config client ditandatangani (tidak bisa diubah pihak lain) |
| Nama produk publik disalahgunakan | Brand internal sendiri; kredit "Powered by RustDesk" tetap tampil |
| Update otomatis ke server pihak ketiga | Auto-update dimatikan karena CSMDESK dianggap custom client |
| Butuh kontrol siapa yang boleh connect | `id-whitelist` di sisi user: hanya ID teknisi yang terdaftar |

## Fitur yang dipakai

- **Remote desktop** penuh (keyboard, mouse, clipboard, multi-monitor).
- **Portable tanpa admin**: satu `.exe`, tidak perlu instalasi.
- **Request elevation dari sisi IT**: teknisi meminta UAC; user hanya klik
  "Accept and Elevate", atau teknisi mengirim kredensial admin.
- **Privacy mode**: layar user dikosongkan saat sesi berjalan.
- **Chat** dalam sesi.
- **Transfer file** dua arah.
- **Address book / grup perangkat** untuk mengelola PC user.

## Perubahan branding

| File | Perubahan |
|---|---|
| `src/common.rs` | `BRAND_NAME = "CSMDESK"` diterapkan di `global_init`; public key custom client diganti milik CSMDESK |
| `src/platform/windows.rs` | direktori staging custom client memakai nama aplikasi |
| `src/auth_2fa.rs` | issuer TOTP `CSMDESK` |
| `flutter/windows/runner/Runner.rc` | metadata exe: ProductName, CompanyName, copyright (Purslane tetap dicantumkan) |
| `flutter/lib/desktop/widgets/tabbar_widget.dart` | judul jendela memakai `appName` |
| `flutter/lib/desktop/pages/desktop_setting_page.dart` | atribusi CSMDESK + RustDesk di halaman About |
| `res/icon.*`, `res/logo*.svg`, `flutter/assets/icon.*`, `logo*.png` | aset brand CSMDESK |
| `NOTICE` | atribusi upstream |

String UI lain otomatis diganti: `src/lang.rs` mengganti kata "RustDesk" dengan
nama aplikasi setiap kali nama bukan "RustDesk", kecuali `powered_by_me`
(kredit sengaja dipertahankan).

Aset brand dibuat ulang dengan:

```
python tools/generate_brand_assets.py
```

## Struktur

```
src/            kode Rust (client + service)
flutter/        UI Flutter
libs/portable/  packer untuk menghasilkan satu exe portable
deploy/         panduan & konfigurasi deployment
tools/          generator aset, signing custom client, build script
```

## Build (Windows x64)

Prasyarat:

- Rust stable (MSVC toolchain)
- Visual Studio Build Tools + "Desktop development with C++"
- Flutter SDK stable
- vcpkg (`VCPKG_ROOT`) dengan `libvpx`, `libyuv`, `opus`, `aom` (x64-windows-static)
- Python 3 + `pip install brotli`

```powershell
# signed config opsional, lihat deploy/README.md
powershell -ExecutionPolicy Bypass -File tools\build_portable.ps1 `
  -CustomTxt deploy\custom.txt
```

Output: `dist\CSMDESK-<versi>.exe` (portable, tanpa installer).

## Lisensi

AGPL-3.0. Lihat `LICENCE`. Setiap distribusi binary wajib menyertakan akses ke
source lengkap —repository ini memenuhi syarat tersebut. Perubahan pada
submodule `libs/hbb_common` **tidak** dilakukan; branding diterapkan dari kode
di repository ini.
