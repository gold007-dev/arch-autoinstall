#!/bin/bash

pacman -S refind
refind-install


efi_partition=$(head -n 1 /partitions.tmp)
swap_partition=$(head -n 2 /partitions.tmp | tail -n 1)
filesystem_partition=$(tail -n 1 /partitions.tmp)

cp -r /usr/share/refind/icons /boot/EFI/refind/

echo "EFI=$efi_partition"
echo "SWAP=$swap_partition"
echo "FS=$filesystem_partition"

# lsblk -no UUID /dev/sda1

echo "menuentry "Arch Linux" {
	icon     /EFI/refind/icons/os_arch.png
	volume   "Arch Linux"
	loader   /vmlinuz-linux
	initrd   /initramfs-linux.img
	options  \"root=$filesystem_partition rw add_efi_memmap\"
	submenuentry "Boot using fallback initramfs" {
		initrd /initramfs-linux-fallback.img
	}
	submenuentry "Boot to terminal" {
		add_options "systemd.unit=multi-user.target"
	}
}" >>/boot/EFI/refind/refind.conf
