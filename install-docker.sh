#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script Universal Instalasi Docker & Docker Compose
# Mendukung berbagai distribusi Linux:
# - Amazon Linux 2 & Amazon Linux 2023 (AL3)
# - Ubuntu (18.04, 20.04, 22.04, 24.04, hingga versi terbaru)
# - Debian (10 Buster, 11 Bullseye, 12 Bookworm, dan terbaru)
# - RHEL (Red Hat Enterprise Linux 7, 8, 9)
# - AlmaLinux & Rocky Linux (8, 9)
# - Oracle Linux (OL 7, 8, 9)
# ==============================================================================

# 1. Pengecekan Privilege Root / Sudo
SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "[ERROR] Script ini membutuhkan hak akses root atau sudo."
        exit 1
    fi
fi

# 2. Target user non-root
TARGET_USER="${1:-${SUDO_USER:-$(logname 2>/dev/null || echo "${USER}")}}"

echo "=========================================================="
echo "      Universal Docker & Docker Compose Installer         "
echo "=========================================================="

# 3. Deteksi Distribusi & Arsitektur OS
if [[ ! -f /etc/os-release ]]; then
    echo "[ERROR] File /etc/os-release tidak ditemukan. Tidak dapat mendeteksi sistem operasi."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

OS_ID="${ID:-unknown}"
OS_ID_LIKE="${ID_LIKE:-}"
OS_VERSION_ID="${VERSION_ID:-}"
OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
ARCH="$(uname -m)"

echo "[INFO] Sistem Terdeteksi : ${PRETTY_NAME:-Linux}"
echo "[INFO] Distro ID         : ${OS_ID} (ID_LIKE: ${OS_ID_LIKE:-none})"
echo "[INFO] Versi             : ${OS_VERSION_ID:-unknown}"
echo "[INFO] Arsitektur        : ${ARCH}"
echo "=========================================================="
echo ""

# 4. Pengecekan apakah Docker sudah terpasang
echo "--- [1/4] Mengecek Instalasi Docker ---"
if command -v docker >/dev/null 2>&1; then
    echo "[OK] Docker sudah terinstall: $(docker --version)"
else
    echo "[INFO] Docker belum ditemukan. Memulai proses instalasi untuk ${OS_ID}..."

    case "${OS_ID}" in
        # ----------------------------------------------------------------------
        # Amazon Linux (AL2 & AL2023)
        # ----------------------------------------------------------------------
        amzn)
            if [[ "${OS_VERSION_ID}" == "2" ]]; then
                echo "[INFO] Menginstal Docker pada Amazon Linux 2..."
                ${SUDO} yum update -y
                if command -v amazon-linux-extras >/dev/null 2>&1; then
                    ${SUDO} amazon-linux-extras install -y docker
                else
                    ${SUDO} yum install -y docker
                fi
            else
                # Amazon Linux 2023 (AL3)
                echo "[INFO] Menginstal Docker pada Amazon Linux 2023..."
                ${SUDO} dnf update -y
                ${SUDO} dnf install -y docker
            fi
            ;;

        # ----------------------------------------------------------------------
        # Ubuntu (18.04, 20.04, 22.04, 24.04, latest)
        # ----------------------------------------------------------------------
        ubuntu)
            echo "[INFO] Menginstal Docker CE pada Ubuntu (${OS_CODENAME:-${OS_VERSION_ID}})..."
            export DEBIAN_FRONTEND=noninteractive
            ${SUDO} apt-get update -y
            ${SUDO} apt-get install -y ca-certificates curl gnupg lsb-release

            ${SUDO} install -m 0755 -d /etc/apt/keyrings
            if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
                ${SUDO} curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
                ${SUDO} chmod a+r /etc/apt/keyrings/docker.asc
            fi

            DPKG_ARCH="$(dpkg --print-architecture)"
            CODENAME="${OS_CODENAME}"
            [[ -z "${CODENAME}" ]] && CODENAME="$(lsb_release -cs)"

            echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
                ${SUDO} tee /etc/apt/sources.list.d/docker.list > /dev/null

            ${SUDO} apt-get update -y
            ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        # ----------------------------------------------------------------------
        # Debian (10 Buster, 11 Bullseye, 12 Bookworm, latest)
        # ----------------------------------------------------------------------
        debian)
            echo "[INFO] Menginstal Docker CE pada Debian (${OS_CODENAME:-${OS_VERSION_ID}})..."
            export DEBIAN_FRONTEND=noninteractive
            ${SUDO} apt-get update -y
            ${SUDO} apt-get install -y ca-certificates curl gnupg

            ${SUDO} install -m 0755 -d /etc/apt/keyrings
            if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
                ${SUDO} curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
                ${SUDO} chmod a+r /etc/apt/keyrings/docker.asc
            fi

            DPKG_ARCH="$(dpkg --print-architecture)"
            echo "deb [arch=${DPKG_ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${OS_CODENAME} stable" | \
                ${SUDO} tee /etc/apt/sources.list.d/docker.list > /dev/null

            ${SUDO} apt-get update -y
            ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        # ----------------------------------------------------------------------
        # AlmaLinux, Rocky Linux, CentOS
        # ----------------------------------------------------------------------
        almalinux|rocky|centos)
            echo "[INFO] Menginstal Docker CE pada ${OS_ID}..."
            PKG_MGR="dnf"
            command -v dnf >/dev/null 2>&1 || PKG_MGR="yum"

            ${SUDO} ${PKG_MGR} install -y yum-utils
            ${SUDO} ${PKG_MGR} config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            ${SUDO} ${PKG_MGR} install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        # ----------------------------------------------------------------------
        # Red Hat Enterprise Linux (RHEL)
        # ----------------------------------------------------------------------
        rhel)
            echo "[INFO] Menginstal Docker CE pada RHEL..."
            PKG_MGR="dnf"
            command -v dnf >/dev/null 2>&1 || PKG_MGR="yum"

            ${SUDO} ${PKG_MGR} install -y yum-utils
            ${SUDO} ${PKG_MGR} config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo 2>/dev/null || \
            ${SUDO} ${PKG_MGR} config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

            ${SUDO} ${PKG_MGR} install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;

        # ----------------------------------------------------------------------
        # Oracle Linux (OL 7, 8, 9)
        # ----------------------------------------------------------------------
        ol)
            echo "[INFO] Menginstal Docker pada Oracle Linux ${OS_VERSION_ID}..."
            MAJOR_VER="${OS_VERSION_ID%%.*}"
            if [[ "${MAJOR_VER}" -eq 7 ]]; then
                ${SUDO} yum-config-manager --enable ol7_addons || true
                ${SUDO} yum install -y docker-engine docker-cli || {
                    ${SUDO} yum install -y yum-utils
                    ${SUDO} yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    ${SUDO} yum install -y docker-ce docker-ce-cli containerd.io
                }
            else
                # OL 8 / 9
                PKG_MGR="dnf"
                command -v dnf >/dev/null 2>&1 || PKG_MGR="yum"
                ${SUDO} ${PKG_MGR} install -y yum-utils
                ${SUDO} ${PKG_MGR} config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                ${SUDO} ${PKG_MGR} install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            fi
            ;;

        # ----------------------------------------------------------------------
        # Fallback untuk distro turunan Debian / RHEL lainnya
        # ----------------------------------------------------------------------
        *)
            if [[ "${OS_ID_LIKE}" =~ (debian|ubuntu) ]]; then
                echo "[INFO] Distro turunan Debian/Ubuntu (${OS_ID}). Menggunakan installer get.docker.com..."
                curl -fsSL https://get.docker.com | ${SUDO} sh
            elif [[ "${OS_ID_LIKE}" =~ (rhel|fedora|centos) ]]; then
                echo "[INFO] Distro turunan RHEL/Fedora (${OS_ID}). Menggunakan installer get.docker.com..."
                curl -fsSL https://get.docker.com | ${SUDO} sh
            else
                echo "[WARN] Distro ${OS_ID} tidak terdaftar spesifik. Mencoba official script get.docker.com..."
                curl -fsSL https://get.docker.com | ${SUDO} sh
            fi
            ;;
    esac

    echo "[OK] Docker berhasil dipasang: $(docker --version)"
fi

echo ""
# 5. Memastikan Service Docker Aktif & Berjalan
echo "--- [2/4] Memastikan Service Docker Berjalan ---"
if ! systemctl is-active --quiet docker; then
    echo "[INFO] Menjalankan dan mengaktifkan service docker..."
    ${SUDO} systemctl enable --now docker
    echo "[OK] Service docker aktif dan berjalan."
else
    echo "[OK] Service docker sudah aktif."
    if ! systemctl is-enabled --quiet docker 2>/dev/null; then
        ${SUDO} systemctl enable docker >/dev/null 2>&1 || true
    fi
fi

echo ""
# 6. Konfigurasi Hak Akses Non-Root User (Docker Group & Permissions)
echo "--- [3/4] Konfigurasi Docker CLI Tanpa Sudo ---"
${SUDO} groupadd -f docker

USERS_TO_CONFIGURE=()
if [[ -n "${TARGET_USER}" && "${TARGET_USER}" != "root" ]] && id "${TARGET_USER}" >/dev/null 2>&1; then
    USERS_TO_CONFIGURE+=("${TARGET_USER}")
fi

# Cek user default yang umum di cloud provider (AWS, OCI, Azure, GCP)
for DEFAULT_USER in ec2-user opc ubuntu admin rocky alma centos; do
    if id "${DEFAULT_USER}" >/dev/null 2>&1; then
        already_in_list=false
        for u in "${USERS_TO_CONFIGURE[@]:-}"; do
            if [[ "${u}" == "${DEFAULT_USER}" ]]; then
                already_in_list=true
                break
            fi
        done
        if [[ "${already_in_list}" == false ]]; then
            USERS_TO_CONFIGURE+=("${DEFAULT_USER}")
        fi
    fi
done

# Pastikan permission socket Docker aman dan bisa diakses grup docker
if [[ -S /var/run/docker.sock ]]; then
    ${SUDO} chown root:docker /var/run/docker.sock
    ${SUDO} chmod 660 /var/run/docker.sock
fi

for usr in "${USERS_TO_CONFIGURE[@]:-}"; do
    [[ -z "${usr}" ]] && continue

    if id -nG "${usr}" | grep -qw "docker"; then
        echo "[OK] User '${usr}' sudah terdaftar di grup 'docker'."
    else
        echo "[INFO] Menambahkan user '${usr}' ke grup 'docker'..."
        ${SUDO} usermod -aG docker "${usr}"
        echo "[OK] User '${usr}' berhasil ditambahkan ke grup 'docker'."
    fi

    # Berikan hak akses ACL socket langsung (jika setfacl terpasang)
    if [[ -S /var/run/docker.sock ]] && command -v setfacl >/dev/null 2>&1; then
        ${SUDO} setfacl -m "u:${usr}:rw" /var/run/docker.sock || true
    fi

    # Rapikan permission folder konfigurasi docker user
    USER_HOME="$(getent passwd "${usr}" | cut -d: -f6)"
    if [[ -n "${USER_HOME}" && -d "${USER_HOME}/.docker" ]]; then
        ${SUDO} chown -R "${usr}:${usr}" "${USER_HOME}/.docker"
        ${SUDO} chmod -R g+rwx "${USER_HOME}/.docker" || true
    fi

    # Tes apakah user sudah bisa akses docker daemon
    if ${SUDO} su - "${usr}" -c "docker info" >/dev/null 2>&1; then
        echo "[OK] Verifikasi sukses: User '${usr}' bisa menjalankan 'docker' tanpa sudo!"
    else
        echo "[INFO] Jalankan 'newgrp docker' atau login ulang untuk mengaktifkan sesi grup user '${usr}'."
    fi
done

echo ""
# 7. Pengecekan & Instalasi Docker Compose V2
echo "--- [4/4] Mengecek Instalasi Docker Compose ---"
if docker compose version >/dev/null 2>&1; then
    echo "[OK] Docker Compose Plugin sudah terpasang: $(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1; then
    echo "[OK] Docker Compose standalone sudah terpasang: $(docker-compose --version)"
else
    echo "[INFO] Docker Compose belum ditemukan. Mengunduh Docker Compose V2..."

    ARCH_NAME="$(uname -m)"
    case "${ARCH_NAME}" in
        x86_64)  ARCH_NAME="x86_64" ;;
        aarch64|arm64) ARCH_NAME="aarch64" ;;
        armv7l)  ARCH_NAME="armv7" ;;
        *)       ARCH_NAME="x86_64" ;;
    esac

    COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH_NAME}"

    echo "[INFO] Mengunduh binary Docker Compose V2 (${ARCH_NAME})..."
    ${SUDO} mkdir -p /usr/local/lib/docker/cli-plugins /usr/libexec/docker/cli-plugins /usr/local/bin
    ${SUDO} curl -fsSL "${COMPOSE_URL}" -o /usr/local/lib/docker/cli-plugins/docker-compose
    ${SUDO} chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Symlink agar kompatibel dengan 'docker compose' dan 'docker-compose'
    ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
    ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

    echo "[OK] Docker Compose berhasil diinstal: $(docker compose version 2>/dev/null || docker-compose --version)"
fi

echo ""
echo "=========================================================="
echo " Instalasi & Konfigurasi Berhasil!"
echo " - Docker Version  : $(docker --version)"
if docker compose version >/dev/null 2>&1; then
    echo " - Docker Compose  : $(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1; then
    echo " - Docker Compose  : $(docker-compose --version)"
fi
echo "=========================================================="
