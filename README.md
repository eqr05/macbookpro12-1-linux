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
| Automontaje | Thunar + udisks para USB/SD y servicio `montar-discos` para particiones internas (NTFS, FAT, exFAT, ext4, HFS+) |
| Ayuda | `Comandos-Linux.txt` en el escritorio (comandos, discos, QEMU, IA en Linux) |
| Extra | Firefox ESR, GParted, Blueman, NTFS/ExFAT/HFS+, microcódigo Intel |

## Automontaje de discos

Hay dos capas, para no pisarse:

- **Live**: automontaje de Thunar (`thunar-volman` + `gvfs-backends`) para USB,
  tarjetas SD y cámaras. Los discos internos se montan con un clic para que
  Calamares no encuentre particiones ocupadas durante la instalación (el
  servicio lleva `ConditionKernelCommandLine=!boot=live`).
- **Sistema instalado**: además, el servicio `montar-discos` monta las
  particiones internas (Boot Camp NTFS, FAT, exFAT, ext4, HFS+) al arrancar y
  cuando aparecen, en `/media/<etiqueta>`, en lectura/escritura y con reintento
  en solo lectura. Se saltan swap, LUKS, LVM, RAID, la partición EFI, el medio
  live y los discos extraíbles. Manual: `sudo systemctl start
  montar-discos.service` y `journalctl -t montar-discos -b`.

## Solo en el sistema instalado

Calamares ejecuta el módulo `packages` (con `try_install` y
`skip_if_no_internet`), así que el live no se infla pero el sistema instalado
recibe, si hay red: `mbpfan` (ventiladores y sensores del Mac), `qemu-system-x86`
y `qemu-utils` para máquinas virtuales. Si no hay internet, la instalación
termina igual y esos extras se pueden poner después con `apt`.

## Ayuda en español

`Comandos-Linux.txt` se copia al escritorio del live y, vía `/etc/skel` y un
autostart idempotente, al del usuario que crees al instalar. Incluye comandos
básicos, `apt`, red/Wi-Fi, discos y automontaje, logs, `nomodeset`, QEMU y
asistentes de IA en Linux. También queda en `/usr/share/macbook-linux/`.

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
3. Entra en la sesión live (usuario `macbook`, sin contraseña). No hay una entrada
   «Install» aparte: la ISO **no incluye el instalador clásico de Debian**, solo
   Calamares dentro de la sesión live, para que nada repartione el disco sin que tú
   lo confirmes.
4. Al entrar al escritorio se abre **Instalar Debian** (Calamares).
5. Particionado recomendado para conservar macOS/Boot Camp: elige *Manual* y crea
   partición raíz ext4 sobre el espacio libre o sobre la partición que quieras reemplazar.
   Deja la ESP (`/boot/efi`) tal cual: Calamares instalará GRUB ahí.

### Arranque posterior

Si el Mac sigue arrancando macOS directamente, bendice GRUB desde macOS:

```sh
sudo bless --mount /Volumes/EFI --setBoot --file /Volumes/EFI/EFI/debian/grubx64.efi
```

## Menú de prueba de i915 (recuperar HDMI)

El arranque por defecto usa `nomodeset`, que deja todo funcionando salvo la GPU:
sin aceleración y sin HDMI (el audio HDMI depende del driver gráfico). Para
intentar recuperarlo, el menú GRUB del USB trae el submenú **«Probar i915 (puede
colgar)»** con seis combinaciones:

1. `i915.enable_dc=0` + mitigaciones de base (psr, fbc, iommu)
2. la 1 + `i915.enable_rc6=0`
3. la 1 + `i915.enable_execlists=0 i915.enable_semaphores=0`
4. la 1 + `i915.enable_ips=0 i915.fastboot=0`
5. la 1 + `acpi_osi=Darwin`
6. todas juntas

Se arrancan desde el USB (solo lectura, no toca el disco). Si una funciona:

```sh
lspci -k | grep -A3 -i vga   # debe decir "Kernel driver in use: i915"
aplay -l                     # debe listar el HDMI
```

Para fijarla en el sistema instalado, edita
`/etc/default/grub.d/99-macbook-nomodeset.cfg`: quita `nomodeset` y pon los
parámetros que funcionaron, luego `sudo update-grub`. El menú lo genera
`config/hooks/live/0200-menu-i915.hook.binary`, que añade las entradas a
`boot/grub/grub.cfg` después de que live-build lo genere.

## Problemas conocidos

- **Pantalla congelada o reinicio al arrancar**: la ISO ya incluye `nomodeset` de serie,
  así que no hace falta editar GRUB. El sistema instalado también lo hereda (vía
  `/etc/default/grub.d/99-macbook-nomodeset.cfg`), porque el modesetting de i915 en la
  Iris Pro 5200 cuelga con el kernel 6.12 de trixie. Si quieres probar la aceleración
  gráfica más adelante, borra ese archivo y ejecuta `sudo update-grub`; si vuelve a
  colgarse, arranca una vez editando GRUB y añadiendo `nomodeset`.
- **Vídeo por software y sin salidas externas**: es consecuencia de `nomodeset`
  (renderizado con llvmpipe); al recuperar el driver i915 desaparece.
- **Consola de diagnóstico**: si la sesión gráfica no responde pero la máquina está
  viva, pulsa `Ctrl+Alt+F2` para pasar a una consola de texto y ejecuta `dmesg`.
- **Windows no arranca tras un intento de instalación**: no escribas nada más y
  repara el gestor de arranque. Desde macOS: arranca con Option y elige el disco de
  Windows; si no aparece, monta la ESP y vuelve a bendecir el arranque de Microsoft
  (`/Volumes/EFI/EFI/Microsoft/Boot/bootmgfw.efi`). Desde un USB de Windows:
  `bcdboot C:\Windows /s S: /f UEFI` (siendo `S:` la ESP montada).
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
