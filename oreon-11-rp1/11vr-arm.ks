#version=DEVEL
# No X setup / graphical login: the shell owns the screen (default target is set in %post)
skipx
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --plaintext rootme
# System language
lang en_US.UTF-8
# Shutdown after installation
shutdown
# System timezone
timezone America/Chicago
# Network information
network  --bootproto=dhcp --device=link --activate

# Oreon repos (primary)
url --url="https://repo-us.oreonhq.com/oreon-11-rp1/testing/aarch64"
repo --name="oreon" --baseurl=https://repo-us.oreonhq.com/oreon-11-rp1/testing/aarch64
# oreonvr-shell comes from the Oreon repo once the build service has built the spec. Until then, point a repo at
# locally built RPMs (os/out/rpms, after `createrepo_c os/out/rpms`):
# repo --name="oreonvr-local" --baseurl=file:///path/to/oreonvr/os/out/rpms

firewall --enabled --service=mdns
selinux --enforcing
services --disabled="sshd" --enabled="NetworkManager"
# plymouth off: the shell takes the display directly. ttyAMA0 is the serial console on ARM VMs/boards.
bootloader --location=none --append="rd.live.image quiet plymouth.enable=0 console=tty0 console=ttyAMA0,115200n8 rd.driver.pre=nouveau"
zerombr
clearpart --all --initlabel
part /boot/efi --fstype="efi" --size=200
part / --size=10238 --grow

%post

systemctl enable livesys.service
systemctl enable livesys-late.service

systemctl enable oreonvr-shell.service
systemctl set-default multi-user.target
systemctl mask plasmalogin.service sddm.service
systemctl --global enable oreonvr-chromium-warmup.service

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

echo 'File created by kickstart. See systemd-update-done.service(8).' \
    | tee /etc/.updated >/var/.updated

# Drop the rescue kernel and initramfs, we don't need them on the live media itself.
# See bug 1317709
rm -f /boot/*-rescue*

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

### Oreon VR ###

# The live user the shell runs its desktop as (oreonvr-pick-user uses it on the live medium)
getent passwd oreonvr &>/dev/null || useradd -m -c "Oreon VR" -G wheel,video,input,audio oreonvr
echo 'oreonvr:oreonvr' | chpasswd
cat > /etc/sudoers.d/oreonvr << 'EOF'
oreonvr ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/oreonvr
# keep its user manager (KWin, Plasma, PipeWire) running without a login
mkdir -p /var/lib/systemd/linger
touch /var/lib/systemd/linger/oreonvr

# No polkit agent runs in the headless desktop, so let wheel manage Flatpak/packages from Discover
cat > /etc/polkit-1/rules.d/50-oreonvr.rules << 'EOF'
// There is no polkit agent in the headless desktop, so let the wheel group (the Oreon VR user) manage Flatpak and
// packages from Discover without a password prompt that could never be answered.
polkit.addRule(function(action, subject) {
  if ((action.id.indexOf("org.freedesktop.Flatpak.") == 0 || action.id.indexOf("org.freedesktop.packagekit.") == 0) &&
      subject.isInGroup("wheel"))
    return polkit.Result.YES;
});
EOF

cat > /etc/xdg/plasma-welcomerc << 'EOF'
[General]
LastSeenVersion=99.0.0
EOF

cat > /usr/lib/os-release << 'EOF'
NAME="Oreon VR"
VERSION="11 (Spatial)"
ID=oreon
VERSION_ID=11
VERSION_CODENAME="Lumen"
PLATFORM_ID="platform:or11"
PRETTY_NAME="Oreon VR 11"
ANSI_COLOR="0;38;2;60;110;180"
LOGO=oreon-logo-icon
CPE_NAME="cpe:/o:oreonhq:oreon:11"
HOME_URL="https://oreonhq.com/"
DOCUMENTATION_URL="https://wiki.oreonhq.com/"
SUPPORT_URL="https://oreonhq.com/help/"
BUG_REPORT_URL="https://community.oreonhq.com/"
VARIANT="Spatial"
VARIANT_ID=oreonvr
EOF
ln -sf ../usr/lib/os-release /etc/os-release
echo 'Oreon VR 11 - based on Oreon 11' > /etc/oreonvr-release
cat > /etc/issue << 'EOF'
Oreon VR 11 - \l

The desktop is on the screen. This console is a shell.
User: oreonvr / password: oreonvr

EOF

# Surf's browser engine (Oreon's repos do not ship Chromium); needs network during the build
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --system -y --noninteractive flathub org.chromium.Chromium || \
    echo "WARNING: Chromium could not be installed; Surf will ask to install it from the Store"

restorecon -RF /etc /usr/lib/os-release /var/lib/flatpak /var/lib/systemd/linger /home/oreonvr 2>/dev/null || :

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
ffmpeg
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
shim-aa64
grub2
grub2-efi-aa64
grub2-efi-aa64-cdboot
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

# Oreon VR
oreonvr-shell
python3-pyside6
poppler-utils
xdg-utils
ffmpeg-libs
pipewire
pipewire-utils
hunspell
hunspell-en-US

# Removals
-kde-connect
-tracker
-ktorrent
-hplip
-f44-backgrounds
-f44-backgrounds-kde
-sssd-kcm
-sssd-common
-sssd
%end
