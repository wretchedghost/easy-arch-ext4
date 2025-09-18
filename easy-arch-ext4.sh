#!/usr/bin/env -S bash -e

# Fixing annoying issue that breaks GitHub Actions
# shellcheck disable=SC2001

# Cleaning the TTY.
clear

# Cosmetics (colors for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'  
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print () {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print () {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print () {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Critical error handler (function).
critical_error () {
    error_print "CRITICAL ERROR: $1"
    error_print "Installation cannot continue. System state may be inconsistent."
    exit 1
}

# Check if packages exist before installation (function).
check_packages () {
    local packages=("$@")
    info_print "Verifying package availability..."
    for pkg in "${packages[@]}"; do
        if ! pacman -Ss "^${pkg}$" &>/dev/null; then
            error_print "Package '$pkg' not found in repositories"
            return 1
        fi
    done
    info_print "All packages verified successfully"
    return 0
}

# Check internet connectivity (function).
check_internet () {
    info_print "Checking internet connectivity..."
    if ! ping -c 3 8.8.8.8 &>/dev/null; then
        error_print "No internet connection detected"
        return 1
    fi
    info_print "Internet connection verified"
    return 0
}

# Backup function for timezone setup (function).
setup_timezone () {
    info_print "Setting up timezone..."
    
    # Try to get timezone from internet first
    if timezone=$(curl -s --connect-timeout 10 http://ip-api.com/line?fields=timezone 2>/dev/null) && [[ -n "$timezone" ]]; then
        if [[ -f "/usr/share/zoneinfo/$timezone" ]]; then
            ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
            info_print "Timezone set to: $timezone"
            return 0
        fi
    fi
    
    # Fallback to UTC if internet fails
    error_print "Could not determine timezone automatically, falling back to UTC"
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    info_print "Timezone set to: UTC (you can change this later with 'timedatectl set-timezone')"
    return 0
}

# Virtualization check (function). 
virt_check () {     
    hypervisor=$(systemd-detect-virt)     
    case $hypervisor in         
        kvm )   info_print "KVM has been detected, setting up guest tools."                 
            if ! pacstrap /mnt qemu-guest-agent &>/dev/null; then
                error_print "Failed to install qemu-guest-agent"
                return 1
            fi
            systemctl enable qemu-guest-agent --root=/mnt &>/dev/null                 
            ;;         
        vmware  )   info_print "VMWare Workstation/ESXi has been detected, setting up guest tools."                     
            if ! pacstrap /mnt open-vm-tools >/dev/null; then
                error_print "Failed to install open-vm-tools"
                return 1
            fi
            systemctl enable vmtoolsd --root=/mnt &>/dev/null                     
            systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null                     
            ;;         
        oracle )    info_print "VirtualBox has been detected, setting up guest tools."                     
            if ! pacstrap /mnt virtualbox-guest-utils &>/dev/null; then
                error_print "Failed to install virtualbox-guest-utils"
                return 1
            fi
            systemctl enable vboxservice --root=/mnt &>/dev/null                     
            ;;         
        microsoft ) info_print "Hyper-V has been detected, setting up guest tools."                     
            if ! pacstrap /mnt hyperv &>/dev/null; then
                error_print "Failed to install hyperv"
                return 1
            fi
            systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null                     
            systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null                     
            systemctl enable hv_vss_daemon --root=/mnt &>/dev/null                     
            ;;     
    esac 
}

# Selecting a kernel to install (function).
kernel_selector () {
    info_print "List of kernels:"
    info_print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied."
    info_print "2) Hardened: A security-focused Linux kernel. Forgoes the GLIBC for MUSL LIBC which is lighter on resources than GLIBC but GLIBC is faster."
    info_print "3) Longterm: Long-term support (LTS) Linux kernel. Older hardware but also for more stablility."
    info_print "4) Zen Kernel: A Linux kernel optimized for desktop usage. I would suggest if you run on modern hardware."
    input_print "Please select the number of the corresponding kernel (e.g. 1): " 
    read -r kernel_choice
    case $kernel_choice in
        1 ) kernel="linux"
            return 0;;
        2 ) kernel="linux-hardened"
            return 0;;
        3 ) kernel="linux-lts"
            return 0;;
        4 ) kernel="linux-zen"
            return 0;;
        * ) error_print "You did not enter a valid selection, please try again."
            return 1
    esac
}

# Selecting a way to handle internet connection (function).
network_selector () {
    info_print "Network utilities:"
    info_print "1) IWD: Utility to connect to networks written by Intel (WiFi-only, built-in DHCP client)"
    info_print "2) NetworkManager: Universal network utility (both WiFi and Ethernet, highly recommended)"
    info_print "3) wpa_supplicant: Utility with support for WEP and WPA/WPA2 (WiFi-only, DHCPCD will be automatically installed)"
    info_print "4) dhcpcd: Basic DHCP client (Ethernet connections or VMs)"
    info_print "5) I will do this on my own (only advanced users)"
    input_print "Please select the number of the corresponding networking utility (e.g. 1): "
    read -r network_choice
    if ! ((1 <= network_choice <= 5)); then
        error_print "You did not enter a valid selection, please try again."
        return 1
    fi
    return 0
}

# Installing the chosen networking method to the system (function).
network_installer () {
    case $network_choice in
        1 ) info_print "Installing and enabling IWD."
            if ! pacstrap /mnt iwd >/dev/null; then
                error_print "Failed to install IWD"
                return 1
            fi
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        2 ) info_print "Installing and enabling NetworkManager."
            if ! pacstrap /mnt networkmanager >/dev/null; then
                error_print "Failed to install NetworkManager"
                return 1
            fi
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        3 ) info_print "Installing and enabling wpa_supplicant and dhcpcd."
            if ! pacstrap /mnt wpa_supplicant dhcpcd >/dev/null; then
                error_print "Failed to install wpa_supplicant and dhcpcd"
                return 1
            fi
            systemctl enable wpa_supplicant --root=/mnt &>/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
        4 ) info_print "Installing dhcpcd."
            if ! pacstrap /mnt dhcpcd >/dev/null; then
                error_print "Failed to install dhcpcd"
                return 1
            fi
            systemctl enable dhcpcd --root=/mnt &>/dev/null
    esac
}

# User enters a password for the LUKS Container (function).
lukspass_selector () {
    input_print "Please enter a password for the LUKS container (you're not going to see the password): "
    read -r -s password
    if [[ -z "$password" ]]; then
        echo
        error_print "You need to enter a password for the LUKS Container, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password for the LUKS container again (you're not going to see the password): "
    read -r -s password2
    echo
    if [[ "$password" != "$password2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the user account (function).
userpass_selector () {
    input_print "Please enter name for a user account (enter empty to not create one): "
    read -r username
    if [[ -z "$username" ]]; then
        return 0
    fi
    input_print "Please enter a password for $username (you're not going to see the password): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        echo
        error_print "You need to enter a password for $username, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        echo
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the root account (function).
rootpass_selector () {
    input_print "Please enter a password for the root user (you're not going to see it): "
    read -r -s rootpass
    if [[ -z "$rootpass" ]]; then
        echo
        error_print "You need to enter a password for the root user, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): " 
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Microcode detector (function).
microcode_detector () {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        microcode="amd-ucode"
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        microcode="intel-ucode"
    fi
}

# User enters a hostname (function).
hostname_selector () {
    input_print "Please enter the hostname: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

# User chooses the locale (function).
locale_selector () {
    input_print "Please insert the locale you use (format: xx_XX. Enter empty to use en_US, or \"/\" to search locales): " locale
    read -r locale
    case "$locale" in
        '') locale="en_US.UTF-8"
            info_print "$locale will be the default locale."
            return 0;;
        '/') sed -E '/^# +|^#$/d;s/^#| *$//g;s/ .*/ (Charset:&)/' /etc/locale.gen | less -M
                clear
                return 1;;
        *)  if ! grep -q "^#\?$(sed 's/[].*[]/\\&/g' <<< "$locale") " /etc/locale.gen; then
                error_print "The specified locale doesn't exist or isn't supported."
                return 1
            fi
            return 0
    esac
}

# User chooses the console keyboard layout (function).
keyboard_selector () {
    input_print "Please insert the keyboard layout to use in console (enter empty to use US, or \"/\" to look up for keyboard layouts): "
    read -r kblayout
    case "$kblayout" in
        '') kblayout="us"
            info_print "The standard US keyboard layout will be used."
            return 0;;
        '/') localectl list-keymaps
             clear
             return 1;;
        *) if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
               error_print "The specified keymap doesn't exist."
               return 1
           fi
        info_print "Changing console layout to $kblayout."
        loadkeys "$kblayout"
        return 0
    esac
}

# Pre-flight checks function
preflight_checks () {
    info_print "Running pre-flight checks..."
    
    # Check internet connectivity
    if ! check_internet; then
        error_print "Internet connection required for installation"
        return 1
    fi
    
    # Update package databases
    info_print "Updating package databases..."
    if ! pacman -Sy; then
        error_print "Failed to update package databases"
        return 1
    fi
    
    # Check if all required packages are available
    local base_packages=("base" "linux-firmware" "grub" "rsync" "efibootmgr" "sudo" "vim" "git" "neofetch" "bash-completion")
    if ! check_packages "${base_packages[@]}"; then
        error_print "Some required packages are not available"
        return 1
    fi
    
    info_print "Pre-flight checks completed successfully"
    return 0
}

# Welcome screen.
echo -ne "${BOLD}${BYELLOW}
=============================================================================================================
███████╗ █████╗ ███████╗██╗   ██╗      █████╗ ██████╗  ██████╗██╗  ██╗      ███████╗██╗  ██╗████████╗██╗  ██╗
██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝     ██╔══██╗██╔══██╗██╔════╝██║  ██║      ██╔════╝╚██╗██╔╝╚══██╔══╝██║  ██║
█████╗  ███████║███████╗ ╚████╔╝█████╗███████║██████╔╝██║     ███████║█████╗█████╗   ╚███╔╝    ██║   ███████║
██╔══╝  ██╔══██║╚════██║  ╚██╔╝ ╚════╝██╔══██║██╔══██╗██║     ██╔══██║╚════╝██╔══╝   ██╔██╗    ██║   ╚════██║
███████╗██║  ██║███████║   ██║        ██║  ██║██║  ██║╚██████╗██║  ██║      ███████╗██╔╝ ██╗   ██║        ██║
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝        ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝      ╚══════╝╚═╝  ╚═╝   ╚═╝        ╚═╝
=============================================================================================================
${RESET}"
info_print "Welcome to easy-arch, a script made in order to simplify the process of installing Arch Linux."
info_print "This script must be run on an EFI system. BIOS will not work. Checking now..."
sleep 2s

if [ -d /sys/firmware/efi ]; then 
    echo "System is running UEFI mode. The script will continue." 
else 
    echo "System is running in BIOS mode. Script will close now."
    exit 0
fi

# Run pre-flight checks before any destructive operations
if ! preflight_checks; then
    critical_error "Pre-flight checks failed"
fi

# Setting up keyboard layout.
until keyboard_selector; do : ; done

# Set up time
timedatectl set-ntp true

# Choosing the target for the installation.
info_print "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd|mmc");
do
    DISK="$ENTRY"
    info_print "Arch Linux will be installed on the following disk: $DISK"
    break
done

# Setting up LUKS password.
until lukspass_selector; do : ; done

# Setting up the kernel.
until kernel_selector; do : ; done

# Check if selected kernel package exists
if ! check_packages "$kernel" "${kernel}-headers"; then
    critical_error "Selected kernel '$kernel' is not available"
fi

# User choses the network.
until network_selector; do : ; done

# User choses the locale.
until locale_selector; do : ; done

# User choses the hostname.
until hostname_selector; do : ; done

# User sets up the user/root passwords.
until userpass_selector; do : ; done
until rootpass_selector; do : ; done

# Warn user about deletion of old partition scheme.
input_print "This will delete the current partition table on $DISK once installation starts. Do you agree [y/N]?: "
read -r disk_response
if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Quitting."
    exit
fi

# === POINT OF NO RETURN ===
info_print "=== STARTING DESTRUCTIVE OPERATIONS ==="

info_print "Wiping $DISK."
if ! wipefs -af "$DISK" &>/dev/null; then
    critical_error "Failed to wipe disk $DISK"
fi
if ! sgdisk -Zo "$DISK" &>/dev/null; then
    critical_error "Failed to initialize GPT on $DISK"
fi

# Creating a new partition scheme.
info_print "Creating the partitions on $DISK."
if ! parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 550MiB \
    set 1 esp on \
    mkpart CRYPTROOT 550MiB 100%; then
    critical_error "Failed to create partitions on $DISK"
fi

ESP="/dev/disk/by-partlabel/ESP"
CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"

# Informing the Kernel of the changes.
info_print "Informing the Kernel about the disk changes."
if ! partprobe "$DISK"; then
    critical_error "Failed to inform kernel of partition changes"
fi

# Wait for devices to be available
sleep 2
if [[ ! -e "$ESP" ]] || [[ ! -e "$CRYPTROOT" ]]; then
    critical_error "Partition devices not found after creation"
fi

# Formatting the ESP as FAT32.
info_print "Formatting the EFI Partition as vFAT32."
if ! mkfs.vfat -F32 "$ESP" &>/dev/null; then
    critical_error "Failed to format EFI partition"
fi

# Creating a LUKS Container for the root partition.
info_print "Creating LUKS Container for the root partition."
if ! echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d - &>/dev/null; then
    critical_error "Failed to create LUKS container"
fi
if ! echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d -; then
    critical_error "Failed to open LUKS container"
fi
fs_ext4="/dev/mapper/cryptroot"

# Formatting the LUKS Container as EXT4.
info_print "Formatting the LUKS container as EXT4."
if ! mkfs.ext4 "$fs_ext4" &>/dev/null; then
    critical_error "Failed to format root filesystem"
fi
if ! mount "$fs_ext4" /mnt; then
    critical_error "Failed to mount root filesystem"
fi

if ! mkdir /mnt/boot; then
    critical_error "Failed to create boot directory"
fi
if ! mount "$ESP" /mnt/boot/; then
    critical_error "Failed to mount boot partition"
fi

# Checking the microcode to install.
microcode_detector

# Setup the swapfile
info_print "Setting up a swapfile. What size do you want in MB? (ie 16384 = 16G, 24576 = 24G, or 32768 = 32G)"
sleep 1s
while :; do
    read -ep 'Swapfile Size: ' swap_response
    [[ $swap_response =~ ^[[:digit:]]+$ ]] || continue
    (( ( (swap_response=(10#$swap_response)) <= 99999 ) && swap_response >= 0 )) || continue
    break
done

if ! dd if=/dev/zero of=/mnt/.swapfile bs=1M count=$swap_response status=progress; then
    error_print "Failed to create swapfile, continuing without swap"
else
    chmod 600 /mnt/.swapfile
    if ! mkswap /mnt/.swapfile; then
        error_print "Failed to format swapfile, continuing without swap"
    elif ! swapon /mnt/.swapfile; then
        error_print "Failed to enable swapfile, continuing without swap"
    fi
fi

# Pacstrap (setting up a base sytem onto the new root).
info_print "Installing the base system (this may take a while)."
sleep 3s
if ! pacstrap -K /mnt base "$kernel" "$microcode" linux-firmware "$kernel"-headers grub rsync efibootmgr sudo vim git neofetch bash-completion; then
    critical_error "Failed to install base system packages"
fi

# Setting up the hostname.
if ! echo "$hostname" > /mnt/etc/hostname; then
    critical_error "Failed to set hostname"
fi

# Generating /etc/fstab.
info_print "Generating a new fstab."
if ! genfstab -U /mnt >> /mnt/etc/fstab; then
    critical_error "Failed to generate fstab"
fi

# Setup tmpfs in /mnt/etc/fstab.
info_print "Generating a tmpfs with the size of 8G. This size can be changed at anytime but please perform a reboot after the change to make sure things don't get wonky. noatime is disabled as default as this is not preferred to have enabled with an NVMe drive. For a SSD you SHOULD enable noatime."
sleep 3s
if ! echo "tmpfs /tmp    tmpfs   rw,nodev,nosuid,size=8G,mode=1700 0 0" >> /mnt/etc/fstab; then
    error_print "Failed to add tmpfs to fstab"
fi

# Configure selected locale and console keymap
if ! sed -i "/^#$locale/s/^#//" /mnt/etc/locale.gen; then
    error_print "Failed to configure locale in locale.gen"
fi
if ! echo "LANG=$locale" > /mnt/etc/locale.conf; then
    error_print "Failed to set locale.conf"
fi
if ! echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf; then
    error_print "Failed to set vconsole.conf"
fi

# Setting hosts file.
info_print "Setting hosts file."
if ! cat > /mnt/etc/hosts <<EOF; then
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF
    error_print "Failed to set hosts file"
fi

# Virtualization check.
if ! virt_check; then
    error_print "Virtualization setup failed, continuing anyway"
fi

# Setting up the network.
if ! network_installer; then
    critical_error "Failed to install network components"
fi

# Configuring /etc/mkinitcpio.conf.
info_print "Configuring /etc/mkinitcpio.conf."
if ! cat > /mnt/etc/mkinitcpio.conf <<EOF; then
HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)
EOF
    critical_error "Failed to configure mkinitcpio"
fi

# Setting up LUKS2 encryption in grub.
info_print "Setting up grub config."
UUID=$(blkid -s UUID -o value $CRYPTROOT)
if [[ -z "$UUID" ]]; then
    critical_error "Failed to get UUID for LUKS partition"
fi
if ! sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",&cryptdevice=UUID=$UUID:cryptroot," /mnt/etc/default/grub; then
    critical_error "Failed to configure GRUB for LUKS"
fi

# Configuring the system.
info_print "Configuring the system (timezone, system clock, initramfs, GRUB)."
if ! arch-chroot /mnt /bin/bash -e << EOF; then
    critical_error "Failed to configure system in chroot"
fi

    # Setting up timezone.
    $(declare -f setup_timezone)
    setup_timezone

    # Setting up clock.
    hwclock --systohc

    # Generating locales.
    locale-gen &>/dev/null

    # Generating a new initramfs.
    mkinitcpio -P &>/dev/null

    # Installing GRUB.
    grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=ARCHLINUX &>/dev/null

    # Creating grub config file.
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null

EOF

# Setting root password.
info_print "Setting root password."
if ! echo "root:$rootpass" | arch-chroot /mnt chpasswd; then
    critical_error "Failed to set root password"
fi

# Setting user password.
if [[ -n "$username" ]]; then
    if ! echo "%wheel ALL=(ALL:ALL) ALL" > /mnt/etc/sudoers.d/wheel; then
        error_print "Failed to configure sudo"
    fi
    info_print "Adding the user $username to the system with root privilege."
    if ! arch-chroot /mnt useradd -m -G wheel,power -s /bin/bash "$username"; then
        error_print "Failed to create user $username"
    else
        info_print "Setting user password for $username."
        if ! echo "$username:$userpass" | arch-chroot /mnt chpasswd; then
            error_print "Failed to set password for $username"
        fi
    fi
fi

# Pacman eye-candy features and multilib.
info_print "Enabling colors, animations, and parallel downloads for pacman."
if ! sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf; then
    error_print "Failed to configure pacman colors"
fi

if ! printf '[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /mnt/etc/pacman.conf; then
    error_print "Failed to enable multilib repository"
fi

# Finishing up.
info_print "Installation completed successfully!"
info_print "You may now reboot into your new Arch Linux system."
info_print "Don't forget to remove the installation media before rebooting."
exit
