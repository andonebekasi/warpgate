<div align="center">

# Warpgate Bastion (Ready-to-Deploy Template)

🌐 **Pilih Bahasa / Select Language:**  
[English](README.md) • **Bahasa Indonesia**

👨‍💻 **Created by Andi Pangeran**

---
</div>

Folder ini telah dibersihkan (*data cleansing*) dari seluruh database lama, log aktivitas, rekaman sesi (`recordings`), SSH keys, serta sertifikat TLS lama sehingga siap dipindahkan dan digunakan langsung di host Linux baru.

## 📁 Struktur Direktori

```text
warpgate/
├── install.sh               # Skrip One-Line via curl: cek & instal Docker + Warpgate otomatis
├── deploy-warpgate.sh       # Skrip All-in-One: cek & instal Docker otomatis + deploy Warpgate
├── setup.sh                 # Skrip inisialisasi Warpgate & manajemen reset data
├── install-docker.sh        # Skrip instalasi Docker multi-OS (standalone)
├── install-docker-al2023.sh # Skrip instalasi Docker khusus Amazon Linux 2023
├── docker-compose.yml       # Konfigurasi container Warpgate
├── README.md                # Dokumentasi utama (English)
├── README.id.md             # Panduan penggunaan (Bahasa Indonesia)
├── PANDUAN_ADMIN_WARPGATE.md# Panduan lengkap Admin UI & Konfigurasi Target
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

## 🚀 Panduan Deployment di Host Linux Baru

### ⚡ Metode 0: Quick Install Otomatis via `curl` (1 Perintah di Host Baru) — *Paling Cepat & Praktis*

Jika Anda baru saja membuat VPS / Instance baru (Ubuntu, Debian, AL2023, CentOS, RHEL, Rocky, AlmaLinux, Oracle Linux) dan belum menginstal apapun, Anda dapat menjalankan instalasi lengkap hanya dengan **1 baris perintah `curl`** tanpa perlu clone atau salin folder terlebih dahulu.

#### Apa yang Dilakukan Skrip `install.sh` Secara Otomatis:
1. **Pemeriksaan `curl`**: Memastikan package `curl` tersedia di sistem.
2. **Pemeriksaan Docker Engine**:
   - Mengecek apakah command `docker` sudah ada.
   - Jika **belum ada**, langsung mengunduh dan memasang Docker Engine resmi menggunakan `curl -fsSL https://get.docker.com` (atau repository native `dnf` pada Amazon Linux 2023).
   - Mengaktifkan dan menjalankan daemon Docker di background (`systemctl enable --now docker`).
   - Mengonfigurasi permission non-root (menambahkan user ke grup `docker` & ACL socket `/var/run/docker.sock`).
3. **Pemeriksaan Docker Compose**:
   - Mendeteksi ketersediaan Docker Compose V2.
   - Jika belum ada, otomatis mengunduh binary Docker Compose resmi via `curl` ke `/usr/local/lib/docker/cli-plugins/docker-compose`.
4. **Pemasangan Standalone CLI Warpgate**:
   - Mendeteksi rilis versi terbaru Warpgate dari GitHub.
   - Mengunduh binary resmi Warpgate Linux (`x86_64` atau `arm64`) via `curl` ke `/usr/local/bin/warpgate`. Anda bisa langsung menjalankan perintah `warpgate --help` di terminal host.
5. **Deployment Container Warpgate**:
   - Menyiapkan direktori instalasi di `/opt/warpgate`.
   - Mengunduh `docker-compose.yml` dan template config via `curl` dari GitHub repository.
   - Melakukan inisialisasi awal (*unattended setup*) untuk membuat database SQLite, sertifikat TLS HTTPS, dan SSH host keys baru.
   - Menjalankan container Warpgate di background (`docker compose up -d`).

#### Cara Menjalankan via `curl`:
```bash
# Mode Interaktif (skrip akan meminta input password admin secara aman):
curl -fsSL https://raw.githubusercontent.com/andonebekasi/warpgate/main/install.sh | bash

# Mode Non-Interaktif (langsung menyertakan password dan domain/host):
curl -fsSL https://raw.githubusercontent.com/andonebekasi/warpgate/main/install.sh | bash -s -- --password "PasswordAdminBaru123!" --host "bastion.domain-anda.com"

# Opsi kustom direktori instalasi:
curl -fsSL https://raw.githubusercontent.com/andonebekasi/warpgate/main/install.sh | bash -s -- --dir "/custom/path/warpgate" --password "PasswordAdminBaru123!"

# Melewati pengunduhan binary CLI standalone (hanya container Docker):
curl -fsSL https://raw.githubusercontent.com/andonebekasi/warpgate/main/install.sh | bash -s -- --skip-cli
```

#### Cara Menjalankan Secara Lokal (Jika Folder Sudah Diunduh):
```bash
chmod +x install.sh
./install.sh --password "PasswordAdminBaru123!"
```

---

### 1. Salin Folder ke Host Baru (Opsional jika deploy manual)

```bash
# Menggunakan scp
scp -r /path/to/warpgate user@ip-host-baru:/opt/warpgate

# Atau menggunakan rsync
rsync -avzP /path/to/warpgate/ user@ip-host-baru:/opt/warpgate/
```

---

### ⚡ Metode 1: All-in-One Deployment (`deploy-warpgate.sh`) — *Sangat Direkomendasikan*

Skrip `deploy-warpgate.sh` adalah skrip otomatisasi satu langkah yang menggabungkan seluruh proses persiapan server hingga Warpgate siap digunakan.

**Fungsi Skrip `deploy-warpgate.sh`:**
1. **Pemeriksaan Docker**: Mendeteksi apakah Docker Engine dan Docker Compose sudah terpasang dan berjalan di sistem.
2. **Otomatis Install Docker**: Jika Docker belum ada, skrip akan langsung mengidentifikasi OS Anda dan menginstalnya secara otomatis (mendukung Amazon Linux 2/2023, Ubuntu, Debian, RHEL, CentOS, Rocky Linux, AlmaLinux, Oracle Linux) beserta konfigurasi user permission non-root (bisa akses Docker tanpa `sudo`).
3. **Inisialisasi & Jalankan Warpgate**: Setelah Docker siap, skrip langsung menjalankan inisialisasi database SQLite, sertifikat TLS, SSH keys, konfigurasi reverse proxy, dan menyalakan container Warpgate (`docker compose up -d`).

#### Cara Menjalankan:
```bash
cd /opt/warpgate
chmod +x deploy-warpgate.sh

# Mode interaktif (akan meminta input password admin baru):
./deploy-warpgate.sh

# Atau mode non-interaktif (langsung menyertakan password dan domain/host):
./deploy-warpgate.sh --password "PasswordAdminBaru123!" --host "bastion.domain-anda.com"
```

**Pilihan Opsi / Parameter:**
- `--password <PASS>` : Tentukan password awal akun `admin` Warpgate.
- `--host <HOSTNAME>` : Tentukan domain atau Public IP untuk `external_host` Warpgate.
- `--skip-run` : Hanya jalankan pengecekan OS dan instalasi Docker tanpa langsung menyalakan Warpgate.
- `-h, --help` : Tampilkan panduan penggunaan parameter.

---

### 🛠️ Metode 2: Deployment Bertahap (Manual / Step-by-Step)

Jika Anda ingin menjalankan proses instalasi Docker dan setup Warpgate secara terpisah:

#### Langkah A: Instalasi Docker & Docker Compose
Jika host baru belum memiliki Docker, pasang menggunakan `install-docker.sh`:

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

#### Langkah B: Inisialisasi & Start Container
Setelah Docker aktif, jalankan inisialisasi Warpgate:

```bash
chmod +x setup.sh

# Mode interaktif:
./setup.sh

# Atau mode non-interaktif:
./setup.sh --password "PasswordAdminBaru123!" --host "bastion.domain-anda.com"
```

---

### 🌐 Akses Dashboard Admin
Buka browser dan akses:
- **URL**: `https://<IP-HOST-BARU>:8889`
- **Username**: `admin`
- **Password**: *(sesuai dengan yang dimasukkan saat menjalankan skrip deploy/setup)*

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

---

## 📚 Dokumentasi Lanjutan

- [PANDUAN_ADMIN_WARPGATE.md](PANDUAN_ADMIN_WARPGATE.md): Panduan lengkap pengelolaan Admin UI Warpgate, penjelasan menu (Targets, Users, Roles, Tickets, SSH Keys), serta panduan konfigurasi host target Linux (SSH) dan Windows (RDP).

---

## 👤 Author / Pembuat

Created by **Andi Pangeran**
