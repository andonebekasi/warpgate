#!/usr/bin/env bash
# ==============================================================================
# One-Line Auto Installer: Docker Engine & Warpgate Bastion
# 
# Dapat dijalankan langsung via curl:
#   curl -fsSL https://raw.githubusercontent.com/andonebekasi/warpgate/main/install.sh | bash
# Atau dengan argumen:
#   curl -fsSL https://raw.githubusercontent.com/andonebekasi/warpgate/main/install.sh | bash -s -- --password "Rahasia123!" --host "bastion.domain.com"
# Atau dijalankan lokal:
#   ./install.sh --password "Rahasia123!"
# ==============================================================================
set -euo pipefail

# --- Warna Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo -e "${BOLD}==========================================================${NC}"
echo -e "${BOLD}   Warpgate & Docker Automated Installer (via curl)       ${NC}"
echo -e "${BOLD}==========================================================${NC}"

# --- 1. Hak Akses Root / Sudo ---
SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        log_error "Script ini memerlukan hak akses root atau sudo."
        exit 1
    fi
fi

# Target user non-root untuk izin docker
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER}")}"

# --- 2. Parsing Argumen ---
ADMIN_PASSWORD="${WARPGATE_ADMIN_PASSWORD:-}"
EXTERNAL_HOST=""
INSTALL_DIR=""
SKIP_CLI=false

usage() {
    cat <<EOF
Penggunaan: $0 [OPSI]

Opsi:
  --password <PASS>   Password awal untuk akun 'admin' Warpgate
  --host <HOSTNAME>   Domain atau Public IP untuk external_host Warpgate
  --dir <PATH>        Direktori instalasi Warpgate (default: /opt/warpgate atau direktori saat ini)
  --skip-cli          Lewati pengunduhan warpgate standalone CLI binary
  -h, --help          Tampilkan panduan ini
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --host)
            EXTERNAL_HOST="$2"
            shift 2
            ;;
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --skip-cli)
            SKIP_CLI=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_warn "Opsi tidak dikenal diabaikan: $1"
            shift
            ;;
    esac
done

# --- 3. Deteksi Arsitektur & OS ---
RAW_ARCH="$(uname -m)"
case "${RAW_ARCH}" in
    x86_64|amd64)
        DOCKER_ARCH="x86_64"
        WARPGATE_ARCH="x86_64"
        DEB_ARCH="amd64"
        ;;
    aarch64|arm64)
        DOCKER_ARCH="aarch64"
        WARPGATE_ARCH="arm64"
        DEB_ARCH="arm64"
        ;;
    *)
        log_error "Arsitektur CPU ${RAW_ARCH} saat ini belum didukung."
        exit 1
        ;;
esac

OS_ID="unknown"
OS_NAME="Linux"
OS_VERSION_ID=""
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_NAME="${PRETTY_NAME:-Linux}"
    OS_VERSION_ID="${VERSION_ID:-}"
fi

log_ok "OS Terdeteksi : ${OS_NAME} (${OS_ID})"
log_ok "Arsitektur    : ${RAW_ARCH}"
log_ok "User Target   : ${TARGET_USER}"

# --- 4. Pastikan 'curl' Sudah Terpasang ---
if ! command -v curl >/dev/null 2>&1; then
    log_info "curl belum terpasang. Memasang curl terlebih dahulu..."
    if command -v apt-get >/dev/null 2>&1; then
        ${SUDO} apt-get update -y && ${SUDO} apt-get install -y curl ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        ${SUDO} dnf install -y curl ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        ${SUDO} yum install -y curl ca-certificates
    else
        log_error "Package manager tidak dikenali. Harap instal 'curl' secara manual."
        exit 1
    fi
    log_ok "curl berhasil dipasang."
fi

# ==============================================================================
# TAHAP 1: PENGECEKAN & INSTALASI DOCKER ENGINE VIA CURL
# ==============================================================================
echo ""
echo -e "${BOLD}--- [1/3] Pengecekan Docker & Docker Compose ---${NC}"

NEED_DOCKER=false
if ! command -v docker >/dev/null 2>&1; then
    log_warn "Docker belum terpasang di sistem!"
    NEED_DOCKER=true
else
    log_ok "Docker sudah terinstall: $(docker --version)"
fi

if [[ "${NEED_DOCKER}" == true ]]; then
    log_info "Memulai instalasi otomatis Docker menggunakan script resmi via curl..."

    # Khusus Amazon Linux 2023 / AL2 yang memiliki paket repo native
    if [[ "${OS_ID}" == "amzn" ]]; then
        if [[ "${OS_VERSION_ID}" =~ ^2023 ]]; then
            log_info "Menginstall Docker di Amazon Linux 2023 via dnf..."
            ${SUDO} dnf update -y
            ${SUDO} dnf install -y docker libxcrypt-compat iptables
        elif [[ "${OS_VERSION_ID}" =~ ^2 ]]; then
            log_info "Menginstall Docker di Amazon Linux 2..."
            ${SUDO} amazon-linux-extras install docker -y 2>/dev/null || ${SUDO} yum install -y docker
        fi
    else
        # Metode universal via get.docker.com menggunakan curl
        log_info "Mengunduh dan mengeksekusi https://get.docker.com via curl..."
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        ${SUDO} sh /tmp/get-docker.sh
        rm -f /tmp/get-docker.sh
    fi

    # Aktifkan service docker
    log_info "Mengaktifkan dan menjalankan layanan Docker daemon..."
    ${SUDO} systemctl enable --now docker || true
    ${SUDO} systemctl start docker || true
    log_ok "Docker Engine berhasil diinstall."
fi

# Konfigurasi user permission non-root
if ! docker info >/dev/null 2>&1; then
    log_info "Mengonfigurasi grup docker untuk user '${TARGET_USER}'..."
    ${SUDO} groupadd -f docker || true
    if id -u "${TARGET_USER}" >/dev/null 2>&1; then
        ${SUDO} usermod -aG docker "${TARGET_USER}" || true
        if [[ -S /var/run/docker.sock ]]; then
            ${SUDO} chmod 660 /var/run/docker.sock || true
            ${SUDO} chown root:docker /var/run/docker.sock || true
            if command -v setfacl >/dev/null 2>&1; then
                ${SUDO} setfacl -m u:"${TARGET_USER}":rw /var/run/docker.sock 2>/dev/null || true
            fi
        fi
    fi
    # Restart docker jika diperlukan
    ${SUDO} systemctl restart docker || true
    sleep 2
fi

# Deteksi atau Install Docker Compose Plugin
COMPOSE_CMD=()
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
    log_ok "Docker Compose (Plugin) aktif: $(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
    log_ok "Docker Compose (Standalone) aktif: $(docker-compose version)"
else
    log_warn "Docker Compose belum ditemukan. Memasang via curl..."
    COMPOSE_VER="v2.30.3"
    COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-linux-${DOCKER_ARCH}"
    ${SUDO} mkdir -p /usr/local/lib/docker/cli-plugins
    ${SUDO} curl -fsSL "${COMPOSE_URL}" -o /usr/local/lib/docker/cli-plugins/docker-compose
    ${SUDO} chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose 2>/dev/null || true
    ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/bin/docker-compose 2>/dev/null || true

    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD=(docker compose)
    else
        COMPOSE_CMD=(docker-compose)
    fi
    log_ok "Docker Compose berhasil dipasang via curl."
fi

# ==============================================================================
# TAHAP 2: PENGECEKAN & INSTALASI WARPGATE CLI BINARY VIA CURL
# ==============================================================================
echo ""
echo -e "${BOLD}--- [2/3] Pengecekan & Instalasi Warpgate Binary (via curl) ---${NC}"

if [[ "${SKIP_CLI}" == false ]]; then
    if command -v warpgate >/dev/null 2>&1; then
        log_ok "Warpgate CLI binary sudah terinstall: $(warpgate --version 2>/dev/null || echo "terpasang")"
    else
        log_info "Mencari versi terbaru Warpgate dari GitHub Releases..."
        WARPGATE_VER="$(curl -sI https://github.com/warp-tech/warpgate/releases/latest | grep -i "location:" | sed -e 's/.*tag\///' | tr -d '\r\n')"
        if [[ -z "${WARPGATE_VER}" ]]; then
            WARPGATE_VER="v0.30.4"
        fi
        log_info "Versi Warpgate: ${WARPGATE_VER} (${WARPGATE_ARCH})"

        BINARY_URL="https://github.com/warp-tech/warpgate/releases/download/${WARPGATE_VER}/warpgate-${WARPGATE_VER}-${WARPGATE_ARCH}-linux"
        log_info "Mengunduh Warpgate binary dari: ${BINARY_URL} ..."
        
        TEMP_BIN="/tmp/warpgate-bin"
        if curl -fsSL "${BINARY_URL}" -o "${TEMP_BIN}"; then
            ${SUDO} mv "${TEMP_BIN}" /usr/local/bin/warpgate
            ${SUDO} chmod +x /usr/local/bin/warpgate
            log_ok "Warpgate CLI binary berhasil dipasang ke /usr/local/bin/warpgate"
            warpgate --version 2>/dev/null || true
        else
            log_warn "Gagal mengunduh binary standalone Warpgate, container docker tetap akan berjalan."
            rm -f "${TEMP_BIN}"
        fi
    fi
else
    log_info "Opsi --skip-cli aktif, melewati instalasi binary Warpgate."
fi

# ==============================================================================
# TAHAP 3: DEPLOYMENT WARPGATE CONTAINER & KONFIGURASI
# ==============================================================================
echo ""
echo -e "${BOLD}--- [3/3] Penyiapan dan Deployment Warpgate Container ---${NC}"

# Tentukan direktori instalasi
if [[ -n "${INSTALL_DIR}" ]]; then
    TARGET_DIR="${INSTALL_DIR}"
elif [[ -f "docker-compose.yml" && -d "data" ]]; then
    TARGET_DIR="$(pwd)"
elif [[ -d "/opt/warpgate" ]]; then
    TARGET_DIR="/opt/warpgate"
else
    TARGET_DIR="/opt/warpgate"
fi

log_info "Direktori Warpgate: ${TARGET_DIR}"
${SUDO} mkdir -p "${TARGET_DIR}/data"
${SUDO} chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_DIR}" 2>/dev/null || true

cd "${TARGET_DIR}"

REPO_RAW_URL="https://raw.githubusercontent.com/andonebekasi/warpgate/main"

# Download docker-compose.yml jika belum ada di direktori
if [[ ! -f "${TARGET_DIR}/docker-compose.yml" ]]; then
    log_info "Mengunduh docker-compose.yml via curl..."
    curl -fsSL "${REPO_RAW_URL}/docker-compose.yml" -o "${TARGET_DIR}/docker-compose.yml"
    log_ok "docker-compose.yml berhasil disimpan."
fi

# Download konfigurasi data/warpgate.yaml template jika belum ada
if [[ ! -f "${TARGET_DIR}/data/warpgate.yaml" ]]; then
    log_info "Mengunduh template data/warpgate.yaml via curl..."
    curl -fsSL "${REPO_RAW_URL}/data/warpgate.yaml" -o "${TARGET_DIR}/data/warpgate.yaml" 2>/dev/null || true
fi

DATA_DIR="${TARGET_DIR}/data"
DB_FILE="${DATA_DIR}/db/db.sqlite3"
TLS_FILE="${DATA_DIR}/tls.certificate.pem"
CONFIG_FILE="${DATA_DIR}/warpgate.yaml"

# Inisialisasi database & TLS jika belum ada
if [[ ! -f "${DB_FILE}" || ! -f "${TLS_FILE}" ]]; then
    log_info "Menyiapkan database baru, TLS certificate, dan SSH keys..."

    if [[ -z "${ADMIN_PASSWORD}" ]]; then
        # Coba baca input dari terminal interaktif atau /dev/tty
        if [[ -t 0 ]]; then
            read -r -s -p "Masukkan password admin Warpgate yang diinginkan: " ADMIN_PASSWORD
            echo ""
        elif [[ -e /dev/tty ]]; then
            read -r -s -p "Masukkan password admin Warpgate yang diinginkan: " ADMIN_PASSWORD < /dev/tty
            echo ""
        fi

        # Jika masih kosong, buatkan random password yang aman
        if [[ -z "${ADMIN_PASSWORD}" ]]; then
            ADMIN_PASSWORD="$(tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 16 2>/dev/null || echo "WarpgatePass123!")"
            log_warn "Password tidak diberikan. Password otomatis dibuat: ${BOLD}${ADMIN_PASSWORD}${NC}"
        fi
    fi

    # Hapus file config sementara agar unattended-setup bekerja bersih
    rm -f "${CONFIG_FILE}"

    SETUP_ARGS=(
        unattended-setup
        --data-path /data
        --http-port 8888
        --ssh-port 2222
        --mysql-port 33306
        --postgres-port 55432
        --kubernetes-port 8443
        --record-sessions
        --admin-password "${ADMIN_PASSWORD}"
    )

    if [[ -n "${EXTERNAL_HOST}" ]]; then
        SETUP_ARGS+=(--external-host "${EXTERNAL_HOST}")
    fi

    log_info "Menjalankan inisialisasi Warpgate image ghcr.io/warp-tech/warpgate..."
    docker run --rm -v "${DATA_DIR}:/data:Z" ghcr.io/warp-tech/warpgate "${SETUP_ARGS[@]}"

    if [[ -f "${CONFIG_FILE}" ]]; then
        sed -i 's/trust_x_forwarded_headers: false/trust_x_forwarded_headers: true/' "${CONFIG_FILE}" || true
    fi
    log_ok "Inisialisasi Warpgate selesai!"
else
    log_ok "Database Warpgate sudah ada di ${DATA_DIR}."
    if [[ -n "${EXTERNAL_HOST}" && -f "${CONFIG_FILE}" ]]; then
        sed -i "s/^external_host:.*/external_host: ${EXTERNAL_HOST}/" "${CONFIG_FILE}"
        log_info "external_host diperbarui ke: ${EXTERNAL_HOST}"
    fi
fi

# Jalankan Warpgate Container
log_info "Menjalankan container Warpgate dengan Docker Compose..."
"${COMPOSE_CMD[@]}" up -d

# Deteksi IP Server
SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${SERVER_IP}" ]]; then
    SERVER_IP="<IP_SERVER_ANDA>"
fi

echo ""
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e "${GREEN}${BOLD}    INSTALASI & DEPLOYMENT WARPGATE BERHASIL!            ${NC}"
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e " Informasi Layanan:"
echo -e " - ${BOLD}Web Admin UI / Client${NC} : ${CYAN}https://${SERVER_IP}:8889${NC}"
echo -e " - ${BOLD}SSH Bastion Proxy    ${NC} : Port ${CYAN}2222${NC}"
echo -e " - ${BOLD}MySQL Proxy          ${NC} : Port ${CYAN}33306${NC}"
echo -e " - ${BOLD}PostgreSQL Proxy     ${NC} : Port ${CYAN}55432${NC}"
echo -e " - ${BOLD}Username Admin       ${NC} : ${YELLOW}admin${NC}"
if [[ -n "${ADMIN_PASSWORD}" ]]; then
echo -e " - ${BOLD}Password Admin       ${NC} : ${YELLOW}${ADMIN_PASSWORD}${NC}"
fi
echo -e " - ${BOLD}Direktori Data       ${NC} : ${TARGET_DIR}/data"
echo -e " - ${BOLD}Warpgate CLI Command ${NC} : ${CYAN}warpgate --help${NC}"
echo -e ""
echo -e " Status Container:"
"${COMPOSE_CMD[@]}" ps
echo -e "${GREEN}==========================================================${NC}"
