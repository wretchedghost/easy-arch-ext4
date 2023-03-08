## Details

[easy-arch-ext4](https://git.wretchednet.com/wretchedghost/easy-arch-ext4) is a **bash script** that boostraps [Arch Linux](https://archlinux.org/) with even more sane defaults.

- **ext4**: Easy to work with filesystem that just works.
- **LUKS2 encryption**: Your data will live on a LUKS2 partition protected by a password
- **Swapfile**: Built in / at /.swapfile. Default is 8GB but can be changed to any size desired, just make sure to reboot after chaning the .swapfile size in /etc/fstab.
- **Bash**: Built on bash but zsh can be installed if desired.
- **User setup**: You'll be walked through the process of setting up a default user account with sudo permissions

## Pull

```bash 
git clone https://git.wretchednet.com/wretchedghost/easy-arch-ext4
cd easy-arch-ext4
chmod +x easy-arch.sh
bash easy-arch.sh
```

## Partitions layout 

The **partitions layout** is simple and it consists of only two partitions:
1. A **FAT32** partition (550MiB), mounted at `/boot/` as ESP.
2. A **LUKS2 encrypted container**, which takes the rest of the disk space, mounted at `/` as root.

| Partition Number | Label     | Size              | Mountpoint     | Filesystem              |
|------------------|-----------|-------------------|----------------|-------------------------|
| 1                | ESP       | 512 MiB           | /boot/         | FAT32                   |
| 2                | CRYPTROOT | Rest of the disk  | /              | EXT4 Encrypted (LUKS2) |


## Ext4 layout

| volume Number | Mountpoint                    |
|---------------|-------------------------------|
| 1             | /                             |

