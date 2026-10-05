#version=DEVEL
# X Window System configuration information
xconfig  --startxonboot
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --plaintext rootme
# System language
lang en_US.UTF-8
# Shutdown after installation
shutdown
# System timezone
timezone US/Eastern
# Network information
network  --bootproto=dhcp --device=link --activate

# Oreon repos (primary)
url --url="https://repo-us.oreonhq.com/oreon-11-rp1/testing/x86_64"
repo --name="oreon" --baseurl=https://repo-us.oreonhq.com/oreon-11-rp1/testing/x86_64
# repo --name="oreon-stt" --baseurl=https://repo-us.oreonhq.com/oreon-11-rp1/kernel-7.2.4/x86_64

firewall --enabled --service=mdns
selinux --enforcing
services --disabled="sshd" --enabled="NetworkManager"
bootloader --location=none --append="rd.live.image quiet rhgb rd.driver.pre=nouveau"
zerombr
clearpart --all --initlabel
part /boot/efi --fstype="efi" --size=200
part / --size=10238 --grow

%post

# Enable livesys services
systemctl enable livesys.service
systemctl enable livesys-late.service

# Enable plasmalogin
systemctl enable plasmalogin.service

# enable tmpfs for /tmp
systemctl enable tmp.mount

# make it so that we don't do writing to the overlay for things which
# are just tmpdirs/caches
# note https://bugzilla.redhat.com/show_bug.cgi?id=1135475
cat >> /etc/fstab << EOF
vartmp   /var/tmp    tmpfs   defaults   0  0
EOF

# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*

# go ahead and pre-make the man -k cache (#455968)
/usr/bin/mandb

# make sure there aren't core files lying around
rm -f /core*

# remove random seed, the newly installed instance should make it's own
rm -f /var/lib/systemd/random-seed

# convince readahead not to collect
# FIXME: for systemd

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

# Show liveinst.desktop on desktop and in menu
sed -i 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop
mkdir /home/liveuser/Desktop
cp -a /usr/share/applications/liveinst.desktop /home/liveuser/Desktop/liveinst.desktop
chmod +x /home/liveuser/Desktop/liveinst.desktop

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

# set livesys session type
cat > /etc/sysconfig/livesys << 'EOF'
livesys_session="kde"
EOF

# Workaround to add openvpn user and group in case they didn't added during
# openvpn package installation
getent group openvpn &>/dev/null || groupadd -r openvpn
getent passwd openvpn &>/dev/null || \
    /usr/sbin/useradd -r -g openvpn -s /sbin/nologin -c OpenVPN \
        -d /etc/openvpn openvpn

%end

%packages
@base-x
# @kde-desktop

# Core and Kernel
kernel
kernel-modules
linux-firmware
oreon-release
oreon-repos
oreon-plasmaconfig
centrio-installer
-fedora-logos
-fedora-release
oreon-logos
openssl
efitools

# Oreon Features
oreon-system-manager
root-protection
oreon-defense

# System Essentials
bash
coreutils
glibc
systemd
NetworkManager
NetworkManager-wifi
iwlwifi-mvm-firmware
iwlwifi-mld-firmware
iwlwifi-dvm-firmware
iwlegacy-firmware
libertas-firmware
realtek-firmware
nvidia-gpu-firmware
amd-gpu-firmware
intel-gpu-firmware
sudo
dracut-live
dracut-config-generic
livesys-scripts
grub2-pc-modules
shim-x64
grub2-efi-x64
grub2-efi-x64-cdboot
grub2-efi-x64-modules
grub2-tools-efi
grub2
efibootmgr
rsync
flatpak
plymouth
lvm2
snapper
boom-boot
mesa-dri-drivers
mesa-libGL
mesa-libEGL
mesa-libgbm
mesa-vulkan-drivers
vulkan-loader
libdrm
qt6-qtwayland
xorg-x11-drv-nouveau
alsa-sof-firmware
kwrite
plasma-systemmonitor
ark
libGLES
lspci
# uncomment once built below
# gparted

# Minimal KDE Plasma
plasma-desktop
plasma-workspace
kwin
plasma-login-manager
kde-settings-plasmalogin
plasma-keyboard
layer-shell-qt
konsole
dolphin
plasma-systemsettings
plasma-discover
plasma-nm
plasma-setup

# Removals
kde-connect
-tracker
-ktorrent
-hplip
-lsvpd
-powerpc-utils
-s390utils-base
-f44-backgrounds
-f44-backgrounds-kde
sssd-kcm
sssd-common
sssd
%end
