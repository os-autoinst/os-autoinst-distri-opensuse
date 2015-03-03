use base "installbasetest";
use testapi;
use autotest;

sub connectssh($) {
    my ($nodenum) = @_;
    my $nodeip = 5+$nodenum; 
    type_string "ssh 10.0.2.1$nodeip -l root\n";
    sleep 10;
    type_string "yes\n";
    sleep 10;
    type_string "nots3cr3t\n";
    sleep 10;
    check_screen 'ha-ssh-login', 40; #should be assert
    send_key 'ctrl-l';
}

sub startvm($) {
    my ($nodenum) = @_;
    my $nodemac = 6+$nodenum;
    type_string "su -c 'qemu-kvm -m 1024 -vga cirrus -drive file=node$nodenum.img,id=hd1 -cdrom /dev/sr0 -drive if=scsi,id=addon_1,file=/dev/sr1,media=cdrom -drive if=scsi,id=addon_2,file=/dev/sr2,media=cdrom -drive if=scsi,id=addon_3,file=/dev/sr3,media=cdrom -vnc :9$nodenum,share=force-shared -netdev bridge,id=hn0 -device virtio-net,netdev=hn0,mac=52:54:00:12:34:5$nodemac &'\n";
    sleep 5;
    type_string "nots3cr3t\n";
    sleep 5;
    send_key 'ctrl-l';
}

sub fixvmnetwork($) {
    my ($nodenum) = @_;
    type_string "vncviewer localhost:9$nodenum -shared -fullscreen\n"; #screen check
    check_screen 'vm-login', 40; #screen check
    type_string "root\n";
    sleep 5;
    type_string "nots3cr3t\n";
    sleep 5;
    type_string "sed -i 's/eth0/eth1/g' /etc/sysconfig/network/ifcfg-*\n";
    sleep 5;
    type_string "/etc/init.d/network restart\n";
    sleep 10;
    type_string "exit\n";
    send_key 'f8'; #screen check
    send_key 'down'; #screen check
    send_key 'ret'; #screen check
    sleep 5;
    send_key 'ctrl-l';
}

sub rebootvm($) {
my ($nodenum) = @_;
    type_string "vncviewer localhost:9$nodenum -shared -fullscreen\n"; #screen check
    check_screen 'vm-login', 40; #screen check
    type_string "root\n";
    sleep 5;
    type_string "nots3cr3t\n";
    sleep 5;
    type_string "chkconfig sshd on\n";
    sleep 5;
    type_string "init 6\n";
    send_key 'f8'; #screen check
    send_key 'down'; #screen check
    send_key 'ret'; #screen check
    sleep 5;
    send_key 'ctrl-l';
}

sub run() {
    # TODO - Make this your snapshot,  this is where you want to restart every time you need to re-run HA validation
    type_string "cp node1.img node2.img && cp node1.img node3.img\n"; #copy disk image two new imgs
    assert_screen 'ha-copy-finished', 500;
    for my $i ( 1 .. 3 ) {
        startvm "$i";
    }
    sleep 120; # give them all time to boot up
    for my $i ( 2 .. 3 ) {
        fixvmnetwork "$i";
    }
    for my $i ( 1 .. 3 ) {
        rebootvm "$i";
    }
    sleep 120; # give them all time to reboot
    #FIXME - quick hack
    type_string "ssh 10.0.2.16 -l root\n";
    sleep 10;
    type_string "nots3cr3t\n";
    sleep 10;
    check_screen 'ha-ssh-login', 40; #should be assert
    send_key 'ctrl-l';
    send_key 'ctrl-pgdn';
    for my $i ( 2.. 3 ) { #should be 1-3, see above FIXME
        connectssh "$i";
        send_key 'ctrl-pgdn';
    }
    send_key 'ctrl-alt-g';
    type_string "zypper -n in yast2-iscsi-client open-iscsi\n";
    sleep 60; # Give it some time to do the install
    type_string "echo '10.0.2.16    node1' >> /etc/hosts\n";
    type_string "echo '10.0.2.17    node2' >> /etc/hosts\n";
    type_string "echo '10.0.2.18    node3' >> /etc/hosts\n";
    send_key 'shift-ctrl-alt-g';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c879' > /etc/iscsi/initiatorname.iscsi\n";
    type_string "echo 'node1' > /etc/hostname\n";
    type_string "echo 'node1' > /etc/HOSTNAME\n";
    type_string "hostname node1\n";
    send_key 'ctrl-pgdn';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c878' > /etc/iscsi/initiatorname.iscsi\n";
    type_string "echo 'node2' > /etc/hostname\n";
    type_string "echo 'node2' > /etc/HOSTNAME\n";
    type_string "hostname node2\n";
    send_key 'ctrl-pgdn';
    type_string "echo 'InitiatorName=iqn.1996-04.de.suse:01:8f4aff8c877' > /etc/iscsi/initiatorname.iscsi\n";
    type_string "echo 'node3' > /etc/hostname\n";
    type_string "echo 'node3' > /etc/HOSTNAME\n";
    type_string "hostname node3\n";
    send_key 'ctrl-pgup';
    send_key 'ctrl-pgup';
}

1;
