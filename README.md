<div align="center">

# Warpgate Bastion (Ready-to-Deploy Template)

🌐 **Select Language / Pilih Bahasa:**  
**English** • [Bahasa Indonesia](README.id.md)

---
</div>

This directory has been pre-cleansed (*data cleansed*) of all legacy databases, activity logs, session recordings (`recordings`), SSH keys, and old TLS certificates, making it a clean, ready-to-deploy template for any new Linux host.

## 📁 Directory Structure

```text
warpgate/
├── docker-compose.yml       # Warpgate container service definition
├── setup.sh                 # Automated initialization & data reset management script
├── install-docker.sh        # Multi-OS Docker & Docker Compose installation script
├── install-docker-al2023.sh # Dedicated Docker installer for Amazon Linux 2023
├── README.md                # Main documentation (English)
├── README.id.md             # Documentation (Bahasa Indonesia)
└── data/
    └── warpgate.yaml        # Base Warpgate configuration (external_host: null)
```

## 🔌 Port Mapping (`docker-compose.yml`)

| Service | Host Port | Container Port | Description |
| :--- | :---: | :---: | :--- |
| **HTTP / Web Admin UI** | `8889` | `8888` | Admin Dashboard & Web Terminal (HTTPS) |
| **SSH Bastion** | `2222` | `2222` | SSH proxy connections via Warpgate |
| **MySQL Proxy** | `33306` | `33306` | MySQL database proxy connections |
| **PostgreSQL Proxy** | `55432` | `55432` | PostgreSQL database proxy connections |

---

## 🚀 Deployment Guide for a New Linux Host

### 1. Copy Folder to the New Host
From your local machine or source server, transfer the `warpgate` directory to the destination Linux server (e.g., using `scp` or `rsync`):

```bash
# Using scp
scp -r /path/to/warpgate user@new-host-ip:/opt/warpgate

# Or using rsync
rsync -avzP /path/to/warpgate/ user@new-host-ip:/opt/warpgate/
```

### 2. Install Docker & Docker Compose (If Not Already Installed)
If the new host does not have Docker and Docker Compose installed, run the automated installation script:

```bash
cd /opt/warpgate
chmod +x install-docker.sh
./install-docker.sh
```

> **Automatically Supported Linux Distributions:**
> - **Amazon Linux 2** & **Amazon Linux 2023 (AL3)**
> - **Ubuntu** (18.04, 20.04, 22.04, 24.04 LTS and newer)
> - **Debian** (10 Buster, 11 Bullseye, 12 Bookworm, etc.)
> - **RHEL** (Red Hat Enterprise Linux 7, 8, 9)
> - **AlmaLinux** & **Rocky Linux** (8, 9)
> - **Oracle Linux** (OL 7, 8, 9)

This script automatically detects your distribution, installs Docker CE & Docker Compose V2, enables systemd services, and adds the current non-root user (e.g., `ubuntu`, `ec2-user`, `opc`, `rocky`, etc.) to the `docker` group so you can run `docker` without `sudo`.

---

### 3. Initialize & Start Container
Log into the destination server and execute `./setup.sh`:

```bash
cd /opt/warpgate
chmod +x setup.sh

# Interactive mode (will prompt for a new admin password):
./setup.sh

# Or non-interactive mode (specify admin password and host domain directly):
./setup.sh --password "YourStrongAdminPassword123!" --host "bastion.your-domain.com"
```

The `setup.sh` script will automatically:
1. Run `unattended-setup` to generate a fresh SQLite database (`data/db/db.sqlite3`), new SSH Host & Client keys (`data/ssh-keys/`), and new TLS certificates (`data/tls.certificate.pem` & `data/tls.key.pem`).
2. Set `trust_x_forwarded_headers: true` and configure `external_host` in `data/warpgate.yaml`.
3. Launch the Warpgate container in the background (`docker compose up -d`).

### 4. Access Admin Dashboard
Open your web browser and navigate to:
- **URL**: `https://<NEW-HOST-IP>:8889`
- **Username**: `admin`
- **Password**: *(the password provided during `./setup.sh`)*

> [!NOTE]
> Since the initial setup creates a self-signed TLS certificate, your browser may display a security warning (*Your connection is not private*). Click *Advanced* -> *Proceed* to continue.

---

## 🛠️ Common Operations

| Action | Command |
| :--- | :--- |
| **Check container status** | `docker compose ps` |
| **View live logs** | `docker compose logs -f` |
| **Restart container** | `docker compose restart` |
| **Stop container** | `docker compose down` |

---

## 🔄 Reset / Re-cleansing in the Future

If you ever need to reset Warpgate back to a completely clean state (erasing databases, logs, session recordings, and keys):

```bash
./setup.sh --reset
```
