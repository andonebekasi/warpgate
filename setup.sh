#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
CONFIG_FILE="${DATA_DIR}/warpgate.yaml"

# Deteksi perintah docker compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD=(docker-compose)
else
    echo "[ERROR] Docker Compose tidak ditemukan. Pastikan Docker & Docker Compose sudah terinstall."
    exit 1
fi

usage() {
    cat <<EOF
Penggunaan: ./setup.sh [OPSI]

Opsi:
  --password <PASS>   Password awal untuk akun 'admin' (jika belum diinisialisasi)
  --host <HOSTNAME>   Set external_host (contoh: bastion.domain.com), default: kosong (null)
  --reset             Hapus seluruh database, rekaman sesi, SSH keys, dan sertifikat TLS (reset ke kondisi bersih)
  -h, --help          Tampilkan bantuan ini
EOF
}

ADMIN_PASSWORD="${WARPGATE_ADMIN_PASSWORD:-}"
EXTERNAL_HOST=""
DO_RESET=false

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
        --reset)
            DO_RESET=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "[ERROR] Opsi tidak dikenal: $1"
            usage
            exit 1
            ;;
    esac
done

cd "${SCRIPT_DIR}"

if [[ "${DO_RESET}" == true ]]; then
    echo "[INFO] Menghentikan container Warpgate (jika berjalan)..."
    "${COMPOSE_CMD[@]}" down 2>/dev/null || true

    echo "[INFO] Membersihkan database, rekaman sesi, SSH keys, dan sertifikat TLS..."
    rm -rf "${DATA_DIR}/db" \
           "${DATA_DIR}/data" \
           "${DATA_DIR}/recordings" \
           "${DATA_DIR}/ssh-keys" \
           "${DATA_DIR}/tls.certificate.pem" \
           "${DATA_DIR}/tls.key.pem" \
           "${DATA_DIR}"/warpgate.yaml-backup*

    if [[ -f "${CONFIG_FILE}" ]]; then
        sed -i 's/^external_host:.*/external_host: null/' "${CONFIG_FILE}"
    fi
    echo "[OK] Data Warpgate telah dibersihkan sepenuhnya."
    exit 0
fi

# Cek apakah database & sertifikat sudah terinisialisasi
if [[ ! -f "${DATA_DIR}/db/db.sqlite3" || ! -f "${DATA_DIR}/tls.certificate.pem" ]]; then
    echo "[INFO] Data belum terinisialisasi. Menjalankan setup awal Warpgate..."

    if [[ -z "${ADMIN_PASSWORD}" ]]; then
        read -r -s -p "Masukkan password awal untuk user 'admin': " ADMIN_PASSWORD
        echo ""
        if [[ -z "${ADMIN_PASSWORD}" ]]; then
            echo "[ERROR] Password admin tidak boleh kosong."
            exit 1
        fi
    fi

    mkdir -p "${DATA_DIR}"
    # Hapus warpgate.yaml sementara agar unattended-setup dapat membuat sertifikat, SSH keys, dan DB baru
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

    docker run --rm -v "${DATA_DIR}:/data:Z" ghcr.io/warp-tech/warpgate "${SETUP_ARGS[@]}"

    # Aktifkan trust_x_forwarded_headers seperti konfigurasi standar
    if [[ -f "${CONFIG_FILE}" ]]; then
        sed -i 's/trust_x_forwarded_headers: false/trust_x_forwarded_headers: true/' "${CONFIG_FILE}" || true
    fi

    echo "[OK] Inisialisasi selesai (DB baru, SSH keys baru, dan TLS cert baru berhasil dibuat)."
else
    echo "[INFO] Database dan sertifikat sudah tersedia di ${DATA_DIR}."
    if [[ -n "${EXTERNAL_HOST}" && -f "${CONFIG_FILE}" ]]; then
        sed -i "s/^external_host:.*/external_host: ${EXTERNAL_HOST}/" "${CONFIG_FILE}"
        echo "[INFO] external_host diperbarui menjadi: ${EXTERNAL_HOST}"
    fi
fi

echo "[INFO] Menjalankan container Warpgate..."
"${COMPOSE_CMD[@]}" up -d

echo ""
echo "=========================================================="
echo " Warpgate berhasil dijalankan!"
echo " - Web Admin UI : https://<IP-HOST>:8889"
echo " - SSH Bastion  : Port 2222"
echo " - MySQL Proxy  : Port 33306"
echo " - PG Proxy     : Port 55432"
echo "=========================================================="
