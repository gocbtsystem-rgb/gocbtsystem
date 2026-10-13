#!/bin/bash
# ============================================================
#  GoCBT Panel - Installer satu perintah
#
#  Penggunaan:
#    curl -fsSL https://raw.githubusercontent.com/gocbtsystem-rgb/gocbtsystem/main/install.sh | sudo bash
#
#  Bisa dijalankan ulang untuk update (binary + script di-refresh,
#  .env tidak dihapus).
# ============================================================
set -e

REPO="gocbtsystem-rgb/gocbtsystem"
INSTALL_DIR="/opt/gocbt-panel"
SERVICE="gocbt-panel"

# --- wajib root ---
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: jalankan sebagai root."
  echo "  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sudo bash"
  exit 1
fi

if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "OS: ${PRETTY_NAME:-tidak dikenal}"
fi
echo "== GoCBT Panel installer =="

mkdir -p "$INSTALL_DIR"

# --- [1/6] download panel binary ---
# (via file sementara + mv, agar aman walau binary lama sedang berjalan)
echo "[1/6] Mengunduh panel binary..."
curl -fsSL -o "$INSTALL_DIR/gocbt-panel.new" "https://raw.githubusercontent.com/$REPO/main/gocbt-panel-linux"
chmod +x "$INSTALL_DIR/gocbt-panel.new"
mv -f "$INSTALL_DIR/gocbt-panel.new" "$INSTALL_DIR/gocbt-panel"

# --- [2/6] download script build + Dockerfile ---
echo "[2/6] Mengunduh build-image.sh & Dockerfile..."
curl -fsSL -o "$INSTALL_DIR/build-image.sh" "https://raw.githubusercontent.com/$REPO/main/build-image.sh"
curl -fsSL -o "$INSTALL_DIR/Dockerfile" "https://raw.githubusercontent.com/$REPO/main/Dockerfile"
chmod +x "$INSTALL_DIR/build-image.sh"

# --- [3/6] download binary sekolah (release assets; opsional) ---
echo "[3/6] Mengunduh binary sekolah..."
for f in gocbt_linux gocbt-install; do
  if curl -fsSL -o "$INSTALL_DIR/$f" "https://github.com/$REPO/releases/latest/download/$f"; then
    chmod +x "$INSTALL_DIR/$f"
    echo "      OK: $f"
  else
    rm -f "$INSTALL_DIR/$f"
    echo "      LEWATI: $f tidak ada di Release."
    echo "      Copy manual ke $INSTALL_DIR/ bila butuh fitur Build:"
    echo "        scp $f root@IP-VPS:$INSTALL_DIR/"
  fi
done

# --- [4/6] .env (jangan timpa bila sudah ada) ---
if [ ! -f "$INSTALL_DIR/.env" ]; then
  echo "[4/6] Membuat .env dengan kredensial acak..."
  ADMIN_PASS="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)"
  SESSION_SECRET="$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 48)"
  cat > "$INSTALL_DIR/.env" <<EOF
PANEL_PORT=9000
PANEL_USER=admin
PANEL_PASS=$ADMIN_PASS
SESSION_SECRET=$SESSION_SECRET
PANEL_BASE_DIR=$INSTALL_DIR
EOF
  chmod 600 "$INSTALL_DIR/.env"
  echo "      OK"
else
  echo "[4/6] .env sudah ada, dilewati (kredensial lama dipertahankan)."
fi

# --- [5/6] systemd service ---
echo "[5/6] Memasang systemd service..."
cat > "/etc/systemd/system/$SERVICE.service" <<EOF
[Unit]
Description=GoCBT Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/gocbt-panel
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null 2>&1 || true
systemctl restart "$SERVICE"
echo "      OK"

# --- [6/6] tunggu service ---
echo "[6/6] Menunggu service..."
sleep 3
if ! systemctl is-active --quiet "$SERVICE"; then
  echo "ERROR: service gagal berjalan."
  echo "Cek log: journalctl -u $SERVICE -n 50 --no-pager"
  exit 1
fi

# --- ringkasan ---
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -z "$IP" ] && IP="IP-SERVER"
PASS="$(grep '^PANEL_PASS=' "$INSTALL_DIR/.env" | cut -d= -f2)"
echo ""
echo "=============================================="
echo " GoCBT Panel terinstal & berjalan!"
echo ""
echo "  URL      : http://$IP:9000"
echo "  Username : admin"
echo "  Password : $PASS"
echo ""
echo "  Segera ganti password setelah login pertama."
echo "=============================================="
