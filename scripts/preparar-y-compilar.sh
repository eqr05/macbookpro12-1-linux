#!/bin/bash
# Ejecutar como root dentro de Debian WSL:
#   bash preparar-y-compilar.sh /mnt/c/.../macbook-linux /mnt/c/.../macbook-linux/iso
set -euo pipefail

PROJECT_WSL="${1:?Uso: preparar-y-compilar.sh <ruta-proyecto-en-wsl> [ruta-salida-iso-en-wsl]}"
ISO_OUT="${2:-}"
DEST=/root/macbook-linux
USER_NAME=macbook

step() { printf '\n==> %s\n' "$*"; }

step "Usuario $USER_NAME"
if ! id "$USER_NAME" >/dev/null 2>&1; then
	useradd -m -s /bin/bash -G sudo "$USER_NAME"
	echo "$USER_NAME:$USER_NAME" | chpasswd
fi
if ! grep -q '^default=' /etc/wsl.conf 2>/dev/null; then
	printf '[user]\ndefault=%s\n' "$USER_NAME" >> /etc/wsl.conf
fi

step "Espacio libre en WSL"
avail_kb=$(df -Pk /root | awk 'NR==2 {print $4}')
if [ "$avail_kb" -lt 8388608 ]; then
	echo "ERROR: se necesitan ~8 GB libres en WSL y hay $((avail_kb/1024/1024)) GB." >&2
	exit 1
fi

step "Instalando herramienta de compilación"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
	live-build debootstrap squashfs-tools xorriso \
	grub-efi-amd64-bin mtools dosfstools rsync ca-certificates

step "Copiando proyecto a ext4 ($DEST)"
rm -rf "$DEST"
mkdir -p "$DEST"
rsync -a \
	--exclude 'binary*' --exclude 'chroot*' --exclude 'cache*' \
	--exclude '.build' --exclude '*.iso' --exclude 'iso/' \
	"$PROJECT_WSL/" "$DEST/"

step "Prueba 1: opciones en lb config --help"
help_out=$(lb config --help 2>&1 || true)
for opt in architectures distribution archive-areas updates security \
	binary-images bootloaders bootappend-live debian-installer \
	debian-installer-gui firmware-binary iso-application iso-publisher \
	iso-volume memtest; do
	if grep -q -- "--$opt" <<<"$help_out"; then
		printf '  OK    --%s\n' "$opt"
	else
		printf '  FALLO --%s no aparece en --help\n' "$opt" >&2
		exit 1
	fi
done
for opt in language locale timezone keyboard-layouts keyboard-model; do
	if grep -q -- "--$opt" <<<"$help_out"; then
		printf '  FALLO --%s debería estar ausente\n' "$opt" >&2
		exit 1
	else
		printf '  OK    --%s ausente (correcto)\n' "$opt"
	fi
done

step "Prueba 2: parseo real de auto/config"
tmp=$(mktemp -d)
cp "$DEST/auto/config" "$tmp/auto/config"
chmod +x "$tmp/auto/config"
( cd "$tmp" && ./auto/config )
test -d "$tmp/config" || { echo "ERROR: auto/config no generó config/" >&2; exit 1; }
rm -rf "$tmp"
echo "  OK    auto/config parseado sin errores"

step "Compilando ISO (20-60 min)"
cd "$DEST"
lb clean >/dev/null 2>&1 || true
./build.sh 2>&1 | tee /root/build.log

step "Validando ISO"
ISO="$DEST/live-image-amd64.hybrid.iso"
[ -f "$ISO" ] || { echo "ERROR: no se generó $ISO" >&2; exit 1; }
ls -lh "$ISO"
( cd "$DEST" && sha256sum "$(basename "$ISO")" | tee SHA256SUMS )

if unsquashfs -l "$DEST/binary/live/filesystem.squashfs" 2>/dev/null | grep -q 'brcmfmac43602-pcie.bin'; then
	echo "  OK    firmware BCM43602 (Wi-Fi) presente"
else
	echo "  AVISO no se encontró brcmfmac43602-pcie.bin en el squashfs" >&2
fi
if unsquashfs -l "$DEST/binary/live/filesystem.squashfs" 2>/dev/null | grep -q 'calamares'; then
	echo "  OK    Calamares presente"
fi

if [ -n "$ISO_OUT" ] && [ -d "$ISO_OUT" ]; then
	step "Copiando ISO y logs a Windows"
	cp -f "$ISO" "$ISO_OUT/"
	cp -f "$DEST/SHA256SUMS" "$ISO_OUT/"
	cp -f /root/build.log "$ISO_OUT/"
fi

step "Fin: ISO en $ISO"
