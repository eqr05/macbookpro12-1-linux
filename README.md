# MacBook Linux

ISO autoarrancable de **Debian 13 (trixie) + XFCE** pensada para un **MacBook Pro de 2015**
(MacBookPro11,4 de 15" y MacBookPro12,1 de 13"), con los controladores que Apple no incluye
en una Debian normal: Wi-Fi Broadcom BCM43602, audio Intel, microcódigo y teclado/ratón estilo Mac.

## Qué incluye

| Componente | Detalle |
|---|---|
| Base | Debian 13 trixie, amd64, UEFI (`grub-efi`, sin syslinux) |
| Escritorio | XFCE con LightDM y autologin (`macbook`) |
| Instalador | Calamares, arranca solo al entrar al escritorio |
| Wi-Fi | `firmware-brcm80211` (BCM43602) + NetworkManager sin ahorro de energía |
| Audio | `firmware-intel-sound`, PipeWire, `snd_hda_intel power_save=0` |
| Teclado | distribución `es`, modelo `macintosh`, consola y X11 |
| Trackpad | libinput con tapping, scroll natural y clickfinger |
| Extra | Firefox ESR, GParted, Blueman, NTFS/ExFAT, microcódigo Intel |

## Obtener la ISO

La compilación la hace GitHub Actions y publica el resultado en **Releases**, troceado en
partes de 1,9 GB (límite de 2 GB por archivo en releases).

1. Descarga todas las partes (`macbook-linux.iso.part01`, `part02`, …) y `SHA256SUMS`.
2. Únelas:

   ```bat
   copy /b macbook-linux.iso.part* macbook-linux.iso
   ```

   En macOS o Linux:

   ```sh
   cat macbook-linux.iso.part* > macbook-linux.iso
   ```

3. Verifica:

   ```sh
   shasum -a 256 macbook-linux.iso      # macOS
   sha256sum macbook-linux.iso           # Linux
   ```

## Grabar el USB

- **macOS**: `diskutil list` para localizar el USB, luego
  `sudo dd if=macbook-linux.iso of=/dev/rdiskN bs=4m && sync` (usa `rdiskN`, no `diskN`).
- **Windows**: Rufus o balenaEtcher en modo *DD*, no en modo ISO.

## Arrancar e instalar

1. Apaga el Mac y enciéndelo con la tecla **Option (⌥)** pulsada.
2. Elige la entrada **EFI Boot** del USB.
3. En el escritorio live se abre **Instalar Debian** (Calamares) automáticamente.
4. Particionado recomendado para conservar macOS/Boot Camp: elige *Manual* y crea
   partición raíz ext4 sobre el espacio libre o sobre la partición que quieras reemplazar.
   Deja la ESP (`/boot/efi`) tal cual: Calamares instalará GRUB ahí.
5. El usuario live es `macbook` y tiene sudo sin contraseña.

### Arranque posterior

Si el Mac sigue arrancando macOS directamente, bendice GRUB desde macOS:

```sh
sudo bless --mount /Volumes/EFI --setBoot --file /Volumes/EFI/EFI/debian/grubx64.efi
```

## Problemas conocidos

- **Wi-Fi no aparece**: comprueba `dmesg | grep brcmfmac`. Si el firmware no carga, la ISO
  está corrupta; vuelve a verificar el SHA256.
- **Sin sonido tras suspender**: el hook ya desactiva el ahorro de energía del códec.
- **Teclado con layout incorrecto en consola**: `dpkg-reconfigure keyboard-configuration`.
- **Secure Boot**: Debian no está firmado por Apple; el arranque funciona con Secure Boot
  desactivado (por defecto en estos Mac).

## Compilar tú mismo

El workflow [`.github/workflows/build-iso.yml`](.github/workflows/build-iso.yml) valida las
opciones de `lb config`, compila dentro de un contenedor Debian trixie (`--privileged`),
comprueba que el firmware Broadcom y Calamares están dentro del squashfs, y publica la ISO
troceada en un Release.

En local (Debian/Ubuntu, como root):

```sh
apt-get install live-build debootstrap squashfs-tools xorriso grub-efi-amd64-bin mtools dosfstools rsync
./build.sh
```

## Estructura

```
auto/config                      opciones de lb config
build.sh                         script de compilación
config/package-lists/            paquetes por lista
config/includes.chroot/          archivos que se copian al sistema live
config/hooks/live/               ajustes post-instalación (locale, teclado, sudo, initramfs)
.github/workflows/build-iso.yml  compilación en la nube
```
