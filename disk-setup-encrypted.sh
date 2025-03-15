
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

MAPPER_NAME="ArchCryptLVM"
VG_NAME="ArchVolumeGroup"

cryptsetup luksFormat --type luks2 $filesystem_partition
cryptsetup open --perf-no_read_workqueue --perf-no_write_workqueue --persistent $filesystem_partition $MAPPER_NAME

pvcreate /dev/mapper/$MAPPER_NAME
vgcreate $VG_NAME /dev/mapper/$MAPPER_NAME

echo "Do you wan't a virtual swap partition? [Y/n]"
read swapq
pattern="[(y|Y)]"
if [[ $swapq =~ $pattern ]]; then
    echo "How many gigabytes of swap do you want? example: 4"
    read swapg
    lvcreate -l ${swapg}G $VG_NAME -n swap
    mkswap /dev/$VG_NAME/swap
fi

lvcreate -l 100%FREE $VG_NAME -n root

mkfs.ext4 /dev/$VG_NAME/root

mkfs.fat -F 32 "$efi_partition"

echo "Sucessfully created filesystems (mkfs)"

echo "Mounting filesystems"

mount /dev/$VG_NAME/root /mnt

mount --mkdir "$efi_partition" /mnt/boot

swapon /dev/$VG_NAME/swap

echo "Partitions successfully mounted"

echo "Proceeding with installation"

# https://wiki.archlinux.org/title/Installation_guide#Installation

echo "Proceeding with installation"

echo "What packages do you want to install?"
echo "example: vim neovim nano man-db tree fastfetch intel-ucode man-pages"
read packages

pacstrap -K /mnt base linux linux-firmware lvm2 $packages

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
BOOT_OPTIONS="cryptdevice=UUID=${LUKS_UUID}:${MAPPER_NAME} root=/dev/${VG_NAME}/root"

cat << EOF > /mnt/boot/refind_linux.conf
"Boot with standard options"  "${BOOT_OPTIONS} loglevel=3 rw"
"Boot to single-user mode"    "${BOOT_OPTIONS} loglevel=3 rw single"
EOF

arch-chroot /mnt
