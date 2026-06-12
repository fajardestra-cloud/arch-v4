#!/bin/bash
set -e

echo "--> [Chroot] Mengonfigurasi ALHP v4 secara permanen..."
cat <<EOT >> /etc/pacman.conf

[core-x86-64-v4]
Include = /etc/pacman.d/alhp-mirrorlist

[extra-x86-64-v4]
Include = /etc/pacman.d/alhp-mirrorlist
EOT

pacman -Syy --noconfirm

echo "--> [Chroot] Mengatur waktu dan wilayah..."
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
hwclock --systohc

echo "--> [Chroot] Mengonfigurasi lokal bahasa..."
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "--> [Chroot] Mengatur Network dan Hostname..."
echo "archlinux" > /etc/hostname

# Menggunakan <<EOT untuk menulis ke /etc/hosts (Spasi dibersihkan total)
cat <<EOT > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
EOT

echo "--> [Chroot] Silakan masukkan Password untuk akun ROOT:"
passwd

echo "--> [Chroot] Mengaktifkan NetworkManager..."
systemctl enable NetworkManager

echo "--> [Chroot] Mengonfigurasi bootloader (systemd-boot)..."
bootctl install

echo "--> [Chroot] Membuat initramfs dengan Dracut khusus Zen Kernel..."
ZEN_VER=$(ls /usr/lib/modules | grep zen)
dracut --kver "$ZEN_VER" --force /boot/initramfs-linux-zen.img
dracut --kver "$ZEN_VER" --force --add-drivers "rescue" /boot/initramfs-linux-zen-fallback.img

# Mendapatkan UUID Root secara otomatis
UUID_ROOT=$(blkid -s UUID -o value /dev/nvme0n1p2)

# Menggunakan <<EOT untuk menulis loader.conf
cat <<EOT > /boot/loader/loader.conf
default arch.conf
timeout 3
console-mode max
editor no
EOT

# Menggunakan <<EOT untuk menulis entri boot utama
cat <<EOT > /boot/loader/entries/arch.conf
title Arch Linux (Zen-v4)
linux /vmlinuz-linux-zen
initrd /intel-ucode.img
initrd /initramfs-linux-zen.img
options root=UUID=$UUID_ROOT rw rootflags=subvol=@ quiet
EOT

# Menggunakan <<EOT untuk menulis entri boot fallback
cat <<EOT > /boot/loader/entries/arch-fallback.conf
title Arch Linux (Zen-v4 Fallback)
linux /vmlinuz-linux-zen
initrd /intel-ucode.img
initrd /initramfs-linux-zen-fallback.img
options root=UUID=$UUID_ROOT rw rootflags=subvol=@
EOT

echo "--> [Chroot] Membuat user baru 'fajardestraprayoga'..."
if ! id "fajardestraprayoga" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash fajardestraprayoga
fi

echo "--> [Chroot] Masukkan password untuk user fajardestraprayoga:"
passwd fajardestraprayoga

echo "--> [Chroot] Memberikan akses Sudo (Wheel group)..."
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "--> [Chroot] Memeriksa status akhir bootloader..."
bootctl status

echo "--> [Chroot] Selesai! Keluar dari lingkungan chroot..."
exit
