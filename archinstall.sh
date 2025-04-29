#!/bin/bash

### CONFIG - EDIT THESE! ###
TARGET_DISK="/dev/sda"   # !! DOUBLE CHECK THIS !!
HOSTNAME="archdolphin"
USERNAME="dolphin"
USER_PASSWORD="1234"     # Change this!
ROOT_PASSWORD="1234"     # Change this!
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
KEYMAP="us"

### Partitioning Setup ###
ROOT_SIZE="55GiB"
SWAP_SIZE="4GiB"
EFI_SIZE="1022MiB"

### Colors ###
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

### Safety Check ###
echo -e "${YELLOW}WARNING: This will DESTROY all data on ${TARGET_DISK}!${NC}"
lsblk
read -p "Proceed? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 1
fi

### Helper Functions ###
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

### Phase 1: Partitioning ###
info "Creating partitions..."
parted -s ${TARGET_DISK} mklabel gpt
parted -s ${TARGET_DISK} mkpart primary ext4 1MiB ${ROOT_SIZE}
parted -s ${TARGET_DISK} mkpart primary linux-swap ${ROOT_SIZE} $(echo ${ROOT_SIZE} | sed 's/GiB//' | awk '{print $1 + 4}')GiB
parted -s ${TARGET_DISK} mkpart primary fat32 $(echo ${ROOT_SIZE} | sed 's/GiB//' | awk '{print $1 + 4}')GiB 100%
parted -s ${TARGET_DISK} set 3 esp on

info "Formatting..."
mkfs.ext4 ${TARGET_DISK}1
mkswap ${TARGET_DISK}2
mkfs.fat -F32 ${TARGET_DISK}3

info "Mounting..."
mount ${TARGET_DISK}1 /mnt
mkdir -p /mnt/boot
mount ${TARGET_DISK}3 /mnt/boot
swapon ${TARGET_DISK}2

### Phase 2: Base System ###
info "Installing base system..."
pacstrap /mnt base linux linux-firmware sof-firmware nano networkmanager grub efibootmgr

info "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

### Phase 3: Chroot Configuration ###
info "Configuring system..."
arch-chroot /mnt /bin/bash <<EOF
    # Timezone
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    hwclock --systohc

    # Locale
    sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen
    locale-gen
    echo "LANG=${LOCALE}" > /etc/locale.conf
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

    # Network
    echo "${HOSTNAME}" > /etc/hostname
    systemctl enable NetworkManager

    # Users
    echo "root:${ROOT_PASSWORD}" | chpasswd
    useradd -m -G wheel -s /bin/bash ${USERNAME}
    echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    # Bootloader (GRUB)
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
EOF

### Phase 4: KDE Plasma & Essentials ###
info "Installing KDE Plasma and extras..."
arch-chroot /mnt /bin/bash <<EOF
    pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications
    pacman -S --noconfirm pipewire pipewire-pulse wireplumber alsa-utils
    pacman -S --noconfirm bluez bluez-utils cups
    systemctl enable sddm
    systemctl enable bluetooth
    systemctl enable cups
EOF

### Done! ###
info "Installation complete!"
echo -e "${GREEN}Reboot and remove the install media. Enjoy KDE Plasma! :3${NC}"
