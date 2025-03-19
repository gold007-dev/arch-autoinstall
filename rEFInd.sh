#!/bin/bash

encrypted=$(head -n 1 /encrypted.tmp)

if [[ $encrypted == "YES" ]]; then

	sed -i '/^HOOKS/s/\(block \)\(.*filesystems\)/\1encrypt lvm2 \2/' /etc/mkinitcpio.conf

	efi_partition=$(head -n 1 /partitions.tmp)
	filesystem_partition=$(tail -n 1 /partitions.tmp)
	echo "EFI=$efi_partition"
	echo "FS=$filesystem_partition"

	# lsblk -no UUID /dev/sda1

	MAPPER_NAME="ArchCryptLVM"
	VG_NAME="ArchVolumeGroup"
	LUKS_UUID=$(blkid -s UUID -o value $filesystem_partition)
	BOOT_OPTIONS="cryptdevice=UUID=${LUKS_UUID}:${MAPPER_NAME} root=/dev/${VG_NAME}/root"

	cat << EOF > /boot/refind_linux.conf
	"Boot with standard options"  "${BOOT_OPTIONS} loglevel=3 rw"
	"Boot to single-user mode"    "${BOOT_OPTIONS} loglevel=3 rw single"
	EOF

	pacman -S refind
	refind-install

	cp -r /usr/share/refind/icons /boot/EFI/refind/

	echo "menuentry "Arch Linux" {
		icon     /EFI/refind/icons/os_arch.png
		volume   "Arch Linux"
		loader   /vmlinuz-linux
		initrd   /initramfs-linux.img
		options  \"${BOOT_OPTIONS} loglevel=3 rw\"
		submenuentry "Boot using fallback initramfs" {
			initrd /initramfs-linux-fallback.img
		}
		submenuentry "Boot to terminal" {
			add_options "systemd.unit=multi-user.target"
		}
	}" >>/boot/EFI/refind/refind.conf
	efibootmgr --create --disk $(echo "$efi_partition" | sed "s/[0-9]$//") --part $(echo "$efi_partition" | grep -o "[0-9]*$") --loader /EFI/refind/refind_x64.efi --label "rEFInd Boot Manager" --unicode
	mkinitcpio -p linux
else
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
	efibootmgr --create --disk $(echo "$efi_partition" | sed "s/[0-9]$//") --part $(echo "$efi_partition" | grep -o "[0-9]*$") --loader /EFI/refind/refind_x64.efi --label "rEFInd Boot Manager" --unicode
fi
