#!/bin/bash

### Jotix arch installation script

### packages for installation
BASE_PACKAGES=(base linux linux-firmware) # base / kernel

PACKAGES=(grub efibootmgr amd-ucode os-prober dosfstools) # boot tools
PACKAGES+=(man man-db man-pages texinfo base-devel) # man pages
PACKAGES+=(gvfs udisks2 file-roller) # files managment
PACKAGES+=(sudo arch-install-scripts mlocate gparted) # admin tools
PACKAGES+=(networkmanager ntp ntfs-3g netctl dialog) # networking
PACKAGES+=(qemu libvirt virt-manager ebtables dnsmasq bridge-utils openbsd-netcat) # virtualization
PACKAGES+=(xf86-video-amdgpu mesa vulkan-radeon) # graphics drivers
PACKAGES+=(xorg gnome gnome-extra picom adapta-gtk-theme) # Xorg / Desktops
PACKAGES+=(cups ghostscript gsfonts) # printing
PACKAGES+=(cowsay lolcat cmatrix neofetch chafa) # useless apps
PACKAGES+=(spotifyd playerctl pavucontrol celluloid v4l2loopback-dkms) # multimedia
PACKAGES+=(emacs git qutebrowser libreoffice gimp) # applications
PACKAGES+=(ttf-ubuntu-font-family adobe-source-code-pro-fonts ttf-roboto ttf-roboto-mono) # jotix's system fonts
PACKAGES+=(ttf-fira-code ttf-caladea ttf-carlito  ttf-dejavu ttf-liberation ttf-linux-libertine-g noto-fonts) # more fonts
PACKAGES+=(adobe-source-code-pro-fonts adobe-source-sans-pro-fonts adobe-source-serif-pro-fonts) # more fonts
PACKAGES+=(pass gnupg openssh) # security
PACKAGES+=(exa bat neovim) # gnu tools replacements

read -r -d '' LOCALES_TO_INSTALL << EOM
en_US.UTF-8 UTF-8
es_AR.UTF-8 UTF-8
EOM

read -r -d '' LOCALE_CONF << EOM
LANG=en_US.UTF-8
EOM

read -r -d '' ARDUINO_RULES << EOM
# ID 2341:0037 Arduino SA 
# copy the content of this file in /etc/udev/rules.d/51-arduino-pro-micro.rules
# Arduino Pro-Micro
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0037", MODE:="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0036", MODE:="0666"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="8037", MODE:="0666"
EOM

################################################################################
### FUNCTIONS
################################################################################

### arch-chroot
ar(){
    arch-chroot /mnt $@
}

### arch-chroot as user
aru(){
    arch-chroot -u $USER_NAME /mnt $@
}

### read y or n from keyboard
read_y_or_n(){
    INPUT=""
    while [[ "$INPUT" != "y" && "$INPUT" != "n" ]]; do
        read -p "$1 (y/n) " -n1 INPUT; echo >&2
    done
    echo $INPUT
}

### set_password "message" minimun_lenght
set_password() {
    PASS1=""
    PASS2=""
    while [[ "$PASS1" != "$PASS2" ]] || [[ ${#PASS1} < $2 ]]; do
        read -sp "$1 (minimum $2 chars): " PASS1; echo >&2
        read -sp "confirm password: " PASS2; echo >&2
        if  [[ "$PASS1" != "$PASS2" ]]; then
            echo "the passwords don't match." >&2
        elif [[ $(count_chars $PASS1) < $2 ]]; then
            echo "the password is too short." >&2
        fi
    done
}

### read_input "message" minimun_lenght
read_input() {
    INPUT=""
    while [[ ${#INPUT} < $2 ]]; do
        read -p "$1 (minimum $2 chars): " INPUT
        if [[ $(count_chars $INPUT) < $2 ]]; then
            echo "too short." >&2
        fi
    done
    echo $INPUT
}

### count characters
count_chars () {
    echo -n "$1" | wc -c
}

################################################################################
### variables
################################################################################

ROOT_PASSWORD=""
HOST_NAME=""
USER_NAME=""
USER_PASSWORD=""
EDIT_MIRRORLIST=""
ENABLE_LIBVIRT=""
ENABLE_CUPS=""
ENABLE_GDM=""

CONFIRMATION="n"
while [[ $CONFIRMATION != "y" ]]; do
    clear
    ROOT_PASSWORD=$(set_password "root password" 5)
    HOST_NAME=$(read_input "hostname" 3)
    USER_NAME=$(read_input "user name" 3)
    USER_PASSWORD=$(set_password "$USER_NAME password" 5)
    EDIT_MIRRORLIST=$(read_y_or_n "edit mirrorlist?")
    ENABLE_LIBVIRT=$(read_y_or_n "enable libvirt?")
    ENABLE_CUPS=$(read_y_or_n "enable cups?")
    ENABLE_GDM=$(read_y_or_n "enable gdm?")
    clear
    echo "Hostname: $HOST_NAME"
    echo "User Name: $USER_NAME"
    echo "Edit Mirrorlist: $EDIT_MIRRORLIST"
    echo "Enable Libvirt: $ENABLE_LIBVIRT"
    echo "Enable Cups: $ENABLE_CUPS"
    echo "Enable Gdm: $ENABLE_GDM"
    echo ""
    CONFIRMATION=$(read_y_or_n "proced with the installation?")
done

################################################################################
### install new system 
################################################################################

if [[ "$EDIT_MIRRORLIST" = "y" ]]; then
    curl -o /etc/pacman.d/mirrorlist https://www.archlinux.org/mirrorlist/all/
    vim /etc/pacman.d/mirrorlist
fi

### update the system clock
timedatectl set-ntp true

### install base system
pacstrap /mnt "${BASE_PACKAGES[@]}"
[[ $? != 0 ]] && exit

### generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

### time
ar ln -sf /usr/share/zoneinfo/America/Buenos_Aires /etc/localtime
ar hwclock --systohc

### locale
echo -e "$LOCALES_TO_INSTALL" > /mnt/etc/locale.gen
ar locale-gen
echo -e "$LOCALE_CONF" > /mnt/etc/locale.conf

### hosts
echo $HOST_NAME > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mntetc/hosts
echo "127.0.1.1 $HOST_NAME.localdomain $HOST_NAME" >> /mnt/etc/hosts

### root password
printf "$ROOT_PASSWORD\n$ROOT_PASSWORD\n" | ar passwd

### install packages
ar pacman -Sy --noconfirm --needed "${PACKAGES[@]}"
[[ $? != 0 ]] && exit

### grub
ar grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub
ar grub-mkconfig -o /boot/grub/grub.cfg

### network
ar systemctl enable NetworkManager
ar systemctl enable ntpdate

### trim
ar systemctl enable fstrim.timer

### create user
ar useradd -m -G wheel -s /bin/bash $USER_NAME
printf "$USER_PASSWORD\n$USER_PASSWORD\n" | ar passwd $USER_NAME  

### display manager
[[ "$ENABLE_GDM" == "y" ]] && ar systemctl enable gdm

### virtualization
if [[ "$ENABLE_LIBVIRT" == "y" ]]; then
    ar systemctl enable libvirtd.service
    ar usermod -a -G libvirt $USER_NAME
fi

### cups
[[ "$ENABLE_CUPS" == "y" ]] && ar systemctl enable cups.service

## arduino pro-micro udev rules
echo "$ARDUINO_RULES" > /mnt/etc/udev/rules.d/51-arduino-pro-micro.rules

### sudo
echo -e "\n\n%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers
