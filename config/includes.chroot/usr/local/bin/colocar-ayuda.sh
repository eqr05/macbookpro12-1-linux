#!/bin/sh
# Copia la guia al escritorio del usuario una sola vez por cuenta.
dir=$(xdg-user-dir DESKTOP 2>/dev/null)
[ -n "$dir" ] || dir="$HOME/Escritorio"
marca="$HOME/.config/macbook-linux/ayuda-colocada"

[ -e "$marca" ] && exit 0

mkdir -p "$dir" "$HOME/.config/macbook-linux" 2>/dev/null || exit 0
if [ ! -e "$dir/Comandos-Linux.txt" ] && [ -r /usr/share/macbook-linux/Comandos-Linux.txt ]; then
	cp /usr/share/macbook-linux/Comandos-Linux.txt "$dir/Comandos-Linux.txt" 2>/dev/null || exit 0
fi
touch "$marca" 2>/dev/null || true
