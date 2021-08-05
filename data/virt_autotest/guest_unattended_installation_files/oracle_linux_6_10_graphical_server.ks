#platform=x86, AMD64, or Intel EM64T
#version=OL6

#Install a fresh system
install

#Controls which display mode will be used during installation.Use text install
text

#Install from the first CD-ROM/DVD drive on the system
cdrom

#Configures additional yum repositories that may be used as sources for package installation
repo --name="UEK4 kernel repo"  --baseurl=file://anaconda-addon

#Sets the language to use during installation and the default language to use on the installed system
lang en_US.UTF-8

#Sets system keyboard type
keyboard us

#Sets the system time zone
timezone --utc America/New_York

#If the monitor command is not given, anaconda will use X to automatically detect your monitor settings. Please try this before manually configuring your monitor.
monitor

# X Window System configuration information
xconfig  --startxonboot

#Ssets up the authentication options for the system
authconfig --enableshadow --passalgo=sha512

#Sets the system’s root password
rootpw  --iscrypted $6$Izlli1gfEmoc10.y$n02OLAwPoXqYyV5JUFyw9cgVNrs7VdwxRr4IjTXwcLoo0szfE00qy.bFAlPHuLycgIm9CdkE8paeH3KfZEUYX/

#Configures network information for target system and activates network devices in installer environment.
#The device specified in the first network command is activated automatically. Activation of the device can be also explicitly required by --activate option.
network --onboot=yes --device=##Device-MacAddr## --hostname=##Host-Name## --bootproto=dhcp --noipv6

#This option corresponds to the Firewall Configuration screen in the installation program
firewall --disabled --service=ssh

#Sets the state of SELinux on the installed system. SELinux defaults to enforcing in anaconda
selinux --disabled

#Specifies how the boot loader should be installed
bootloader --timeout 8 --append="crashkernel=auto rhgb"

#Removes partitions from the system, prior to creation of new partitions
clearpart --all --initlabel

#Automatically create partitions
autopart

#If zerombr is specified, any disks whose formatting is unrecognized are initialized
zerombr

#This makes the installer step through every screen, displaying each briefly
autostep --autoscreenshot

#Controls the error logging of anaconda during installation. It has no effect on the installed system.
logging --level debug --host ##Logging-HostName## --port ##Logging-HostPort##

#Determine whether the Setup Agent starts the first time the system is booted
firstboot --disabled

#Reboot after the installation is complete. Normally, kickstart displays a message and waits for the user to press a key before rebooting.
reboot --eject

#Use the %packages command to begin a kickstart file section that lists the packages you would like to install.
%packages
@additional-devel
@base
@client-mgmt-tools
@compat-libraries
@console-internet
@core
@debugging
@basic-desktop
@desktop-platform
@development
@directory-client
@emacs
@graphical-admin-tools
@guest-agents
@hardware-monitoring
@internet-browser
@java-platform
@large-systems
@legacy-unix
@legacy-x
@network-server
@network-file-system-client
@network-tools
@performance
@perl-runtime
@remote-desktop-clients
@server-platform
@server-platform-devel
@server-policy
@system-management
@system-admin-tools
@uek4-kernel-repo
@virtualization-client
@virtualization-platform
@virtualization-tools
@web-server
@x11
libXinerama-devel
xorg-x11-proto-devel
startup-notification-devel
libgnomeui-devel
libbonobo-devel
libXau-devel
libgcrypt-devel
popt-devel
gnome-python2-desktop
libXrandr-devel
libxslt-devel
libglade2-devel
gnutls-devel
mtools
gdisk
pax
python-dmidecode
oddjob
sgpio
device-mapper-persistent-data
systemtap-client
python-six
jpackage-utils
samba-winbind
certmonger
pam_krb5
krb5-workstation
tcp_wrappers
libXmu
dnsmasq
radvd
ebtables
lksctp-tools
perl-DBD-SQLite
scrub
crypto-utils
kernel-uek-devel
libdtrace-ctf
libvirt-java
certmonger
perl-CGI
-ql23xx-firmware
-netxen-firmware
-bfa-firmware
-rt73usb-firmware
-iwl5150-firmware
-iwl100-firmware
-iwl6050-firmware
-iwl6000g2a-firmware
-ql2200-firmware
-iwl3945-firmware
-rt61pci-firmware
-iwl4965-firmware
-ql2500-firmware
-iwl6000-firmware
-libertas-usb8388-firmware
-ivtv-firmware
-ql2100-firmware
-iwl5000-firmware
-ql2400-firmware
-iwl1000-firmware
-kernel-firmware
%end

#You have the option of adding commands to run on the system once the installation is complete.
#This section must be at the end of the kickstart file and must start with the %post command. 
#This section is useful for functions such as installing additional software and configuring an additional nameserver.
%post
cd
umask 077
mkdir -p /root/.ssh
touch /root/.ssh/authorized_keys
echo >> /root/.ssh/authorized_keys
echo "##Authorized-Keys##" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
%end
