
#!/bin/bash

online=$(ping -q -c1 google.com &>/dev/null && echo online || echo offline)

if [[ $online == "offline" ]]; then
    echo "Please connect to the internet"
    exit 69
fi

echo You are on a $(cat /sys/firmware/efi/fw_platform_size)-bit system

echo "on which drive do you want your system to be? (example: (/dev/sda)"

read targetDisk

echo "create an efi partition (EFI format) (min. 1Gib)"
echo "we will not create a swap partition, we will create a swapfile on the encrypted partition later"
echo "create a file system partition (encrypted LUKS (with \`gdisk\` it's partition code 8309)) (Rest of diskspace (min. 32GiB))"

echo "Press enter when you are ready to set up your partitions"
read

cfdisk $targetDisk

echo "do you know where your partitions are? (example: /dev/sda1, /dev/sda2)"
echo "(y|yes|y|Yes|YES)"

read confirmation
pattern="[^(y|Y)]"
if [[ $confirmation =~ $pattern ]]; then
    vim <(fdisk -l)
fi
echo "What is your efi partition? example: /dev/sda1"
read efi_partition

echo "What is your filesystem partition? example: /dev/sda2"
read filesystem_partition

cryptsetup luksFormat --type luks2 $filesystem_partition
cryptsetup open --perf-no_read_workqueue --perf-no_write_workqueue --persistent $filesystem_partition cryptlvm

pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm
lvcreate -l 100%FREE vg -n root

mkfs.ext4 /dev/vg/root

mkfs.fat -F 32 "$efi_partition"

echo "Sucessfully created filesystems (mkfs)"

echo "Mounting filesystems"

mount /dev/vg/root /mnt

mount --mkdir "$efi_partition" /mnt/boot

echo "Partitions successfully mounted"

echo "Proceeding with installation"

# https://wiki.archlinux.org/title/Installation_guide#Installation

echo "Proceeding with installation"

echo "What packages do you want to install?"
echo "example: vim neovim nano man-db tree fastfetch intel-ucode man-pages"
read packages

pacstrap -K /mnt base linux linux-firmware $packages

echo "generating fstab"

genfstab -U /mnt >>/mnt/etc/fstab

cp install.sh /mnt/install.sh
cp rEFInd.sh /mnt/rEFInd.sh
chmod 777 /mnt/install.sh

echo "chrooting into /mnt"
echo "Please run /install.sh"
echo "$efi_partition" >/mnt/partitions.tmp
echo "$filesystem_partition" >>/mnt/partitions.tmp

LUKS_UUID=$(blkid -s UUID -o value $filesystem_partition)
BOOT_OPTIONS="cryptdevice=UUID=${LUKS_UUID}:cryptlvm root=/dev/vg/root"

cat << EOF > /mnt/boot/refind_linux.conf
"Boot with standard options"  "${BOOT_OPTIONS} rw loglevel=3"
"Boot to single-user mode"    "${BOOT_OPTIONS} rw loglevel=3 single"
"Boot with minimal options"   "ro ${BOOT_OPTIONS}"
EOF

arch-chroot /mnt
