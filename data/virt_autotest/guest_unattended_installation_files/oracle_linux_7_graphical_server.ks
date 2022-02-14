#platform=x86, AMD64, or Intel EM64T
#version=OL7

#Install a fresh system
install

# Use CDROM installation media
cdrom

##Configures additional yum repositories that may be used as sources for package installation
repo --name="Server-HighAvailability" --baseurl=file:///run/install/repo/addons/HighAvailability
repo --name="Server-ResilientStorage" --baseurl=file:///run/install/repo/addons/ResilientStorage

# Use graphical install
text

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System language
lang en_US.UTF-8

# System timezone
timezone America/New_York --isUtc --nontp

# SELinux configuration
selinux --disabled

# System authorization information
auth --enableshadow --passalgo=sha512

# Root password
rootpw --iscrypted $6$zvl3sD3rWFqvfCba$HqhHw.yA8XUcbgWzNjTzF/4GNDwlOG4hD6wTcDepjM9Fo0rdE.orxepVc8k4at9X.IIlDc6sHQkxqbSQHEmS41

# Network information
network  --bootproto=dhcp --device=##Device-MacAddr## --hostname=##Host-Name## --ipv6=auto --activate

#Do not configure any iptables rules.Open ssh service
firewall --disabled --ssh --service=ssh

# System services
services --disabled="chronyd" --enabled="sshd"

#The installer can start up ssh to provide for interactivity and inspection, just like it can with telnet
sshpw $6$zvl3sD3rWFqvfCba$HqhHw.yA8XUcbgWzNjTzF/4GNDwlOG4hD6wTcDepjM9Fo0rdE.orxepVc8k4at9X.IIlDc6sHQkxqbSQHEmS41 --username root --iscrypted

#This installs a ssh key to the authorized_keys file of the specified user on the installed system
sshkey "##Authorized-Keys##" --username root

#Removes partitions from the system, prior to creation of new partitions
clearpart --all --initlabel --disklabel ##Disk-Label##

#Automatically create partitions
autopart

#If zerombr is specified, any disks whose formatting is unrecognized are initialized
zerombr

#This makes the installer step through every screen, displaying each briefly
autostep --autoscreenshot

#Controls the error logging of anaconda during installation. It has no effect on the installed system.
logging --level debug --host ##Logging-HostName## --port ##Logging-HostPort##

# X Window System configuration information
xconfig  --startxonboot

# System bootloader configuration
bootloader --timeout=8 --append=" crashkernel=auto"

#Determine whether the Setup Agent starts the first time the system is booted
firstboot --disabled

#Reboot after the installation is complete. Normally, kickstart displays a message and waits for the user to press a key before rebooting.
reboot --eject

#Use the %packages command to begin a kickstart file section that lists the packages you would like to install
%packages
@^graphical-server-environment
@base
@compat-libraries
@core
@desktop-debugging
@development
@dial-up
@fonts
@gnome-desktop
@guest-agents
@guest-desktop-agents
@hardware-monitoring
@input-methods
@internet-browser
@multimedia
@network-file-system-client
@performance
@print-client
@remote-system-management
@system-admin-tools
@virtualization-client
@virtualization-tools
@x11
kexec-tools
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
