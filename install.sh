#!/bin/bash
loadkeys sg-latin1

echo You are on a $(cat /sys/firmware/efi/fw_platform_size)-bit system

echo "create an efi partition (EFI format) (min. 1Gib)"
echo "create a swap partition (swap format) (min. 4GiB)"
echo "create a file system partition (Linux format) (Rest of diskspace (min. 32GiB))"

echo "Press enter when you are ready to set up your partitions"
read

cfdisk

echo "What is your filesystem partition? example: /dev/sda1"
read filesystem_partition

mkfs.ext4 "$filesystem_partition"

echo "What is your swap partition? example: /dev/sda2"
read swap_partition

mkswap "$swap_partition"

echo "What is your efi partition? example: /dev/sda3"
read efi_partition

mkfs.fat -F 32 "$efi_partition"

echo "Sucessfully created filesystems (mkfs)"

echo "Mounting filesystems"

mount "$filesystem_partition" /mnt

mount --mkdir "$efi_partition" /mnt/boot

swapon "$swap_partition"

echo "Partitions successfully mounted"

echo "Proceeding with installation"

# https://wiki.archlinux.org/title/Installation_guide#Installation