#!/bin/bash

yay_install() {

    cd /opt
    git clone https://aur.archlinux.org/yay-git
    chown -R $username:$username ./yay-git
    cd yay-git
}

# This script is designed to install install the setup that is used in my i3-workstation repo

# function to check if running as root

pacman -Syyu

pacman -Sy xorg-server xorg-xinit openssh curl wget neofetch vim rsync git zip unzip urxvt-perls i3-wm i3lock i3blocks lxappearance scrot picom feh dunst rofi conky xfce4-clipman arandr voluemicon xautolock imagemagick ttf-bitstream-vera ttf-font-awesome ttf-dejavu ttf-monoid ttf-roboto ttf-ubuntu-font-family ttf-hack ttf-droid firefox midori pcmanfm gvfs gvfs-smb gvfs-mtp gvfs-mtp wine thunderbird barrier pipewire pipewire-alsa pipewire-pulse pavucontrol lightdm lightdm-slick-greeter android-tools cups cifs ntfs-3g nfs-utils deluge libreoffice-still manuskript obsidian

# Yay AUR install

## check to make sure you are not running as root

yay_install
makepkg -si

yay -S signal-browser-bin qtbrowser caffeine-ng blueberry firefox-profile-service spotify teamviewer downgrade

# AUR Theme
yay -S vimix-icon-theme vimix vimix-gtk-themes vimix-cursors
