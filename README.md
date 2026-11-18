# Warpgate Bastion (Ready-to-Deploy Template)

Folder ini telah dibersihkan (*data cleansing*) dari seluruh database lama, log aktivitas, rekaman sesi (`recordings`), SSH keys, serta sertifikat TLS lama sehingga siap dipindahkan dan digunakan di host Linux baru.

## Struktur Direktori

```text
warpgate/
├── docker-compose.yml       # Konfigurasi container Warpgate
├── setup.sh                 # Script inisialisasi otomatis & manajemen reset data
├── install-docker.sh        # Script instalasi Docker multi-OS (Amazon Linux, Ubuntu, Debian, RHEL, AlmaLinux, Oracle Linux)
├── install-docker-al2023.sh # Script instalasi Docker khusus Amazon Linux 2023
├── README.md                # Panduan penggunaan & migrasi host
└── data/
    └── warpgate.yaml        # Konfigurasi dasar Warpgate (external_host: null)
```

## Mapping Port (`docker-compose.yml`)

| Layanan | Port Host | Port Container | Keterangan |
| :--- | :---: | :---: | :--- |
| **HTTP / Web Admin UI** | `8889` | `8888` | Dashboard Admin & Web Terminal (HTTPS) |
| **SSH Bastion** | `2222` | `2222` | Koneksi SSH melalui Warpgate |
| **MySQL Proxy** | `33306` | `33306` | Koneksi Proxy Database MySQL |
| **PostgreSQL Proxy** | `55432` | `55432` | Koneksi Proxy Database PostgreSQL |

---

## Cara Menggunakan di Host Linux Baru

### 1. Salin Folder ke Host Baru
Dari komputer ini, salin folder `warpgate` ke server Linux tujuan (misalnya menggunakan `scp` atau `rsync`):

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

Skrip ini akan otomatis mendeteksi distro OS, memasang Docker CE & Docker Compose V2, mengaktifkan service systemd, serta mengatur hak akses user non-root (seperti `ubuntu`, `ec2-user`, `opc`, `rocky`, dll.) agar dapat menjalankan perintah `docker` tanpa `sudo`.

---

### 3. Jalankan Setup & Start Container di Host Baru
Masuk ke server tujuan, lalu jalankan `./setup.sh`:

```bash
cd /opt/warpgate
chmod +x setup.sh

# Mode interaktif (akan meminta input password admin baru)
./setup.sh

# Atau langsung menentukan password admin dan domain/external host:
./setup.sh --password "PasswordAdminBaru123!" --host "bastion.domain-anda.com"
```

Script `setup.sh` akan otomatis:
1. Menjalankan `unattended-setup` untuk membuat database SQLite baru (`data/db/db.sqlite3`), SSH Host & Client Keys baru (`data/ssh-keys/`), serta sertifikat TLS baru (`data/tls.certificate.pem` & `data/tls.key.pem`).
2. Mengatur `trust_x_forwarded_headers: true` dan `external_host` pada `data/warpgate.yaml`.
3. Menjalankan container Warpgate di background (`docker compose up -d`).

### 4. Akses Dashboard Admin
Buka browser dan akses:
- **URL**: `https://<IP-HOST-BARU>:8889`
- **Username**: `admin`
- **Password**: *(sesuai yang dimasukkan saat menjalankan `./setup.sh`)*

---

## Cara Reset / Cleansing Ulang di Kemudian Hari

Jika suatu saat ingin mengosongkan kembali seluruh database, log, rekaman sesi, dan key ke kondisi awal:

```bash
./setup.sh --reset
```
