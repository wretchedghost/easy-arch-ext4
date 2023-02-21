#### If wifi is needed
```
# iwctl
station wlan0 scan
station wlan0 connect <SSID>
```

#### Set the date and time
```
# timedatectl set-ntp true
```
#### Set bigger font in the tty
```bash
# setfont ter-132b
```

#### Partition the disks
```bash
# gdisk /dev/nvme0n1
+512M ef00
100% 8300
```

#### Create the encrypted root partion
```bash
# cryptsetup luksFormat /dev/nvme0n1p2
# cryptsetup luksOpen /dev/nvme0n1p2 cryptroot
```

#### Build the filesystems
```
# mkfs.vfat -F32 /dev/nvme0n1p1
# mkfs.ext4 /dev/mapper/cryptroot
```

#### Mount root and boot
```
# mount /dev/mapper/cryptroot /mnt
# mkdir -p /mnt/boot
# mount /dev/nvme0n1p1 /mnt/boot
```

#### Setup the Swapfile
>24576 = 24G
>32768 = 32G

```
# dd if=/dev/zero of=/mnt/.swapfile bs=1M count=24576 status=progress
# chmod 600 /mnt/.swapfile
# mkswap /mnt/.swapfile
# swapon /mnt/.swapfile
```

#### Install the base files and generate the fstab. Also build the tmpfs
```
# pacstrap /mnt base base-devel linux linux-firmware vim git screenfetch networkmanager grub efibootmgr intel-ucode bash-completion
(linux-lts/linux-lts-headers, linux-zen/linux-zen-headers, linux-hardended/linux-hardended-headers can also be install or swapped out for linux/linux-headers)

# genfstab -U /mnt >> /mnt/etc/fstab

# vim /mnt/etc/fstab
tmpfs /tmp tmpfs rw,nodev,nosuid,size=8G,noatime,mode=1700 0 0
```
>(Also change all relatime to noatime EXCEPT for /boot)

#### Chroot into the new system drive
```
# arch-chroot /mnt /bin/bash
```

#### Setup the time and make it persistant
```
# ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
# hwclock --systohc
# vim /etc/locale.gen 
(uncomment en_US.UTF-8)
# locale-gen
# echo 'LANG=en_US.UTF-8' > /etc/locale.conf
```

#### Setup hostname and hosts files
```
# echo <hostname> > /etc/hostname
# vim /etc/hosts
>(127.0.0.1	localhost
>127.0.1.1	tpx1.wretchednet.in	tpx1)
```

#### Create the root password
```
# passwd
```

#### Edit the kernel hooks and tweak pacman.conf
```
# vim /etc/mkinitcpio.conf
```
>(add keyboard between autodetect and modconf and ecrypt between block and filesystem in the HOOKS array_)

```
# mkinitcpio -p linux 
```
>(For linux kernel. Use linux-lts for LTS kernel, linux-hardened, and or linux-zen)

```
# vim /etc/pacman.conf
```
>(uncommenct Color and add ILoveCandy. Uncomment multilib and the line underneath)


#### Build grub
```
# blkid -s UUID -o value /dev/nvme0n1p2 >> /etc/default/grub
# vim /etc/default/grub
>(set GRUB_CMDLINE_LINUX="cryptdevice=UUID=<uuid-here>:cryptroot" and uncomment GRUB_ENABLE_CRYPTODISK=y_
# grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ARCHLINUX
# grub-mkconfig -o /boot/grub/grub.cfg
```

#### Make sure wifi will work after reboot
```
# systemctl enable NetworkManager
```

#### Exit out of the chrooted system
```
# exit 
```

#### Reboot
```
# reboot
```
