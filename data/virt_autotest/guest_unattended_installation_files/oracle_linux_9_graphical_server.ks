#platform=x86, AMD64, or Intel EM64T
#version=OL9

#Do not configure any iptables rules.Open ssh service
firewall --disabled --ssh --service=ssh

#Use CDROM installation media
cdrom

##Configures additional yum repositories that may be used as sources for package installation
repo --name="AppStream" --baseurl=file:///run/install/sources/mount-0000-cdrom/AppStream

# Use text install
text --non-interactive

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System language
lang en_US.UTF-8

# System timezone
timezone America/New_York --isUtc

# SELinux configuration
selinux --disabled

# Controls the error logging of anaconda during installation. It has no effect on the installed system.
logging --level debug --host ##Logging-HostName## --port ##Logging-HostPort##

# Root password
rootpw --iscrypted $6$/2CjdguO.C2pZTYv$lk1WGy9n5Dcv.CqfxUDujzsfTgGsxgW.WerJqUzF31osEWMuiUnDvXwLnZH8cZ/SB6L/a.0AH2En/aWUZDoFv/

# Network information
network  --bootproto=dhcp --device=##Device-MacAddr## --hostname=##Host-Name## --ipv6=auto --activate

#Accept the EULA
eula --agree --accept

#Controls anaconda’s access to disks attached to the system
ignoredisk --only-use=vda

#Automatically create partitions
autopart

#Removes partitions from the system, prior to creation of new partitions
clearpart --all --initlabel --disklabel ##Disk-Label##

#If zerombr is specified, any disks whose formatting is unrecognized are initialized
zerombr

#This makes the installer step through every screen, displaying each briefly
autostep --autoscreenshot

# System bootloader configuration
bootloader --location=mbr --boot-drive=vda --timeout 8

#Modifies the default set of services that will run under the default runlevel
services --enabled sshd

#This installs a ssh key to the authorized_keys file of the specified user on the installed system
sshkey "##Authorized-Keys##" --username root

#The installer can start up ssh to provide for interactivity and inspection, just like it can with telnet
sshpw $6$/2CjdguO.C2pZTYv$lk1WGy9n5Dcv.CqfxUDujzsfTgGsxgW.WerJqUzF31osEWMuiUnDvXwLnZH8cZ/SB6L/a.0AH2En/aWUZDoFv/ --username root --iscrypted

#Determine whether the Setup Agent starts the first time the system is booted
firstboot --disabled

#Reboot after the installation is complete
reboot --eject

%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

#Use the %packages command to begin a kickstart file section that lists the packages you would like to install
%packages
@^graphical-server-environment
@debugging
@development
@graphical-admin-tools
@guest-agents
@legacy-unix
@network-server
@performance
@remote-desktop-clients
@remote-system-management
@security-tools
@system-tools
@virtualization-client
@virtualization-tools
@web-server
kexec-tools
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

%anaconda
pwpolicy root --minlen=6 --minquality=1 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=6 --minquality=1 --notstrict --nochanges --notempty
%end
