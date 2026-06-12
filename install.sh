#!/bin/bash

# Exit jika terjadi error
set -e

echo "===================================================="
echo "   Arch Linux x86_64-v4 + Zen Kernel Installer      "
echo "===================================================="

# 1. Skema Partisi Otomatis dengan gdisk
echo "--> Membuat tabel partisi GPT dan partisi baru pada /dev/nvme0n1..."
sgdisk --zap-all /dev/nvme0n1
sgdisk --new=1:0:+2G --typecode=1:ef00 --change-name=1:ESP /dev/nvme0n1
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:ArchLinux /dev/nvme0n1

# 2. Format Partisi
echo "--> Memformat partisi (FAT32 & Btrfs)..."
mkfs.fat -F32 -n ESP /dev/nvme0n1p1
mkfs.btrfs -L ArchLinux -f /dev/nvme0n1p2

# 3. Pembuatan Skema Subvolume Btrfs
echo "--> Membuat subvolume Btrfs..."
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
umount /mnt

# 4. Mount Subvolume dengan Opsi Optimasi
echo "--> Mounting subvolume dengan kompresi zstd..."
mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt

# Membuat direktori mount point
mkdir -p /mnt/home
mkdir -p /mnt/boot
mkdir -p /mnt/var/cache
mkdir -p /mnt/var/log

# Mount sisa subvolume dan partisi boot
mount -o noatime,compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
mount -o noatime,compress=zstd,subvol=@cache /dev/nvme0n1p2 /mnt/var/cache
mount -o noatime,compress=zstd,subvol=@log /dev/nvme0n1p2 /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot

# 5. Konfigurasi ALHP v4 pada Live ISO
echo "--> Mengonfigurasi PGP Key dan repositori ALHP v4 pada Live ISO..."
pacman-key --recv-keys F7AC1436EFE55AA17BB38B4254DF2855BAEB77EA
pacman-key --lsign-key F7AC1436EFE55AA17BB38B4254DF2855BAEB77EA

# Modifikasi pacman.conf yang lebih aman untuk ALHP
sed -i '/^\[core\]/i [core-x86-64-v4]\nServer = https://cdn.alhp.dev/\$repo/os/\$arch\n\n[extra-x86-64-v4]\nServer = https://cdn.alhp.dev/\$repo/os/\$arch\n' /etc/pacman.conf

# 6. Optimasi Mirrorlist Resmi Utama
echo "--> Mengurutkan mirrorlist resmi terdekat..."
reflector --country Indonesia --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# 7. Eksekusi Pacstrap (Ditambahkan dracut-hook agar otomatisasi Dracut berjalan sempurna)
echo "--> Menjalankan pacstrap..."
pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware dracut btrfs-progs nano intel-ucode networkmanager sudo alhp-keyring alhp-mirrorlist

# 8. Generate Fstab
echo "--> Membuat berkas fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# 9. Mengunduh Skrip Chroot ke Dalam Sistem Baru
echo "--> Mempersiapkan lingkungan chroot..."
curl -L -o /mnt/chroot.sh https://raw.githubusercontent.com/fajardestra-cloud/arch-v4/main/chroot.sh
chmod +x /mnt/chroot.sh

# 10. Masuk ke Lingkungan Chroot Secara Otomatis
echo "--> Memasuki arch-chroot..."
arch-chroot /mnt ./chroot.sh

# 11. Finalisasi Setelah Keluar dari Chroot
echo "--> Membersihkan sisa instalasi..."
rm -f /mnt/chroot.sh
umount -R /mnt
echo "===================================================="
echo " Instalasi Berhasil! PC akan dimatikan dalam 5 detik."
echo "===================================================="
sleep 5
poweroff
