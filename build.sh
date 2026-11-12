#!/bin/sh
set -eu
cd "$(dirname "$0")"

if [ "$(id -u)" -ne 0 ]; then
	echo "Ejecuta este script como root: sudo ./build.sh" >&2
	exit 1
fi

case "$(pwd)" in
	/mnt/*)
		echo "Estás en /mnt (drvfs). Copia el proyecto a ~/macbook-linux antes de compilar." >&2
		echo "  cp -a /mnt/c/Users/EQR/Documents/Qoder/2026-11-10/cf5f3a7f/macbook-linux ~/ && cd ~/macbook-linux" >&2
		exit 1
		;;
esac

command -v lb >/dev/null 2>&1 || {
	echo "Falta live-build: apt install live-build debootstrap squashfs-tools xorriso" >&2
	exit 1
}

# Normalizar finales de línea y permisos si el proyecto viene de Windows
sed -i 's/\r$//' auto/config build.sh config/hooks/live/*.hook.chroot
chmod +x auto/config config/hooks/live/*.hook.chroot

exec lb build
