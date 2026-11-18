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
├── deploy-warpgate.sh       # All-in-one deployer (auto check & install Docker + deploy Warpgate)
├── setup.sh                 # Warpgate initialization & data reset management script
├── install-docker.sh        # Multi-OS Docker & Docker Compose installation script (standalone)
├── install-docker-al2023.sh # Dedicated Docker installer for Amazon Linux 2023
├── docker-compose.yml       # Warpgate container service definition
├── README.md                # Main documentation (English)
├── README.id.md             # Documentation (Bahasa Indonesia)
├── PANDUAN_ADMIN_WARPGATE.md# Complete Admin UI & Target configuration guide
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

---

### ⚡ Method 1: All-in-One Deployment (`deploy-warpgate.sh`) — *Recommended*

The `deploy-warpgate.sh` script is a unified, single-step automation script that handles everything from server prerequisite validation to launching Warpgate.

**What `deploy-warpgate.sh` does:**
1. **Docker Check**: Checks whether Docker Engine and Docker Compose are installed and operational on the host.
2. **Auto-Install Docker**: If Docker is not found, it automatically detects your OS distribution (supporting Amazon Linux 2/2023, Ubuntu, Debian, RHEL, CentOS, Rocky Linux, AlmaLinux, Oracle Linux) and installs Docker Engine & Docker Compose V2, configuring non-root user permissions (running Docker without `sudo`).
3. **Auto-Setup & Run Warpgate**: Once Docker is confirmed ready, it initializes the SQLite database, TLS certificate, SSH keys, sets up proxy reverse header settings, and starts the Warpgate container (`docker compose up -d`).

#### How to Run:
```bash
cd /opt/warpgate
chmod +x deploy-warpgate.sh

# Interactive mode (will prompt for a new admin password):
./deploy-warpgate.sh

# Or non-interactive mode (specify admin password and host domain directly):
./deploy-warpgate.sh --password "YourStrongAdminPassword123!" --host "bastion.your-domain.com"
```

**Available Options / Flags:**
- `--password <PASS>` : Initial password for the Warpgate `admin` user.
- `--host <HOSTNAME>` : Domain or Public IP for Warpgate's `external_host`.
- `--skip-run` : Only perform OS check & Docker installation without starting Warpgate.
- `-h, --help` : Show help message and usage details.

---

### 🛠️ Method 2: Step-by-Step Deployment (Manual)

If you prefer to install Docker and initialize Warpgate in separate steps:

#### Step A: Install Docker & Docker Compose
If the new host does not have Docker and Docker Compose installed, run:

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

#### Step B: Initialize & Start Container
Once Docker is running, initialize Warpgate:

```bash
chmod +x setup.sh

# Interactive mode:
./setup.sh

# Or non-interactive mode:
./setup.sh --password "YourStrongAdminPassword123!" --host "bastion.your-domain.com"
```

---

### 🌐 Access Admin Dashboard
Open your web browser and navigate to:
- **URL**: `https://<NEW-HOST-IP>:8889`
- **Username**: `admin`
- **Password**: *(the password provided during the deploy/setup script)*

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

---

## 📚 Additional Documentation

- [PANDUAN_ADMIN_WARPGATE.md](PANDUAN_ADMIN_WARPGATE.md): Comprehensive Warpgate Admin UI guide, menu explanations (Targets, Users, Roles, Tickets, SSH Keys), and target configuration for Linux (SSH) and Windows (RDP).
