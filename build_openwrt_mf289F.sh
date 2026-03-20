#!/bin/bash
set -Eeuo pipefail
trap 'echo "[X] Errore alla riga $LINENO. Uscita."; exit 1' ERR

# 🔧 CONFIGURAZIONE
VERSION="24.10.5"
TARGET="ipq40xx"
SUBTARGET="generic"
PROFILE="zte_mf289f"

BASE_URL="https://downloads.openwrt.org"
ARCHIVE_NAME="openwrt-imagebuilder-${VERSION}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.zst"
ARCHIVE_URL="${BASE_URL}/releases/${VERSION}/targets/${TARGET}/${SUBTARGET}/${ARCHIVE_NAME}"

PACKAGES="luci luci-proto-qmi luci-proto-modemmanager luci-proto-wireguard \
wireguard-tools kmod-usb-serial-option kmod-usb-serial kmod-usb-serial-wwan \
usb-modeswitch kmod-mii kmod-usb-net kmod-usb-wdm kmod-usb-net-qmi-wwan \
uqmi kmod-usb-net-cdc-mbim modemmanager umbim kmod-usb-net-cdc-mbim luci-proto-mbim"

# 📦 Verifica tool richiesti
for t in wget tar make unzstd sha256sum; do
  command -v "$t" >/dev/null || { echo "[!] Tool mancante: $t. Installa con: sudo apt install $t"; exit 1; }
done

echo "==> OpenWrt ${VERSION} | Target: ${TARGET}/${SUBTARGET} | Profilo: ${PROFILE}"
echo "==> Scarico ImageBuilder da: $ARCHIVE_URL"

# ✅ Scarico ImageBuilder se non presente
[[ -f "$ARCHIVE_NAME" && -s "$ARCHIVE_NAME" ]] || wget --show-progress "$ARCHIVE_URL" -O "$ARCHIVE_NAME"

# 📦 Estrazione
tar --use-compress-program=unzstd -xf "$ARCHIVE_NAME"

# 📁 Rileva cartella estratta
FOLDER_NAME=$(find . -maxdepth 1 -type d -name "openwrt-imagebuilder-${VERSION}-*${TARGET}*${SUBTARGET}*" | head -n1)
[[ -d "$FOLDER_NAME" ]] || { echo "[X] Cartella ImageBuilder non trovata."; exit 1; }
echo "[✓] Cartella trovata: $FOLDER_NAME"

# 🔍 Recupero automatico hash kmods
KMOD_HASH=$(wget -qO- "${BASE_URL}/releases/${VERSION}/targets/${TARGET}/${SUBTARGET}/kmods/" \
  | grep -oE '6\.6\.[0-9]+-1-[a-f0-9]{32}' | head -n1)
[[ -n "$KMOD_HASH" ]] || { echo "[X] Impossibile recuperare il kernel hash."; exit 1; }
echo "[✓] Kernel modules hash per ImageBuilder: $KMOD_HASH"

# 📄 Sovrascrivo repositories.conf con feed ufficiali
REPO_CONF="$FOLDER_NAME/repositories.conf"
cat > "$REPO_CONF" <<EOF
src/gz openwrt_core https://downloads.openwrt.org/releases/${VERSION}/targets/${TARGET}/${SUBTARGET}/packages
src/gz openwrt_base https://downloads.openwrt.org/releases/${VERSION}/packages/arm_cortex-a7_neon-vfpv4/base
src/gz openwrt_kmods https://downloads.openwrt.org/releases/${VERSION}/targets/${TARGET}/${SUBTARGET}/kmods/${KMOD_HASH}
src/gz openwrt_luci https://downloads.openwrt.org/releases/${VERSION}/packages/arm_cortex-a7_neon-vfpv4/luci
src/gz openwrt_packages https://downloads.openwrt.org/releases/${VERSION}/packages/arm_cortex-a7_neon-vfpv4/packages
src/gz openwrt_routing https://downloads.openwrt.org/releases/${VERSION}/packages/arm_cortex-a7_neon-vfpv4/routing
src/gz openwrt_telephony https://downloads.openwrt.org/releases/${VERSION}/packages/arm_cortex-a7_neon-vfpv4/telephony
src imagebuilder file:packages
option check_signature
EOF

# 🔗 Aggiungo custom feeds (solo registrazione, non download)
CUSTOMFEEDS="$FOLDER_NAME/files/etc/opkg/customfeeds.conf"
mkdir -p "$(dirname "$CUSTOMFEEDS")"
touch "$CUSTOMFEEDS"
grep -q cristian_repo "$CUSTOMFEEDS" || \
echo 'src/gz cristian_repo https://ilblogdicristiangallo.github.io/ilblogdicristiangallo_repo_openwrt' >> "$CUSTOMFEEDS"
grep -q IceG_repo "$CUSTOMFEEDS" || \
echo 'src/gz IceG_repo https://github.com/4IceG/Modem-extras/raw/main/myrepo' >> "$CUSTOMFEEDS"

# 🔐 Integro chiavi pubbliche con emoji 🎉
KEYS_DIR="$FOLDER_NAME/keys"
OPKG_KEYS_DIR="$FOLDER_NAME/files/etc/opkg/keys"
UCI_DEFAULTS_DIR="$FOLDER_NAME/files/etc/uci-defaults"
mkdir -p "$OPKG_KEYS_DIR" "$UCI_DEFAULTS_DIR"

if [[ -d "$KEYS_DIR" ]]; then
  shopt -s nullglob
  for keyfile in "$KEYS_DIR"/*.pub; do
    [[ -f "$keyfile" ]] || continue
    keyname=$(basename "$keyfile")
    cp -f "$keyfile" "$OPKG_KEYS_DIR/$keyname"
    
    # Creo script per aggiungere la chiave al primo avvio
    DEFAULTS_SCRIPT="$UCI_DEFAULTS_DIR/99-add-${keyname// /_}"
    cat > "$DEFAULTS_SCRIPT" <<EOF
#!/bin/sh
echo "🔑 Aggiungo chiave: $keyname"
opkg-key add /etc/opkg/keys/$keyname
exit 0
EOF
    chmod +x "$DEFAULTS_SCRIPT"
    echo "[✓] Chiave $keyname copiata e script UCI-defaults creato 🎉"
  done

  # Aggiorno manualmente anche le due chiavi principali
  for mainkey in ilblogdicristiangallo.pub IceG-repo.pub; do
    if [[ -f "$OPKG_KEYS_DIR/$mainkey" ]]; then
      echo "🔑 Aggiungo chiave principale $mainkey direttamente..."
      cat > "$UCI_DEFAULTS_DIR/99-add-$mainkey" <<EOF
#!/bin/sh
opkg-key add /etc/opkg/keys/$mainkey
exit 0
EOF
      chmod +x "$UCI_DEFAULTS_DIR/99-add-$mainkey"
    fi
  done

  shopt -u nullglob
else
  echo "[!] Cartella keys non trovata, nessuna chiave copiata ⚠️"
fi


# 📦 Verifica pacchetti locali
echo "==> Verifico pacchetti .ipk in _local_packages/"
mkdir -p _local_packages
for base in luci-app-modemband luci-app-sms-tool-js luci-app-3ginfo-lite luci-app-atcommands; do
  match=$(find _local_packages/ -maxdepth 1 -type f -name "${base}*.ipk" | head -n1)
  [[ -n "$match" && -s "$match" ]] || { echo "[X] Pacchetto mancante o vuoto: ${base}"; exit 1; }
done

# 📦 Copia pacchetti locali in files/root e aggiorna PACKAGES
mkdir -p "$FOLDER_NAME/files/root"
for base in luci-app-modemband luci-app-sms-tool-js luci-app-3ginfo-lite luci-app-atcommands; do
  ipk=$(find _local_packages/ -maxdepth 1 -type f -name "${base}*.ipk" | head -n1)
  cp -f "$ipk" "$FOLDER_NAME/files/root/"
  PACKAGES="$PACKAGES $base"
done
echo "[✓] Pacchetti locali copiati e aggiunti alla build"

# 🌐 Configurazioni originali di rete, firewall, wireless e nlbwmon
mkdir -p "$FOLDER_NAME/files/etc/config"

cat > "$FOLDER_NAME/files/etc/config/network" << 'EOF'
config interface 'loopback'
    option device 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

config globals 'globals'
    option ula_prefix 'fd00:abcd::/48'

config device
    option name 'br-lan'
    option type 'bridge'
    list ports 'lan2'

config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'


config interface 'wan'
    option device '/dev/cdc-wdm0'
    option proto 'qmi'
    option apn 'internet'
    option auth 'none'
    option pdptype 'ipv4'
    option auto '1'

config interface 'wan6'
    option device 'wan'
    option proto 'dhcpv6'
EOF

cat > "$FOLDER_NAME/files/etc/config/firewall" << 'EOF'
config defaults
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option syn_flood '1'

config zone
    option name 'lan'
    option network 'lan'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'

config zone
    option name 'wan'
    option network 'wan wan6'
    option input 'REJECT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option masq '1'
    option mtu_fix '1'

config forwarding
    option src 'lan'
    option dest 'wan'
EOF


# 🏗️ Compilazione immagine
cd "$FOLDER_NAME"
echo "==> Compilo immagine per ${PROFILE}..."
make image PROFILE="$PROFILE" FILES=files/ PACKAGES="$PACKAGES"

# 📁 Output immagine

OUT_DIR="bin/targets/${TARGET}/${SUBTARGET}"
SYSUPGRADE=$(find "$OUT_DIR" -name '*sysupgrade*.bin' | head -n1)
[[ -f "$SYSUPGRADE" ]] || { echo "[X] sysupgrade.bin non trovato."; exit 1; }

# Desktop dell'utente reale (non root)
REAL_USER=${SUDO_USER:-$USER}
DESKTOP_DIR="/home/$REAL_USER/Desktop"

# fallback se Desktop non esiste
if [[ ! -d "$DESKTOP_DIR" ]]; then
    DESKTOP_DIR="/home/$REAL_USER"
fi

DEST="$DESKTOP_DIR/sysupgrade-${PROFILE}-$(date +%Y%m%d-%H%M).bin"

cp -f "$SYSUPGRADE" "$DEST"
echo "[✓] sysupgrade.bin copiato su Desktop: $DEST"

