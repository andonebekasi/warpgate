#!/usr/bin/env bash
# ==============================================================================
# Script Otomatisasi Warpgate:
# 1. Deteksi Sistem Operasi (OS) & Arsitektur
# 2. Pengujian Docker & Docker Compose
# 3. Instalasi otomatis Docker & Compose jika belum ada
# 4. Konfigurasi permission user non-root (akses docker tanpa sudo)
# 5. Inisialisasi dan Menjalankan Warpgate
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
CONFIG_FILE="${DATA_DIR}/warpgate.yaml"

# Warna Output
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
echo -e "${BOLD}   Warpgate Deployer & Environment Validator              ${NC}"
echo -e "${BOLD}==========================================================${NC}"

# 1. Target user non-root
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "${USER}")}"
SUDO=""

ensure_sudo() {
    if [[ -z "${SUDO}" && "${EUID}" -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
        else
            log_error "Script ini membutuhkan hak akses root atau sudo."
            exit 1
        fi
    fi
}

# Parsing Argumen
ADMIN_PASSWORD="${WARPGATE_ADMIN_PASSWORD:-}"
EXTERNAL_HOST=""
SKIP_RUN=false

usage() {
    cat <<EOF
Penggunaan: $0 [OPSI]

Opsi:
  --password <PASS>   Password awal untuk akun 'admin' Warpgate
  --host <HOSTNAME>   Domain / Public IP untuk external_host Warpgate
  --skip-run          Hanya lakukan test OS & install Docker, tanpa menjalankan Warpgate
  -h, --help          Tampilkan bantuan ini
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
        --skip-run)
            SKIP_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Opsi tidak dikenal: $1"
            usage
            exit 1
            ;;
    esac
done

# ==============================================================================
# TAHAP 1: TEST SISTEM OPERASI (OS) & ARSITEKTUR
# ==============================================================================
log_info "Memeriksa Sistem Operasi dan Arsitektur..."

if [[ ! -f /etc/os-release ]]; then
    log_error "File /etc/os-release tidak ditemukan. Tidak dapat mendeteksi sistem operasi."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

OS_ID="${ID:-unknown}"
OS_ID_LIKE="${ID_LIKE:-}"
OS_NAME="${PRETTY_NAME:-Linux}"
OS_VERSION_ID="${VERSION_ID:-}"
OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
RAW_ARCH="$(uname -m)"

case "${RAW_ARCH}" in
    x86_64|amd64)
        DOCKER_ARCH="x86_64"
        DEB_ARCH="amd64"
        ;;
    aarch64|arm64)
        DOCKER_ARCH="aarch64"
        DEB_ARCH="arm64"
        ;;
    *)
        log_error "Arsitektur ${RAW_ARCH} saat ini belum didukung skrip ini."
        exit 1
        ;;
esac

log_ok "OS Terdeteksi : ${OS_NAME} (${OS_ID} ${OS_VERSION_ID})"
log_ok "Arsitektur    : ${RAW_ARCH} (${DOCKER_ARCH})"
log_ok "Target User   : ${TARGET_USER}"

# ==============================================================================
# FUNGSI INSTALASI DOCKER OTOMATIS BERDASARKAN OS
# ==============================================================================
install_docker_engine() {
    log_info "Memulai instalasi Docker Engine untuk ${OS_NAME}..."

    case "${OS_ID}" in
        amzn)
            if [[ "${OS_VERSION_ID}" =~ ^2023 ]]; then
                log_info "Menginstall Docker di Amazon Linux 2023 via dnf..."
                ${SUDO} dnf update -y
                ${SUDO} dnf install -y docker libxcrypt-compat iptables
            elif [[ "${OS_VERSION_ID}" =~ ^2 ]]; then
                log_info "Menginstall Docker di Amazon Linux 2 via amazon-linux-extras..."
                ${SUDO} yum update -y
                ${SUDO} amazon-linux-extras install docker -y || ${SUDO} yum install -y docker
            else
                ${SUDO} dnf install -y docker || ${SUDO} yum install -y docker
            fi
            ;;

        ubuntu|debian)
            log_info "Menginstall Docker di Debian/Ubuntu via APT repository resmi..."
            ${SUDO} apt-get update -y
            ${SUDO} apt-get install -y ca-certificates curl gnupg lsb-release acl
            ${SUDO} install -m 0755 -d /etc/apt/keyrings
            if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
                curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | ${SUDO} gpg --dearmor -o /etc/apt/keyrings/docker.gpg
                ${SUDO} chmod a+r /etc/apt/keyrings/docker.gpg
            fi
            echo "deb [arch=${DEB_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} ${OS_CODENAME:-$(lsb_release -cs)} stable" | \
                ${SUDO} tee /etc/apt/sources.list.d/docker.list > /dev/null
            ${SUDO} apt-get update -y
            ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        rhel|centos|rocky|almalinux|ol)
            log_info "Menginstall Docker di RHEL / Enterprise Linux family..."
            PKG_MGR="yum"
            command -v dnf >/dev/null 2>&1 && PKG_MGR="dnf"
            ${SUDO} ${PKG_MGR} install -y yum-utils device-mapper-persistent-data lvm2 acl || true
            ${SUDO} ${PKG_MGR} config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
            ${SUDO} ${PKG_MGR} install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin --nobest || \
            ${SUDO} ${PKG_MGR} install -y docker || true
            ;;

        *)
            # Fallback jika OS turunan Debian / RedHat atau distro lain
            if [[ "${OS_ID_LIKE}" =~ (ubuntu|debian) ]]; then
                log_info "Distro berbasis Debian terdeteksi via ID_LIKE..."
                ${SUDO} apt-get update -y && ${SUDO} apt-get install -y docker.io docker-compose
            elif [[ "${OS_ID_LIKE}" =~ (rhel|fedora|centos) ]]; then
                log_info "Distro berbasis RHEL terdeteksi via ID_LIKE..."
                ${SUDO} dnf install -y docker || ${SUDO} yum install -y docker
            else
                log_warn "Mencoba instalasi via official get.docker.com script..."
                curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
                ${SUDO} sh /tmp/get-docker.sh
                rm -f /tmp/get-docker.sh
            fi
            ;;
    esac

    # Nyalakan service Docker
    log_info "Mengaktifkan dan menjalankan service Docker daemon..."
    ${SUDO} systemctl enable --now docker || true
    ${SUDO} systemctl start docker || true
    log_ok "Instalasi Docker Engine selesai."
}

# ==============================================================================
# FUNGSI INSTALASI DOCKER COMPOSE STANDALONE / PLUGIN
# ==============================================================================
install_docker_compose() {
    log_info "Memeriksa dan memasang Docker Compose..."
    local COMPOSE_VERSION="v2.30.3"
    local DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${DOCKER_ARCH}"

    log_info "Mengunduh Docker Compose ${COMPOSE_VERSION} (${DOCKER_ARCH})..."
    ${SUDO} mkdir -p /usr/local/lib/docker/cli-plugins
    ${SUDO} curl -sSL "${DOWNLOAD_URL}" -o /usr/local/lib/docker/cli-plugins/docker-compose
    ${SUDO} chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Buat symlink juga ke /usr/local/bin/docker-compose agar kompatibel
    ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose 2>/dev/null || true
    ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/bin/docker-compose 2>/dev/null || true
    log_ok "Docker Compose berhasil dipasang."
}

# ==============================================================================
# TAHAP 2: TEST DOCKER & DOCKER COMPOSE
# ==============================================================================
NEED_DOCKER=false
NEED_COMPOSE=false

if ! command -v docker >/dev/null 2>&1; then
    log_warn "Docker belum terpasang di sistem ini."
    NEED_DOCKER=true
else
    DOCKER_VER="$(docker --version 2>/dev/null || true)"
    log_ok "Docker sudah terinstall: ${DOCKER_VER}"
fi

# Deteksi Docker Compose
COMPOSE_CMD=()
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
    log_ok "Docker Compose (Plugin) terdeteksi: $(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1 && docker-compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
    log_ok "Docker Compose (Standalone) terdeteksi: $(docker-compose version)"
else
    log_warn "Docker Compose belum terpasang."
    NEED_COMPOSE=true
fi

# ==============================================================================
# TAHAP 3: EKSEKUSI INSTALASI JIKA DIPERLUKAN
# ==============================================================================
if [[ "${NEED_DOCKER}" == true ]]; then
    ensure_sudo
    install_docker_engine
fi

if [[ "${NEED_COMPOSE}" == true ]]; then
    ensure_sudo
    install_docker_compose
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD=(docker compose)
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD=(docker-compose)
    fi
fi

# ==============================================================================
# TAHAP 4: KONFIGURASI AKSES USER NON-ROOT KE DOCKER (JIKA BELUM BISA AKSES)
# ==============================================================================
if ! docker info >/dev/null 2>&1; then
    log_info "Mengonfigurasi hak akses Docker daemon untuk user '${TARGET_USER}'..."
    ensure_sudo

    ${SUDO} groupadd -f docker || true
    if id -u "${TARGET_USER}" >/dev/null 2>&1; then
        ${SUDO} usermod -aG docker "${TARGET_USER}" || true
        
        # Atur ACL socket agar tidak perlu logout/login
        if [[ -S /var/run/docker.sock ]]; then
            ${SUDO} chmod 660 /var/run/docker.sock || true
            ${SUDO} chown root:docker /var/run/docker.sock || true
            if command -v setfacl >/dev/null 2>&1; then
                ${SUDO} setfacl -m u:"${TARGET_USER}":rw /var/run/docker.sock 2>/dev/null || true
            fi
        fi
    fi

    # Pastikan service docker benar-benar hidup
    if ! ${SUDO} systemctl is-active --quiet docker 2>/dev/null; then
        log_info "Menjalankan service Docker daemon..."
        ${SUDO} systemctl restart docker || true
        sleep 2
    fi
fi

# Uji apakah docker info bisa diakses
if docker info >/dev/null 2>&1; then
    log_ok "Docker daemon berjalan normal dan siap digunakan (tanpa sudo)!"
elif [[ -n "${SUDO}" ]] && ${SUDO} docker info >/dev/null 2>&1; then
    log_warn "Docker daemon berjalan dengan sudo (re-login mungkin diperlukan untuk user non-root)."
else
    log_error "Docker daemon gagal merespons. Periksa status via: systemctl status docker"
    exit 1
fi

if [[ "${SKIP_RUN}" == true ]]; then
    log_ok "Mode --skip-run aktif. Pengujian OS & instalasi Docker selesai!"
    exit 0
fi

# ==============================================================================
# TAHAP 5: INISIALISASI DAN MENJALANKAN WARPGATE
# ==============================================================================
echo ""
echo -e "${BOLD}==========================================================${NC}"
echo -e "${BOLD}   Menyiapkan dan Menjalankan Warpgate Bastion            ${NC}"
echo -e "${BOLD}==========================================================${NC}"

cd "${SCRIPT_DIR}"
mkdir -p "${DATA_DIR}"

# Cek apakah database dan sertifikat TLS sudah tersedia
DB_FILE="${DATA_DIR}/db/db.sqlite3"
TLS_FILE="${DATA_DIR}/tls.certificate.pem"

if [[ ! -f "${DB_FILE}" || ! -f "${TLS_FILE}" ]]; then
    log_info "Data Warpgate belum terinisialisasi. Menjalankan setup awal otomatis..."

    if [[ -z "${ADMIN_PASSWORD}" ]]; then
        if [[ -t 0 ]]; then
            read -r -s -p "Masukkan password awal untuk user 'admin' Warpgate: " ADMIN_PASSWORD
            echo ""
        fi
        if [[ -z "${ADMIN_PASSWORD}" ]]; then
            ADMIN_PASSWORD="WarpgatePassword123!"
            log_warn "Password kosong, menggunakan default temporary: ${ADMIN_PASSWORD}"
        fi
    fi

    # Bersihkan file config kosong agar unattended-setup bekerja bersih
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

    log_info "Mengunduh image dan melakukan inisialisasi Warpgate..."
    docker run --rm -v "${DATA_DIR}:/data:Z" ghcr.io/warp-tech/warpgate "${SETUP_ARGS[@]}"

    if [[ -f "${CONFIG_FILE}" ]]; then
        sed -i 's/trust_x_forwarded_headers: false/trust_x_forwarded_headers: true/' "${CONFIG_FILE}" || true
    fi
    log_ok "Inisialisasi database, SSH keys, dan TLS certificate Warpgate berhasil!"
else
    log_ok "Database dan TLS Warpgate sudah ada di ${DATA_DIR}. Melewati initial setup."
    if [[ -n "${EXTERNAL_HOST}" && -f "${CONFIG_FILE}" ]]; then
        sed -i "s/^external_host:.*/external_host: ${EXTERNAL_HOST}/" "${CONFIG_FILE}"
        log_info "external_host diperbarui menjadi: ${EXTERNAL_HOST}"
    fi
fi

# Jalankan Warpgate melalui Docker Compose
log_info "Menjalankan container Warpgate dengan Docker Compose..."
"${COMPOSE_CMD[@]}" up -d

# Deteksi IP Server
SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [[ -z "${SERVER_IP}" ]]; then
    SERVER_IP="<IP-SERVER-ANDA>"
fi

echo ""
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e "${GREEN}${BOLD}   WARPGATE BERHASIL DIJALANKAN DENGAN SUKSES!            ${NC}"
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e " Endpoint Akses Warpgate:"
echo -e " - ${BOLD}Web Admin UI / Client${NC} : ${CYAN}https://${SERVER_IP}:8889${NC}"
echo -e " - ${BOLD}SSH Bastion Proxy    ${NC} : Port ${CYAN}2222${NC}"
echo -e " - ${BOLD}MySQL Proxy          ${NC} : Port ${CYAN}33306${NC}"
echo -e " - ${BOLD}PostgreSQL Proxy     ${NC} : Port ${CYAN}55432${NC}"
echo -e " - ${BOLD}User Login Admin     ${NC} : ${YELLOW}admin${NC}"
echo -e " - ${BOLD}Status Container     ${NC} :"
"${COMPOSE_CMD[@]}" ps
echo -e "${GREEN}==========================================================${NC}"
