<div align="center">

# Warpgate Bastion (Ready-to-Deploy Template)

🌐 **Pilih Bahasa / Select Language:**  
[English](README.md) • **Bahasa Indonesia**

---
</div>

Folder ini telah dibersihkan (*data cleansing*) dari seluruh database lama, log aktivitas, rekaman sesi (`recordings`), SSH keys, serta sertifikat TLS lama sehingga siap dipindahkan dan digunakan langsung di host Linux baru.

## 📁 Struktur Direktori

```text
warpgate/
├── docker-compose.yml       # Konfigurasi container Warpgate
├── setup.sh                 # Skrip inisialisasi otomatis & manajemen reset data
├── install-docker.sh        # Skrip instalasi Docker multi-OS (Amazon Linux, Ubuntu, Debian, RHEL, AlmaLinux, Oracle Linux)
├── install-docker-al2023.sh # Skrip instalasi Docker khusus Amazon Linux 2023
├── README.md                # Dokumentasi utama (English)
├── README.id.md             # Panduan penggunaan (Bahasa Indonesia)
└── data/
    └── warpgate.yaml        # Konfigurasi dasar Warpgate (external_host: null)
```

## 🔌 Mapping Port (`docker-compose.yml`)

| Layanan | Port Host | Port Container | Keterangan |
| :--- | :---: | :---: | :--- |
| **HTTP / Web Admin UI** | `8889` | `8888` | Dashboard Admin & Web Terminal (HTTPS) |
| **SSH Bastion** | `2222` | `2222` | Koneksi SSH melalui Warpgate |
| **MySQL Proxy** | `33306` | `33306` | Koneksi Proxy Database MySQL |
| **PostgreSQL Proxy** | `55432` | `55432` | Koneksi Proxy Database PostgreSQL |

---

## 🚀 Panduan Penggunaan di Host Linux Baru

### 1. Salin Folder ke Host Baru
Dari komputer lokal atau server lama, salin folder `warpgate` ke server Linux tujuan (misalnya menggunakan `scp` atau `rsync`):

```bash
# Menggunakan scp
scp -r /path/to/warpgate user@ip-host-baru:/opt/warpgate

# Atau menggunakan rsync
rsync -avzP /path/to/warpgate/ user@ip-host-baru:/opt/warpgate/
```

### 2. Instalasi Docker & Docker Compose (Jika Belum Terpasang)
Jika host baru belum memiliki Docker dan Docker Compose, jalankan skrip instalasi otomatis:

```bash
cd /opt/warpgate
chmod +x install-docker.sh
./install-docker.sh
```

> **Distribusi Linux yang Didukung Secara Otomatis:**
> - **Amazon Linux 2** & **Amazon Linux 2023 (AL3)**
> - **Ubuntu** (18.04, 20.04, 22.04, 24.04 LTS hingga terbaru)
> - **Debian** (10 Buster, 11 Bullseye, 12 Bookworm, dll.)
> - **RHEL** (Red Hat Enterprise Linux 7, 8, 9)
> - **AlmaLinux** & **Rocky Linux** (8, 9)
> - **Oracle Linux** (OL 7, 8, 9)

Skrip ini otomatis mendeteksi distro OS, memasang Docker CE & Docker Compose V2, mengaktifkan service systemd, serta mengatur user non-root (seperti `ubuntu`, `ec2-user`, `opc`, `rocky`, dll.) agar dapat menjalankan `docker` tanpa `sudo`.

---

### 3. Jalankan Inisialisasi & Start Container
Masuk ke server tujuan, lalu jalankan `./setup.sh`:

```bash
cd /opt/warpgate
chmod +x setup.sh

# Mode interaktif (akan meminta input password admin baru):
./setup.sh

# Atau mode otomatis (langsung menentukan password dan domain host):
./setup.sh --password "PasswordAdminBaru123!" --host "bastion.domain-anda.com"
```

Skrip `setup.sh` akan secara otomatis:
1. Menjalankan `unattended-setup` untuk membuat database SQLite baru (`data/db/db.sqlite3`), SSH Host & Client Keys baru (`data/ssh-keys/`), serta sertifikat TLS baru (`data/tls.certificate.pem` & `data/tls.key.pem`).
2. Mengatur `trust_x_forwarded_headers: true` dan `external_host` pada `data/warpgate.yaml`.
3. Menjalankan container Warpgate di latar belakang (`docker compose up -d`).

### 4. Akses Dashboard Admin
Buka browser dan akses:
- **URL**: `https://<IP-HOST-BARU>:8889`
- **Username**: `admin`
- **Password**: *(sesuai dengan yang dimasukkan saat menjalankan `./setup.sh`)*

> [!NOTE]
> Karena menggunakan self-signed TLS certificate bawaan saat inisialisasi, browser mungkin akan menampilkan peringatan keamanan (*Your connection is not private*). Anda dapat memilih *Advanced* -> *Proceed*.

---

## 🛠️ Perintah Berguna (Operations)

| Kebutuhan | Perintah |
| :--- | :--- |
| **Cek status container** | `docker compose ps` |
| **Lihat log aktivitas** | `docker compose logs -f` |
| **Restart container** | `docker compose restart` |
| **Stop container** | `docker compose down` |

---

## 🔄 Reset / Cleansing Ulang di Kemudian Hari

Jika di masa mendatang Anda ingin mengosongkan kembali seluruh database, log, rekaman sesi, dan keys ke kondisi template bersih:

```bash
./setup.sh --reset
```
