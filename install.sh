#!/bin/bash
set -e

echo "===================================================="
echo "   Arch Linux x86_64-v4 + Zen Kernel Installer      "
echo "===================================================="

# Cek koneksi internet sebelum mulai agar tidak macet di tengah jalan
echo "--> Memeriksa koneksi internet..."
if ! ping -c 2 google.com &>/dev/null; then
    echo "ERROR: Tidak ada koneksi internet. Sambungkan internet terlebih dahulu!"
    exit 1
fi

echo "--> Membuat tabel partisi GPT dan partisi baru pada /dev/nvme0n1..."
sgdisk --zap-all /dev/nvme0n1
sgdisk --new=1:0:+2G --typecode=1:ef00 --change-name=1:ESP /dev/nvme0n1
sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:ArchLinux /dev/nvme0n1

# Menunggu kernel me-refresh tabel partisi baru
sleep 2 

echo "--> Memformat partisi (FAT32 & Btrfs)..."
mkfs.fat -F32 -n ESP /dev/nvme0n1p1
mkfs.btrfs -L ArchLinux -f /dev/nvme0n1p2

echo "--> Membuat subvolume Btrfs..."
mount /dev/nvme0n1p2 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
umount /mnt

echo "--> Mounting subvolume dengan kompresi zstd..."
mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p2 /mnt

mkdir -p /mnt/home
mkdir -p /mnt/boot
mkdir -p /mnt/var/cache
mkdir -p /mnt/var/log

mount -o noatime,compress=zstd,subvol=@home /dev/nvme0n1p2 /mnt/home
mount -o noatime,compress=zstd,subvol=@cache /dev/nvme0n1p2 /mnt/var/cache
mount -o noatime,compress=zstd,subvol=@log /dev/nvme0n1p2 /mnt/var/log
mount /dev/nvme0n1p1 /mnt/boot

echo "--> Mengonfigurasi PGP Key dan repositori ALHP v4 pada Live ISO..."
# 1. Inisialisasi gpg bawaan ISO agar siap menerima key baru
pacman-key --init
pacman-key --populate archlinux

echo "--> Mengonfigurasi repositori ALHP v4 (Bypass Key Check)..."
# Menambahkan repositori ALHP dengan aturan SigLevel = Optional TrustAll
# Ini membuat pacman mengabaikan error PGP key khusus untuk repo ALHP selama instalasi
sed -i '/^\[core\]/i [core-x86-64-v4]\nSigLevel = Optional TrustAll\nServer = https://cdn.alhp.dev/\$repo/os/\$arch\n\n[extra-x86-64-v4]\nSigLevel = Optional TrustAll\nServer = https://cdn.alhp.dev/\$repo/os/\$arch\n' /etc/pacman.conf

# Sinkronisasi database database pacman setelah repositori ditambahkan
pacman -Sy --noconfirm

echo "--> Mengurutkan mirrorlist resmi terdekat..."
reflector --country Indonesia --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

echo "--> Menjalankan pacstrap..."
pacstrap -K /mnt base base-devel linux-zen linux-zen-headers linux-firmware dracut btrfs-progs nano intel-ucode networkmanager sudo alhp-keyring alhp-mirrorlist

echo "--> Membuat berkas fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "--> Mempersiapkan lingkungan chroot..."
curl -L -o /mnt/chroot.sh https://raw.githubusercontent.com/fajardestra-cloud/arch-v4/main/chroot.sh
chmod +x /mnt/chroot.sh

echo "--> Memasuki arch-chroot..."
arch-chroot /mnt ./chroot.sh

echo "--> Membersihkan sisa instalasi..."
rm -f /mnt/chroot.sh
umount -R /mnt
echo "===================================================="
echo " Instalasi Berhasil! PC akan dimatikan dalam 5 detik."
echo "===================================================="
sleep 5
poweroff
