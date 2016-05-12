# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";

use testapi;

use strict;
use warnings;

sub is_jeos() {
    return get_var('FLAVOR', '') =~ /^JeOS/;
}

sub run() {

    my $self = shift;

    my $arch       = get_var('ARCH',             'x86_64');
    my $vmm_family = get_var('VIRSH_VMM_FAMILY', 'kvm');
    my $vmm_type   = get_var('VIRSH_VMM_TYPE',   'hvm');

    my $svirt = select_console('svirt');
    my $name  = $svirt->name;
    my $repo;

    my $xenconsole = "xvc0";
    if (check_var("VERSION", "12-SP2")) {
        $xenconsole = "hvc0";    # on 12-SP2 we use pvops, thus /dev/hvc0
    }

    if (!is_jeos) {
        my $cmdline = get_var('VIRSH_CMDLINE') . " ";

        $repo = "ftp://openqa.suse.de/" . get_var('REPO_0');
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

        if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
            $cmdline .= "xenfb.video=4,1024,768 console=$xenconsole console=tty0 ";
        }
        else {
            $cmdline .= "console=ttyS0 ";
        }

        $svirt->change_domain_element(os => initrd => "/var/lib/libvirt/images/$name.initrd");
        # <os><kernel>...</kernel></os> defaults to grub.xen, we need to remove
        # content first if booting kernel diretly
        if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
            $svirt->change_domain_element(os => kernel => undef);
        }
        $svirt->change_domain_element(os => kernel  => "/var/lib/libvirt/images/$name.kernel");
        $svirt->change_domain_element(os => cmdline => $cmdline);

        # after installation we need to redefine the domain, so just shutdown
        $svirt->change_domain_element(on_reboot => 'destroy');
    }

    # TODO: JeOS defaults to 24 GB (or 30 on HyperV)
    my $size_i = get_var('HDDSIZEGB', '24');

    my $file = get_var('HDD_1');
    # in JeOS we have the disk, we just need to deploy it
    if (is_jeos) {
        $svirt->add_disk({size => $size_i . 'G', file => $file});
    }
    else {
        $svirt->add_disk({size => $size_i . 'G', file => $file, create => 1});
    }

    my $pty_type;
    if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
        $pty_type = 'xen';
    }
    else {
        $pty_type = 'serial';
    }
    $svirt->add_pty({pty_dev => 'console', type => $pty_type, port => '0'});
    if (!($vmm_family eq 'xen' && $vmm_type eq 'linux')) {
        $svirt->add_pty({pty_dev => 'serial', type => 'isa-serial', port => '0'});
    }

    $svirt->add_vnc({port => '5901'});

    if ($vmm_family eq 'kvm') {
        $svirt->add_interface({type => 'network', source => {network => 'default'}, model => {type => 'virtio'}});
    }
    elsif ($vmm_family eq 'xen') {
        if ($vmm_type eq 'hvm') {
            $svirt->add_interface({type => 'network', source => {network => 'default'}, model => {type => 'netfront'}});
            # emulator is not being set for Xen HVM automatically
            $svirt->add_emulator({emulator => '/usr/lib/xen/bin/qemu-system-i386'});
        }
        elsif ($vmm_type eq 'linux') {
            $svirt->add_interface({type => 'network', source => {network => 'default'}});
        }
    }

    if (!is_jeos) {
        my $loader = "loader";
        my $xen    = "";
        my $linux  = "linux";
        if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
            $loader = "";
            $xen    = "-xen";
            $linux  = "vmlinuz";
        }
        # Show this on screen. The sleeps are necessary for the main process
        # to wait for the downloads otherwise it would continue and could
        # start the VM with uncomplete kernel/initrd, and thus fail. The time
        # to wait is pure guesswork.
        type_string "wget $repo/boot/$arch/$loader/$linux$xen -O /var/lib/libvirt/images/$name.kernel\n";
        sleep 10;    # TODO: assert_screen
        type_string "wget $repo/boot/$arch/$loader/initrd$xen -O /var/lib/libvirt/images/$name.initrd\n";
        sleep 10;    # TODO: assert_screen
    }

    $svirt->define_and_start;

    # This sets kernel argument so needle-matching works on Xen PV. It's being
    # done via host's PTY device because we don't see anything unless kernel
    # sets framebuffer (this is a GRUB2's limitation bsc#961638).
    if ($vmm_family eq 'xen') {
        if ($vmm_type eq 'linux') {
            type_string "export pty=`virsh dumpxml $name | grep \"console type=\" | sed \"s/'/ /g\" | awk '{ print \$5 }'`\n";
            type_string "echo \$pty\n";
            type_string "echo e > \$pty\n";    # edit
            for (1 .. 4) { type_string "echo -en '\\033[B' > \$pty\n"; }    # four-times key down
            type_string "echo -en '\\033[K' > \$pty\n";                     # end of line
            type_string "echo -en ' xenfb.video=4,1024,768' > \$pty\n";     # set kernel framebuffer
            type_string "echo -en '\\x18' > \$pty\n";                       # send Ctrl-x to boot guest kernel
        }
    }
    # select_console does not select TTY in traditional sense, but
    # connects to a guest VNC session
    if (is_jeos) {
        select_console('sut');
    }
    else {
        if (check_var("VIDEOMODE", "text")) {
            wait_serial("run 'yast.ssh'", 500) || die "linuxrc didn't finish";
            select_console("installation");
            type_string("yast.ssh\n");
        }
        else {
            wait_serial(' Starting YaST2 ', 500) || die "yast didn't start";
            select_console('installation');
        }
    }
}

1;
