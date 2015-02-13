use base "installbasetest";
use strict;
use testapi;

sub key_round($$) {
    my ($tag, $key) = @_;

    my $counter = 10;
    while ( !check_screen( $tag, 1 ) ) {
        send_key $key;
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

sub createhavm($) {
    my ($nodenum) = @_;
    script_run "qemu-img create -f qcow2 node$nodenum.img 10G";
    my $nodemac = 6+$nodenum;
    type_string "su -c 'qemu-kvm -m 1024 -vga cirrus -drive file=node$nodenum.img,id=hd1 -cdrom /dev/sr0 -drive if=scsi,id=addon_1,file=/dev/sr1,media=cdrom -drive if=scsi,id=addon_2,file=/dev/sr2,media=cdrom -drive if=scsi,id=addon_3,file=/dev/sr3,media=cdrom -vnc :9$nodenum,share=force-shared -netdev bridge,id=hn0 -device virtio-net,netdev=hn0,mac=52:54:00:12:34:5$nodemac &'\n";
    type_string "nots3cr3t\n";
    sleep 5;
    type_string "vncviewer localhost:9$nodenum -shared -fullscreen\n";
    assert_screen "inst-bootmenu", 15;
    key_round 'inst-oninstallation', 'down';
    type_string "ssh=1 ";
    type_string "sshpassword=openqaha ";
    type_string "netsetup=dhcp,all ", 13;
    assert_screen "inst-ssh-typed", 13;
    send_key 'ret';
    assert_screen "inst-ssh-ready", 240;
    send_key 'f8';
    send_key 'down';
    send_key 'ret';
    send_key 'ctrl-l'
}

sub run() {
    assert_and_click 'proxy-terminator-ha-icon';
    send_key 'ret';
    assert_screen 'proxy-terminator-started';
    send_key 'ctrl-pgup';
    send_key 'ctrl-pgup';
    for my $i ( 1 .. 3 ) {
        createhavm "$i";
    }
}

1;
