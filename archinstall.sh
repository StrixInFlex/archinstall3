#!/bin/bash

# ~(˘▾˘~) Arch Linux Install Script (~˘▾˘)~
# Fully automates UEFI install with KDE Plasma!
# Usage: curl -sL tinyurl.com/dolphin-arch | bash

### (=^･ω･^=) Configuration - EDIT ME! (=^･ω･^=) ###
TARGET_DISK="/dev/sda"   # (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ Check with 'lsblk' plz!
HOSTNAME="archdolphin"
USERNAME="dolphin"
USER_PASSWORD="1234"     # (╯°□°）╯ Change this!
ROOT_PASSWORD="1234"     # (╯°□°）╯ Change this too!
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"

### (◕‿◕✿) Partitioning Setup ###
ROOT_SIZE="55GiB"        # sda1 - Root partition
SWAP_SIZE="4GiB"         # sda2 - Swap
EFI_SIZE="1022MiB"       # sda3 - EFI

### (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ Colors for pretty output ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

### (•̀ᴗ•́)و Safety Check ###
echo -e "${YELLOW}WARNING: This will NUKE all data on ${TARGET_DISK}!${NC}"
lsblk
read -p "Are you a cute dolphin ready to proceed? (^・ω・^ ) (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Installation aborted by user! (´• ω •`)ﾉ${NC}"
    exit 1
fi

### (ง •̀_•́)ง Helper Functions ###
info() { echo -e "${GREEN}[♡INFO♡]${NC} $1"; }
warn() { echo -e "${YELLOW}[♡WARN♡]${NC} $1"; }
error() { echo -e "${RED}[♡ERROR♡]${NC} $1"; exit 1; }

### Phase 1: (╯°□°）╯︵ Partitioning Magic ###
info "Creating partitions with dolphin precision..."
parted -s ${TARGET_DISK} mklabel gpt || error "Failed to create GPT table!"
parted -s ${TARGET_DISK} mkpart primary ext4 1MiB ${ROOT_SIZE} || error "Failed to create root partition!"
parted -s ${TARGET_DISK} mkpart primary linux-swap ${ROOT_SIZE} 59GiB || error "Failed to create swap!"
parted -s ${TARGET_DISK} mkpart primary fat32 59GiB 60GiB || error "Failed to create EFI!"
parted -s ${TARGET_DISK} set 3 esp on || error "Failed to set ESP flag!"

info "Formatting with dolphin sparkles ✨..."
mkfs.ext4 ${TARGET_DISK}1 || error "Failed to format root!"
mkswap ${TARGET_DISK}2 || error "Failed to format swap!"
mkfs.fat -F32 ${TARGET_DISK}3 || error "Failed to format EFI!"

info "Mounting everything neatly..."
mount ${TARGET_DISK}1 /mnt || error "Failed to mount root!"
mkdir -p /mnt/boot || error "Failed to create boot dir!"
mount ${TARGET_DISK}3 /mnt/boot || error "Failed to mount EFI!"
swapon ${TARGET_DISK}2 || error "Failed to enable swap!"

### Phase 2: (ﾉ´ヮ`)ﾉ*: ･ﾟ Pacman Party ###
info "Getting fresh Arch mirrors for speedy downloads..."
pacman -Sy --noconfirm reflector || warn "Mirror update failed, but we'll proceed!"
reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

info "Installing the base system (≧◡≦)..."
pacstrap /mnt base linux linux-firmware sof-firmware nano networkmanager grub efibootmgr || error "Pacstrap failed!"

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || error "Fstab generation failed!"

### Phase 3: (◠‿◠✿) Chroot Config ###
info "Entering chroot dolphin dance..."
arch-chroot /mnt /bin/bash <<EOF
    # ʕ•ᴥ•ʔ Time & Language
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime || exit 1
    hwclock --systohc || warn "HW clock sync failed!"
    sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen || exit 1
    locale-gen || exit 1
    echo "LANG=${LOCALE}" > /etc/locale.conf || exit 1
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf || exit 1

    # (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ Network
    echo "${HOSTNAME}" > /etc/hostname || exit 1
    systemctl enable NetworkManager || warn "Failed to enable NetworkManager!"

    # (｡♥‿♥｡) Users
    echo "root:${ROOT_PASSWORD}" | chpasswd || exit 1
    useradd -m -G wheel -s /bin/bash ${USERNAME} || exit 1
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd || exit 1
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || exit 1

    # (╯°□°）╯︵ GRUB
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || exit 1
    grub-mkconfig -o /boot/grub/grub.cfg || exit 1
EOF

### Phase 4: (✿ ♥‿♥) KDE Plasma & Goodies ###
info "Installing KDE Plasma and dolphin essentials..."
arch-chroot /mnt /bin/bash <<EOF
    # ヽ(・ω・)ﾉ Desktop Environment
    pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications || exit 1

    # ♪~ ᕕ(ᐛ)ᕗ Multimedia
    pacman -S --noconfirm pipewire pipewire-pulse wireplumber alsa-utils || warn "Audio setup failed!"

    # (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ Utilities
    pacman -S --noconfirm bluez bluez-utils cups || warn "Bluetooth/printing failed!"

    # (•̀ᴗ•́)و Enable Services
    systemctl enable sddm || warn "SDDM failed!"
    systemctl enable bluetooth || warn "Bluetooth failed!"
    systemctl enable cups || warn "Printing failed!"

    # (ﾉ>ω<)ﾉ AUR/yay
    pacman -S --noconfirm git base-devel || warn "Development tools failed!"
    sudo -u ${USERNAME} git clone https://aur.archlinux.org/yay.git /home/${USERNAME}/yay || exit 1
    cd /home/${USERNAME}/yay || exit 1
    sudo -u ${USERNAME} makepkg -si --noconfirm || warn "Yay installation failed!"
EOF

### (ﾉ◕ヮ◕)ﾉ*:･ﾟ✧ Installation Complete! ###
echo -e "${GREEN}
   Installation complete! (ﾉ´ヮ`)ﾉ*: ･ﾟ
   -----------------------------------
   Hostname: ${HOSTNAME}
   Username: ${USERNAME}
   Password: ${USER_PASSWORD} (Change me!)
   
   1. Type 'reboot' to restart
   2. Remove installation media
   3. Login to KDE Plasma!
   
   Need help? Check Arch Wiki! (^・ω・^ )
${NC}"
