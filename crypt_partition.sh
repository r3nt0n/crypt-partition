# #!/bin/bash
# r3nt0n
# crypt-partition.sh - automatic partition encryption with cryptsetup
# https://github.com/r3nt0n/crypt-partition.sh

# IMPORTANT: this script must be executed by root and with all other users logout
# if you try to run it from a user session, you werent able to umount /home
# To create a password for root:
# sudo -i
# passwd
# after encryption, delete with:
# passwd -dl root

# Just SET this three variables and run it with elevated privileges.
# partition:     the partition you want to encrypt
# mounted_point: the path where the partition is currently mounted
# mapper_name:   mapper name to encrypted partition used by cryptsetup
partition=/dev/sdax
mounted_point=/home
mapper_name=HOME

apt install -y cryptsetup
if [ $? -eq 100 ]; then
    echo "You need privileges to run this script."
	exit 2
fi

# Loading dm_crypt module in memory
modprobe dm_crypt

# Creating a backup
mkdir /backup/
cp -a $mounted_point/ /backup/
# Umount the partition
umount $mounted_point
# if you are unable to umount or umount -f, to logout other users, do:
# pkill -KILL -u user

# [Optional] Rewrite all sectors with random data
#dd if=/dev/urandom of=$partition bs=4096

# Format partition
cryptsetup -v -s 512 -y luksFormat $partition
# Open partition and assign a mapper name
cryptsetup luksOpen $partition $mapper_name
# Create file system
mkfs.ext4 /dev/mapper/$mapper_name

# Add a new entry to /etc/crypttab
uuid=$(blkid $partition | cut -d' ' -f2 | tr -d '"')
echo "$mapper_name  $uuid  none luks,timeout=180" >> /etc/crypttab

# [Optional] Create /etc/fstab backup
cp /etc/fstab /etc/fstab.bak

# Remove old partition mountpoint (still not working, do it manually)
sed -i "\|$mounted_point|d" /etc/fstab
# Add this new entry to /etc/fstab
echo "# /home crypted partition" >> /etc/fstab
echo "/dev/mapper/$mapper_name  $mounted_point  ext4  defaults,noatime,nodiratime 1 2" >> /etc/fstab

# Mount the crypted partition and restore the backup
mount /dev/mapper/$mapper_name
cp -a /backup/* $mounted_point/

# Update the changes to initramfs
update-initramfs -u

# To umount and close partition (optional, test purposes):
#umount /dev/mapper/$mapper_name
#cryptsetup luksClose $mapper_name

# Reboot to test
reboot -h now

# You can remove /backup/ after reboot and testing

exit 0
