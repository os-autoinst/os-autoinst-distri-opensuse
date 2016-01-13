# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;
use testapi;
use utils;

sub createvm($) {
    my ($self, $nodenum) = @_;
    script_run "qemu-img create -f qcow2 node$nodenum.img 10G";
    my $nodemac = 6 + $nodenum;
    type_string "su -c 'qemu-kvm -m 1024 -vga cirrus -drive file=node$nodenum.img,id=hd1 -cdrom /dev/sr0 -drive if=scsi,id=addon_1,file=/dev/sr1,media=cdrom -drive if=scsi,id=addon_2,file=/dev/sr2,media=cdrom -drive if=scsi,id=addon_3,file=/dev/sr3,media=cdrom -vnc :9$nodenum,share=force-shared -netdev bridge,id=hn0 -device virtio-net,netdev=hn0,mac=52:54:00:12:34:5$nodemac &'\n";
    sleep 5;
    type_string "nots3cr3t\n";
    sleep 5;
    type_string "vncviewer localhost:9$nodenum -shared -fullscreen\n";
    assert_screen "inst-bootmenu",                    15;
    send_key_until_needlematch 'inst-oninstallation', 'down';
    type_string "ssh=1 ";
    type_string "sshpassword=openqaha ";
    type_string "netsetup=dhcp,all ", 13;
    assert_screen "inst-ssh-typed",   13;
    send_key 'ret',                   1;
    assert_screen "inst-ssh-ready",   500;
    send_key 'f8',                    1;
    send_key 'down',                  1;
    send_key 'ret',                   1;
    clear_console;
}

sub run() {
    my ($self) = @_;

    assert_and_click 'proxy-terminator-ha-icon';
    send_key 'ret';
    assert_screen 'proxy-terminator-started';
    send_key 'ctrl-pgup', 1;
    send_key 'ctrl-pgup', 1;
    $self->createvm("1");    # only need one VM now
}

1;
