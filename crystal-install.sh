#!/bin/sh
# Arch Linux installer script. EFI only!


# Check if chroot_commands.sh exists in the current directory.
if [ ! -f chroot_commands.sh ]; then
    echo "Error: chroot_commands.sh not found in the current directory."
    echo "Please ensure chroot_commands.sh is in the same directory as this script."
    exit 1
fi

[ -z "$1" ] && printf "Usage: Provide only the drive to install to (i.e /dev/sda, see lsblk)\n\n./archstrap.sh [DRIVE]\n\n" && exit
[ ! -b "$1" ] && printf "Drive $1 is not a valid block device.\n" && exit
printf "\nThis script will erase all data on $1.\nAre you certain? (y/n): " && read CERTAIN
[ "$CERTAIN" != "y" ] && printf "Abort." && exit

#!/bin/sh
# Arch Linux installer script. EFI only!

# Prompt for the username and password of the second user.
echo "Enter the username of your user (this will also be the hostname):"
read username
export username
echo "Enter the password for $username:"
read -s user_password
export user_password

# Set the hostname to be the same as the username.
hostname=$username
export hostname

# Set the locale, localtime, and keymap.
locale_lang="en_US.UTF-8"
export locale_lang
localtime="/usr/share/zoneinfo/America/Santiago"
export localtime
keymap="jp106"
export keymap

# Set the partition schema.
partition_schema="/dev/sda"
export partition_schema

# Print a brief with the installation configs.
echo "Installation configs:"
echo "Username: $username"
echo "Hostname: $hostname"
echo "Locale Lang: $locale_lang"
echo "Localtime: $localtime"
echo "Keymap: $keymap"
echo "Partition Schema: $partition_schema"
echo "Current partition layout:"
fdisk -l $partition_schema

# Prompt for confirmation before continuing.
echo "Do you want to continue with these settings? (y/n)"
read confirmation
if [ "$confirmation" != "y" ]; then
    echo "Installation cancelled."
    exit 1
fi

disk=$1
boot=${disk}1
swap=${disk}2
root=${disk}3

# Cleanup from previous runs.
if swapon --summary | grep -q "$swap"; then
    swapoff $swap
fi
umount -R /mnt || true

# Partition 1GB for boot, 3GB for swap, rest for root.
# Optimal alignment will change the exact size though!
set -xe
parted -s $disk mklabel gpt
parted -sa optimal $disk mkpart primary fat32 0% 1GB
parted -sa optimal $disk mkpart primary linux-swap 1GB 4GB
parted -sa optimal $disk mkpart primary ext4 4GB 100%
parted -s $disk set 1 esp on

# Format the partitions.
mkfs.fat -IF32 $boot
mkswap -f $swap
mkfs.ext4 -F $root

# Mount the partitions.
mount $root /mnt
mkdir -p /mnt/boot
mount $boot /mnt/boot
swapon $swap

# Packages and chroot.
pacstrap /mnt linux linux-firmware networkmanager vim base base-devel git man efibootmgr grub
genfstab -U /mnt > /mnt/etc/fstab

# Enter the system and set up basic locale, passwords and bootloader.
arch-chroot /mnt ./chroot_commands.sh

# Finalize.
umount -R /mnt
set +xe

printf "
        *--- Installation Complete! ---*
        |                              |
        |        Username: root        |
        |        Password: 123         |
        |                              |
        *------------------------------*

"