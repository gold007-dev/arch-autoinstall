#!/bin/bash

#################################################################
###### This script should be run after chrooting into /mnt ######
#################################################################

echo "Setting up keys again"

pacman-key --init
pacman-key --populate archlinux

echo "checking if you are still online"

online=$(ping -q -c1 google.com &>/dev/null && echo online || echo offline)

if [[ $online == "offline" ]];then
    echo "Please connect to the internet"
    exit 69
fi

echo "Setting up local time"

first=1
region="undefined"
while ! [ -d "/usr/share/zoneinfo/$region" ]; do
    if [ $first -eq 0 ]; then
        echo "This region does not exist"
    fi
    echo "do you want to list all regions?"
    echo "[Y/n]"
    read regionList
    pattern="[^(y|Y)]"
    if ! [[ $regionList =~ $pattern ]]; then
        vim <(ls -lah /usr/share/zoneinfo)
    fi
    echo "What region are you in? (example: Europe)"
    read region
    first=0

done
first=1
city="undefined"
while ! [ -f "/usr/share/zoneinfo/$region/$city" ]; do
    if [ $first -eq 0 ]; then
        echo "This city does not exist"
    fi
    echo "do you want to list all cities?"
    echo "[Y/n]"
    read citylist
    pattern="[^(y|Y)]"
    if ! [[ $citylist =~ $pattern ]]; then
        vim <(ls -lah /usr/share/zoneinfo/$region)
    fi
    echo "What city are you in? (example: Zurich)"
    read city
    first=0

done

ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime

echo "generationg /etc/adjtime"

hwclock --systohc

echo "we will now set up the locale. please uncomment the line for your locale"
echo "we will later need the exact name of your selected locale. Please write it down"
echo "a vim instance will open after your confirmation"
echo "please press enter"
read

vim /etc/locale.gen

echo "generating locale"

locale-gen

echo "what locale did you use?"
echo "example: en_SG.UTF-8"
read locale

echo "LANG=$locale">/etc/locale.conf

echo "what keymap are you using?"
echo "example: sg-latin1"
read keymap

echo "KEYMAP=$keymap">>/etc/vconsole.conf

echo "what should the hostname be?"
echo "example: arch"
read hostname

echo "$hostname">/etc/hostname

echo "we will now set the root password"

passwd

echo "do you want to use rEFInd as your boot manager?"
echo "[Y/n]"
read rEFInd
pattern="[^(y|Y)]"
if ! [[ $refind =~ $pattern ]]; then
    /rEFInd.sh
fi


echo "installation complete. Please exit and reboot."

echo "Please remove the USB and boot into the newly installed arch system"

exit 0
