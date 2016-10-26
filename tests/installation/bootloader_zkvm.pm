# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: zKVM bootloader
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

use base "installbasetest";

use testapi;

use strict;
use warnings;

sub run() {

    my $self = shift;

    my $svirt = select_console('svirt');
    my $name  = $svirt->name;

    # temporary use of hardcoded '+4' to workaround messed up network setup on z/KVM
    my $vtap = $svirt->instance + 4;

    my $cmdline = get_var('VIRSH_CMDLINE') . " ";

    my $repo = "ftp://openqa.suse.de/" . get_var('REPO_0');
    $cmdline .= "install=$repo ";

    if (check_var("VIDEOMODE", "text")) {
        $cmdline .= "ssh=1 ";    # trigger ssh-text installation
    }
    else {
        $cmdline .= "sshd=1 vnc=1 VNCPassword=$testapi::password ";    # trigger default VNC installation
    }

    # we need ssh access to gather logs
    # 'ssh=1' and 'sshd=1' are equal, both together don't work
    # so let's just set the password here
    $cmdline .= "sshpassword=$testapi::password ";

    $svirt->change_domain_element(os => initrd  => "/var/lib/libvirt/images/$name.initrd");
    $svirt->change_domain_element(os => kernel  => "/var/lib/libvirt/images/$name.kernel");
    $svirt->change_domain_element(os => cmdline => $cmdline);

    # after installation we need to redefine the domain, so just shutdown
    $svirt->change_domain_element(on_reboot => 'destroy');

    # For some tests we need more than the default 4GB
    my $size_i = get_var('HDDSIZEGB') || '4';

    $svirt->add_disk({size => $size_i . "G", create => 1, dev_id => 'a'});
    # need that for s390
    $svirt->add_pty({pty_dev => 'console', pty_dev_type => 'pty', target_type => 'sclp', target_port => '0'});

    # direct access to the tap device
    # use of $vtap temporarily
    $svirt->add_interface({type => 'direct', source => {dev => "enccw0.0.0600", mode => 'bridge'}, target => {dev => 'macvtap' . $vtap}});

    # use proper virtio
    # $svirt->add_interface({ type => 'network', source => { network => 'default' }, model => { type => 'virtio' } });

    # show this on screen and make sure that kernel and initrd are actually saved
    type_string "wget $repo/boot/s390x/initrd -O /var/lib/libvirt/images/$name.initrd\n";
    assert_screen "initrd-saved";
    type_string "wget $repo/boot/s390x/linux -O /var/lib/libvirt/images/$name.kernel\n";
    assert_screen "kernel-saved";

    $svirt->define_and_start;

    if (check_var("VIDEOMODE", "text")) {
        wait_serial("run 'yast.ssh'", 300) || die "linuxrc didn't finish";
        select_console("installation");
        type_string("yast.ssh\n");
    }
    else {
        wait_serial(' Starting YaST2 ', 300) || die "yast didn't start";
        select_console('installation');
    }
}

1;
