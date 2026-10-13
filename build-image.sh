#!/bin/bash
# Script Build Docker Image GoCBT
# Pemakaian: ./build-image.sh [tag] [--sync-tenants|--no-sync]
#   --sync-tenants : setelah build, langsung sinkronkan semua tenant
#                    (patch compose + recreate, tanpa konfirmasi)
#   --no-sync      : jangan sinkronkan (tanpa konfirmasi)
#   tanpa flag     : tanya konfirmasi dulu (default: tidak)
TAG="latest"
SYNC_MODE="ask"
for arg in "$@"; do
  case "$arg" in
    --sync-tenants) SYNC_MODE="yes" ;;
    --no-sync)      SYNC_MODE="no" ;;
    *)              TAG="$arg" ;;
  esac
done
MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$MASTER_DIR" || exit 1

if [ ! -f "$MASTER_DIR/gocbt_linux" ]; then
    echo "❌ Error: File binary '$MASTER_DIR/gocbt_linux' tidak ditemukan!"
    exit 1
fi

if [ ! -f "$MASTER_DIR/Dockerfile" ]; then
    echo "❌ Error: File '$MASTER_DIR/Dockerfile' tidak ditemukan!"
    exit 1
fi

if [ ! -f "$MASTER_DIR/gocbt-install" ]; then
    echo "❌ Error: File binary '$MASTER_DIR/gocbt-install' tidak ditemukan!"
    echo "   Copy dari hasil build.bat (backend/gocbt-install) ke folder ini,"
    echo "   lalu jalankan ulang script ini."
    exit 1
fi

echo "=========================================="
echo "🔨 Memulai Build Docker Image GoCBT ($TAG)..."
echo "=========================================="

if [ "$TAG" != "latest" ]; then
    docker build -t gocbt:latest -t gocbt:$TAG .
else
    docker build -t gocbt:latest .
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Image gocbt:latest berhasil di-build!"
    docker images gocbt:latest --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
else
    echo "❌ Gagal build image Docker."
    exit 1
fi

# --- Integrasi sinkron tenant: patch compose + recreate agar tenant lama
# memakai image baru sekaligus mount license.key (via sync-license.sh). ---
if [ -x "$MASTER_DIR/sync-license.sh" ]; then
    do_sync=false
    case "$SYNC_MODE" in
        yes) do_sync=true ;;
        no)  do_sync=false ;;
        ask)
            echo ""
            read -r -p "Sinkronkan tenant yang ada ke image & mount lisensi baru? [y/N] " ans
            case "$ans" in [yY]*) do_sync=true ;; esac
            ;;
    esac
    if [ "$do_sync" = true ]; then
        echo ""
        "$MASTER_DIR/sync-license.sh"
    else
        echo ""
        echo "ℹ️  Sinkron tenant dilewati. Jalankan manual bila perlu: ./sync-license.sh"
        echo "   (atau ./build-image.sh --sync-tenants untuk langsung sinkron)"
    fi
fi

