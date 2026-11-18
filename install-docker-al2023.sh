#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script Instalasi Docker & Docker Compose untuk Amazon Linux 2023 (AL2023)
# Mengecek keberadaan Docker & Docker Compose terlebih dahulu sebelum menginstal
# ==============================================================================

# Gunakan sudo jika tidak dijalankan sebagai root
SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        echo "[ERROR] Script ini membutuhkan akses root atau sudo."
        exit 1
    fi
fi

# Deteksi user non-root (bisa juga dikirim lewat argumen pertama: ./install-docker-al2023.sh nama_user)
TARGET_USER="${1:-${SUDO_USER:-$(logname 2>/dev/null || echo "${USER}")}}"

echo "=========================================================="
echo " Pengecekan Sistem & Instalasi Docker (Amazon Linux 2023)"
echo "=========================================================="

# 1. Validasi OS (Opsional peringatan jika bukan Amazon Linux 2023)
if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "[INFO] OS Terdeteksi: ${PRETTY_NAME:-Unknown}"
    if [[ "${ID:-}" != "amzn" ]]; then
        echo "[WARN] OS bukan Amazon Linux (ID=${ID:-unknown}). Script tetap dilanjutkan..."
    fi
fi

echo ""
echo "--- [1/4] Mengecek Instalasi Docker ---"
if command -v docker >/dev/null 2>&1; then
    DOCKER_VER="$(docker --version)"
    echo "[OK] Docker sudah terinstall: ${DOCKER_VER}"
else
    echo "[INFO] Docker belum ditemukan. Menginstal Docker melalui dnf..."
    ${SUDO} dnf update -y
    ${SUDO} dnf install -y docker
    echo "[OK] Docker berhasil diinstal: $(docker --version)"
fi

echo ""
echo "--- [2/4] Memastikan Service Docker Berjalan ---"
if ! systemctl is-active --quiet docker; then
    echo "[INFO] Menjalankan dan mengaktifkan service docker..."
    ${SUDO} systemctl enable --now docker
    echo "[OK] Service docker aktif dan berjalan."
else
    echo "[OK] Service docker sudah berjalan."
    ${SUDO} systemctl enable docker >/dev/null 2>&1 || true
fi

echo ""
echo "--- [3/4] Konfigurasi Docker CLI Tanpa Sudo (Non-Root Access) ---"
# Pastikan grup 'docker' tersedia di sistem
${SUDO} groupadd -f docker

# Kumpulkan daftar user non-root yang perlu diberi akses docker tanpa sudo
USERS_TO_CONFIGURE=()
if [[ -n "${TARGET_USER}" && "${TARGET_USER}" != "root" ]] && id "${TARGET_USER}" >/dev/null 2>&1; then
    USERS_TO_CONFIGURE+=("${TARGET_USER}")
fi

# Jika dijalankan langsung sebagai root (misal setelah 'sudo su -'), otomatis cek default user cloud (ec2-user, opc, ubuntu, centos)
for DEFAULT_USER in ec2-user opc ubuntu admin; do
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

# Pastikan kepemilikan dan permission socket Docker benar
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

    # Set ACL pada /var/run/docker.sock agar user langsung bisa menjalankan 'docker'
    # tanpa sudo di sesi terminal saat ini (tanpa wajib logout/login ulang terlebih dahulu)
    if [[ -S /var/run/docker.sock ]] && command -v setfacl >/dev/null 2>&1; then
        ${SUDO} setfacl -m "u:${usr}:rw" /var/run/docker.sock || true
    fi

    # Perbaiki permission folder ~/.docker jika sebelumnya pernah dibuat dengan sudo
    USER_HOME="$(getent passwd "${usr}" | cut -d: -f6)"
    if [[ -n "${USER_HOME}" && -d "${USER_HOME}/.docker" ]]; then
        ${SUDO} chown -R "${usr}:${usr}" "${USER_HOME}/.docker"
        ${SUDO} chmod -R g+rwx "${USER_HOME}/.docker" || true
    fi

    # Verifikasi apakah user sudah bisa mengakses docker daemon tanpa sudo
    if ${SUDO} su - "${usr}" -c "docker info" >/dev/null 2>&1; then
        echo "[OK] Verifikasi sukses: User '${usr}' sudah bisa menjalankan 'docker' CLI tanpa sudo!"
    else
        echo "[INFO] Jalankan perintah 'newgrp docker' atau login ulang untuk mengaktifkan sesi grup pada user '${usr}'."
    fi
done

echo ""
echo "--- [4/4] Mengecek Instalasi Docker Compose ---"
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VER="$(docker compose version)"
    echo "[OK] Docker Compose Plugin sudah terinstall: ${COMPOSE_VER}"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VER="$(docker-compose --version)"
    echo "[OK] Docker Compose standalone sudah terinstall: ${COMPOSE_VER}"
else
    echo "[INFO] Docker Compose belum ditemukan. Menginstal Docker Compose V2..."

    # Coba via dnf terlebih dahulu jika paket docker-compose-plugin tersedia di repo
    if ${SUDO} dnf list available docker-compose-plugin >/dev/null 2>&1; then
        ${SUDO} dnf install -y docker-compose-plugin
    else
        # Unduh binary resmi Docker Compose V2 sesuai arsitektur (x86_64 / aarch64)
        ARCH="$(uname -m)"
        COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${ARCH}"

        echo "[INFO] Mengunduh Docker Compose V2 untuk arsitektur ${ARCH}..."
        ${SUDO} mkdir -p /usr/local/lib/docker/cli-plugins /usr/libexec/docker/cli-plugins
        ${SUDO} curl -fsSL "${COMPOSE_URL}" -o /usr/local/lib/docker/cli-plugins/docker-compose
        ${SUDO} chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

        # Buat symlink agar 'docker compose' dan 'docker-compose' keduanya bisa digunakan
        ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
        ${SUDO} ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
    fi

    echo "[OK] Docker Compose berhasil diinstal: $(docker compose version)"
fi

echo ""
echo "=========================================================="
echo " Selesai! Status Akhir:"
echo " - Docker         : $(docker --version)"
if docker compose version >/dev/null 2>&1; then
    echo " - Docker Compose : $(docker compose version)"
elif command -v docker-compose >/dev/null 2>&1; then
    echo " - Docker Compose : $(docker-compose --version)"
fi
echo "=========================================================="
