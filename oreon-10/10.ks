#version=DEVEL
# Firewall configuration
firewall --enabled --service=mdns
# Keyboard layouts
keyboard 'us'
# System language
lang en_US.UTF-8
# Network information
network  --bootproto=dhcp --device=link --activate
# Shutdown after installation
shutdown
# Repos
url --url="https://download.copr.fedorainfracloud.org/results/brandonlester/oreon-10/centos-stream-10-$basearch/"

repo --name="devel" --baseurl=https://raw.repo.almalinux.org/almalinux/10/devel/$basearch/os/ --excludepkgs="kpatch, kpatch-dnf, almalinux-release, anaconda, anaconda-gui, anaconda-core, anaconda-tui, anaconda-widgets, almalinux-indexhtml, almalinux-bookmarks, firefox"
repo --name="oreon" --baseurl=https://download.copr.fedorainfracloud.org/results/brandonlester/oreon-10/centos-stream-10-$basearch/
repo --name="oreonoldrepo" --baseurl=https://packages.boostyconnect.com/oreon-10/$basearch/
repo --name="oreonextras" --baseurl=https://packages.boostyconnect.com/oreon-10/extras-$basearch/
repo --name="epel" --baseurl=https://dl.fedoraproject.org/pub/epel/10/Everything/$basearch/
repo --name="base" --baseurl=https://repo.almalinux.org/almalinux/10/BaseOS/$basearch/os/ --excludepkgs="anaconda-live, kpatch, kpatch-dnf, almalinux-release, anaconda, anaconda-gui, anaconda-core, anaconda-tui, anaconda-widgets, almalinux-indexhtml, almalinux-bookmarks, firefox"
repo --name="appstream" --baseurl=https://repo.almalinux.org/almalinux/10/AppStream/$basearch/os/ --excludepkgs="anaconda-live, kpatch, kpatch-dnf, almalinux-release, anaconda, anaconda-gui, anaconda-core, anaconda-tui, anaconda-widgets, almalinux-indexhtml, almalinux-bookmarks, firefox"
repo --name="extras" --baseurl=https://repo.almalinux.org/almalinux/10/extras/$basearch/os/ --excludepkgs="anaconda-live, kpatch, kpatch-dnf, almalinux-release, anaconda, anaconda-gui, anaconda-core, anaconda-tui, anaconda-widgets, almalinux-indexhtml, almalinux-bookmarks, firefox"
repo --name="crb" --baseurl=https://repo.almalinux.org/almalinux/10/CRB/$basearch/os/ --excludepkgs="anaconda-live, kpatch, kpatch-dnf, almalinux-release, anaconda, anaconda-gui, anaconda-core, anaconda-tui, anaconda-widgets, almalinux-indexhtml, almalinux-bookmarks, firefox"
repo --name="backports" --baseurl=https://download.copr.fedorainfracloud.org/results/brandonlester/oreon-10-backports/centos-stream-9-$basearch/

# Root password
rootpw --iscrypted --lock locked
# SELinux configuration - set to enforcing because Centrio relies on the state of the live env
selinux --enforcing
# System services
services --disabled="sshd" --enabled="NetworkManager,ModemManager"
# System timezone
timezone US/Eastern
# Use network installation
url --mirrorlist="https://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=$basearch"
# X Window System configuration information
xconfig  --startxonboot
# System bootloader configuration
bootloader --location=none --append="rd.live.image quiet rhgb"
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype="ext4" --size=5120
part / --size=8576

%post
# Enable livesys services
systemctl enable livesys.service
systemctl enable livesys-late.service

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
echo "Packages within this LiveCD"
rpm -qa --qf '%{size}\t%{name}-%{version}-%{release}.%{arch}\n' |sort -rn
# Note that running rpm recreates the rpm db files which aren't needed or wanted
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

# Disable network service here, as doing it in the services line
# fails due to RHBZ #1369794
systemctl disable network

# Remove machine-id on pre generated images
rm -f /etc/machine-id
touch /etc/machine-id

%end

%post
# set livesys session type
sed -i 's/^livesys_session=.*/livesys_session="gnome"/' /etc/sysconfig/livesys

# Force GTK4 to use the stable OpenGL rendering backend to prevent Vulkan initialization crashes in the live environment
cat >> /etc/environment << 'EOF'
GSK_RENDERER=ngl
EOF

%end

# Packages
%packages
@^workstation-product-environment
@hardware-support
@multimedia
@core
@standard
@gnome-desktop
@workstation*
@anaconda-tools
centrio-installer
livesys-scripts
epel-release
fuse
systemd-resolved
xdg-utils
atheros-firmware
-setroubleshoot
-almalinux-logos
-almalinux-release
-almalinux-backgrounds
-almalinux-repos
-firefox
oreon-repos
oreon-logos
oreon-release
oreon-backgrounds
-gstreamer1-plugins-good-qt6
gnome-shell-extension-dash-to-panel-oreon
gnome-shell-extension-arc-menu-oreon
gnome-shell-extension-blur-my-shell-oreon
gnome-shell-extension-desktop-icons
gnome-shell-oreon-theming
oreon-shell-theme
kernel-devel
dracut-live
python3-crypt-r
memtest86+

%end
