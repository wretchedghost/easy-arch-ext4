#!/bin/bash

# This script is designed to install install the setup that is used in my i3-workstation repo

# function to check if running as root

pacman -Syyu

pacman -Sy xorg-server xorg-xinit openssh curl wget neofetch vim rsync git zip unzip urxvt-perls 

pacman -Sy i3-wm i3lock i3blocks lxappearance scrot picom feh dunst rofi conky xfce4-clipman arandr voluemicon xautolock imagemagick 

pacman -Sy ttf-bitstream-vera ttf-font-awesome ttf-dejavu ttf-monoid ttf-roboto ttf-ubuntu-font-family ttf-hack ttf-droid 

pacman -Sy firefox midori 

pacman -Sy pcmanfm gvfs gvfs-smb gvfs-mtp gvfs-mtp wine thunderbird barrier

pacman -S pipewire pipewire-alsa pipewire-pulse pavucontrol

pacman -S lightdm lightdm-slick-greeter

pacman -S android-tools cups cifs ntfs-3g nfs-utils 

# Optionals
pacman -S deluge libreoffice-still manuskript obsidian

# Yay AUR install
#

# AUR stuff

yay -S signal-browser-bin qtbrowser caffeine-ng blueberry firefox-profile-service spotify teamviewer downgrade

# AUR Theme
yay -S vimix-icon-theme vimix vimix-gtk-themes vimix-cursors
