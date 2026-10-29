# Panduan Deployment CSMDESK

Topologi: semua koneksi (IT -> user, dan user <-> user) melewati server CSMDESK.
Client portable tidak menyentuh jaringan publik RustDesk.

```
            +----------------------------------+
            |  Server CSMDESK (hbbs + hbbr)    |
            |  ID/rendezvous : 21115-21116     |
            |  relay         : 21117           |
            +-----------------+----------------+
                     ^            ^
        register ID  |            |  koneksi P2P / relay (terenkripsi)
                     |            |
        +------------+--+      +--+---------------+
        | IT (controller)|     | User (portable)  |
        | csmdesk.exe    |<--->| CSMDESK.exe      |
        +----------------+     +------------------+
```

## 1. Siapkan server

Satu VPS / server kampus dengan Docker. Domain contoh: `rd.csmdesk.example`
(ganti dengan domain/subdomain sendiri).

```yaml
# docker-compose.yml
services:
  hbbs:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbs
    command: hbbs -r rd.csmdesk.example:21117 -k _
    ports:
      - "21115:21115/tcp"
      - "21116:21116/tcp"
      - "21116:21116/udp"
      - "21118:21118/tcp"
    volumes:
      - ./data:/root
    restart: unless-stopped
  hbbr:
    image: rustdesk/rustdesk-server:latest
    container_name: hbbr
    ports:
      - "21117:21117/tcp"
      - "21119:21119/tcp"
    volumes:
      - ./data:/root
    restart: unless-stopped
```

```bash
docker compose up -d
# public key server (dipakai client untuk verifikasi)
cat ./data/id_ed25519.pub
```

Port yang harus dibuka: `21115/tcp, 21116/tcp+udp, 21118/tcp` untuk hbbs,
`21117/tcp, 21119/tcp` untuk hbbr. Firewall jaringan user wajib
mengizinkan keluar ke port tersebut.

`-k _` memaksa semua client memakai key; tanpa itu koneksi tak terverifikasi
bisa lolos.

## 2. Buat konfigurasi client (signed custom client)

Public key signing client sudah di-compile ke binary (`src/common.rs`, `const KEY`).
Kunci privatnya ada di `D:\Project\CSMDESK\secrets\csmdesk_signing.key`
**di luar repository** — jangan pernah di-commit.

```bash
# salin contoh, isi nilai sebenarnya
cp deploy/custom-client.example.json deploy/custom-client.local.json
# edit custom-client.local.json:
#   custom-rendezvous-server : host hbbs
#   key                      : isi id_ed25519.pub
#   id-whitelist             : daftar ID client teknisi, dipisah koma

python tools/csmdesk_custom.py sign \
  --key ../secrets/csmdesk_signing.key \
  --config deploy/custom-client.local.json \
  --out deploy/custom.txt
```

Karena binary hanya menerima custom.txt yang ditandatangani kunci ini, pihak
luar tidak bisa mem-pointing ulang client CSMDESK.

Rencana kunci whitelist:

- Daftarkan ID laptop tiap teknisi ke `id-whitelist`, lalu build + redistribusi.
- Tambahan teknisi baru = edit JSON, re-sign, rebuild portable, distribute ulang.
- Kalau butuh fleksibilitas harian, pindahkan `id-whitelist` dari
  `override-settings` ke `default-settings` (prefilled tapi masih bisa diubah
  lewat remote config oleh IT).

## 3. Build portable

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_portable.ps1 `
  -CustomTxt deploy\custom.txt
```

Output: `dist\CSMDESK-<versi>.exe` — satu file, config sudah ter-embed.

## 4. Distribusi ke user

1. Bagikan `CSMDESK.exe` (link internal / email / share folder).
2. User double-click — tidak perlu admin, tidak perlu install.
3. ID perangkat muncul di jendela utama; minta user mengirimkan ID-nya ke
   helpdesk agar bisa dibooking di address book.
4. Saat sesi berjalan ada popup "Accept" — **jangan dimatikan**; itu fondasi
   consent (UU PDP 27/2022 + etika support).

## 5. Alur kerja IT

| Kebutuhan | Cara |
|---|---|
| Remote biasa | Masukkan ID user, koneksi harus di-accept user |
| Install software / UAC | Klik **Request Elevation** di toolbar → user klik "Accept and Elevate", ATAU kirim username/password admin lewat dialog Request Elevation |
| Privacy mode | Aktifkan di toolbar sesi (butuh `enable-privacy-mode=Y` di config client) |
| Chat | Ikon chat di toolbar sesi |
| Transfer file | Buka sesi "File Transfer" atau ikon transfer di toolbar |

Catatan portable + UAC: portable exe tidak punya hak admin. Untuk mengontrol
window elevated (Task Manager, prompt UAC) gunakan Request Elevation di atas.
Jika user tidak ada di tempat, gunakan build dengan suffix `-qs-` pada nama exe
(`CSMDESK-qs-.exe`) agar minta elevasi saat start — pakai ini hanya untuk
lab/kiosk yang memang diizinkan kebijakan, bukan PC pribadi pegawai.

## 6. Keamanan & kepatuhan

- Semua koneksi terenkripsi end-to-end (NaCl); server hanya meneruskan.
- `id-whitelist` membatasi siapa yang bisa connect ke PC user.
- Tanpa password permanen/unattended yang diaktifkan default; sesi per sesi.
- Simpan kunci signing `csmdesk_signing.key` di tempat aman (password manager /
  vault), **bukan** di repository. Kehilangan = semua client harus dibangun ulang.
- Dokumentasikan setiap sesi remote di tiket support.

## 7. Troubleshooting cepat

| Gejala | Cek |
|---|---|
| Client tidak dapat ID | Port 21116 UDP/TCP ke hbbs; `custom-rendezvous-server` benar |
| "Key mismatch" | `key` di custom.txt != `id_ed25519.pub` server |
| custom.txt diabaikan | File harus bernama persis `custom.txt` dan berada di folder yang sama dengan exe; harus signed dengan kunci yang ter-compile |
| UAC screen hitam | Gunakan Request Elevation; pastikan user klik accept |
| Privacy mode tidak tersedia | Aktifkan `enable-privacy-mode`; Windows 10+; cek driver virtual display di sisi user |
