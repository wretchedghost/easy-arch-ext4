## Details

```text
=============================================================================================================
███████╗ █████╗ ███████╗██╗   ██╗      █████╗ ██████╗  ██████╗██╗  ██╗      ███████╗██╗  ██╗████████╗██╗  ██╗
██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝     ██╔══██╗██╔══██╗██╔════╝██║  ██║      ██╔════╝╚██╗██╔╝╚══██╔══╝██║  ██║
█████╗  ███████║███████╗ ╚████╔╝█████╗███████║██████╔╝██║     ███████║█████╗█████╗   ╚███╔╝    ██║   ███████║
██╔══╝  ██╔══██║╚════██║  ╚██╔╝ ╚════╝██╔══██║██╔══██╗██║     ██╔══██║╚════╝██╔══╝   ██╔██╗    ██║   ╚════██║
███████╗██║  ██║███████║   ██║        ██║  ██║██║  ██║╚██████╗██║  ██║      ███████╗██╔╝ ██╗   ██║        ██║
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝      ╚══════╝╚═╝  ╚═╝   ╚═╝        ╚═╝
=============================================================================================================
```

This is a fork of classy-giraffe's easy-arch script that can be found here: [https://github.com/classy-giraffe/easy-arch](https://github.com/classy-giraffe/easy-arch). I prefer to use a more simplified setup by using `GRUB2` rather than `systemd` as a bootloader. I am also not hip enough to use `btrfs` so I will stick with the simple yet rock solid `ext4`.

> Bug error: If you are running on a virtual machine then make sure to uncomment the virt_check function that is run. I had to disable it due to it getting hung up on hardware. For now the virt_check func will be commented out.

[Easy-Arch-EXT4](https://git.wretchednet.com/wretchedghost/easy-arch-ext4) is a **bash script** that boostraps [Arch Linux](https://archlinux.org/) with ***very*** sane defaults.

## What this script uses to install Arch Linux

- **UEFI or EFI ONLY**

- **ext4**: Easy to work with filesystem that just works. Though you will not have the fancy backups and restore features like `btrfs`.
- **LUKS2 encryption**: Your data will live on a LUKS2 partition protected by a password while at rest.
- **Swapfile**: Built in `/` at `/.swapfile`. Allows user to create a swapfile in any size they want from 1MB to 99999MB.
- **Bash**: Built on `bash` but `zsh` can be installed and used as default if desired manually.
- **User setup**: You'll be guided through the process of setting up a default user account with sudo permissions.
- **Tmpfs directory**: A tmpfs partition will be created at `/tmp` with the size of 8G. This can be changed by editing the easy-arch-ext4.sh file"
- **Noatime**: This is **NOT** enabled by default as more and more people are using NVMe drives more than SSDs now. If you use a SSD you **should** add noatime to all partitions in `/etc/fstab` post install.

## Pull

```text 
# git clone https://git.wretchednet.com/wretchedghost/easy-arch-ext4
# cd easy-arch-ext4
# chmod +x easy-arch.sh
# bash easy-arch.sh
```

Read through my code if you want before blindly running the script.

## Partitions layout 

The **partitions layout** is simple and it consists of only two partitions:
1. A **FAT32** partition (550MiB), mounted at `/boot/` as ESP.
2. A **LUKS2 encrypted container** called `cryptroot`, which takes the rest of the disk space, mounted at `/` as root.

| Partition Number | Label     | Size              | Mountpoint     | Filesystem              |
|------------------|-----------|-------------------|----------------|-------------------------|
| 1                | ESP       | 512 MiB           | /boot/         | FAT32                   |
| 2                | CRYPTROOT | Rest of the disk  | /              | EXT4 Encrypted (LUKS2) |


## Ext4 layout

| Volume Number | Mountpoint                    |
|---------------|-------------------------------|
| 1             | /                             |
| 1.a           | /.swapfile                    |
| 1.b           | /tmp                          |
