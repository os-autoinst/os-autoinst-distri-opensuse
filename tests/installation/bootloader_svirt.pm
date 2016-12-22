# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: svirt bootloader
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use File::Basename;

sub run() {

    my $self = shift;

    my $arch       = get_var('ARCH');
    my $vmm_family = get_required_var('VIRSH_VMM_FAMILY');
    my $vmm_type   = get_required_var('VIRSH_VMM_TYPE');

    my $svirt = select_console('svirt');
    my $name  = $svirt->name;
    my $repo;

    my $xenconsole = "hvc0";
    if (!get_var('SP2ORLATER')) {
        $xenconsole = "xvc0";
    }

    if (get_var('NETBOOT')) {
        my $cmdline = get_var('VIRSH_CMDLINE', '') . " ";

        $repo = "ftp://openqa.suse.de/" . get_var('REPO_0');
        $cmdline .= "install=$repo ";

        if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
            if (is_jeos) {
                $cmdline .= "xenfb.video=4,1024,768 ";
            }
            else {
                $cmdline .= "xen-fbfront.video=32,1024,768 ";
            }
            $cmdline .= "console=$xenconsole console=tty ";
        }
        else {
            $cmdline .= "console=ttyS0 console=tty ";
        }

        if (check_var('VIDEOMODE', 'text')) {
            $cmdline .= "textmode=1 ";
        }

        if (get_var('EXTRABOOTPARAMS')) {
            $cmdline .= get_var('EXTRABOOTPARAMS') . " ";
        }

        $svirt->change_domain_element(os => initrd => "/var/lib/libvirt/images/$name.initrd");
        # <os><kernel>...</kernel></os> defaults to grub.xen, we need to remove
        # content first if booting kernel diretly
        if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
            $svirt->change_domain_element(os => kernel => undef);
        }
        $svirt->change_domain_element(os => kernel  => "/var/lib/libvirt/images/$name.kernel");
        $svirt->change_domain_element(os => cmdline => $cmdline);
    }

    # After installation we need to redefine the domain, so the next
    # boot loads installed kernel and initrd.
    $svirt->change_domain_element(on_reboot => 'destroy');

    my $size_i = get_var('HDDSIZEGB', '24');
    # In JeOS we have the disk, we just need to deploy it, for the rest
    # - installs from network and ISO media - we have to create it.
    if (my $hddfile = get_var('HDD_1')) {
        $svirt->add_disk(
            {
                size      => $size_i . 'G',
                file      => ($vmm_family eq 'vmware') ? basename($hddfile) : $hddfile,
                dev_id    => 'a',
                bootorder => 1
            });
        if (my $extra_hdd = get_var('HDD_2')) {
            $svirt->add_disk(
                {
                    file => ($vmm_family eq 'vmware') ? basename($extra_hdd) : $extra_hdd,
                    dev_id => 'b'
                });

        }
    }
    else {
        $svirt->add_disk(
            {
                size      => $size_i . 'G',
                create    => 1,
                dev_id    => 'a',
                bootorder => 1
            });
    }

    # In JeOS and netinstall we don't have ISO media, for the rest we have to attach it.
    if (!get_var('NETBOOT') and !is_jeos() and !get_var('HDD_1')) {
        my $isofile = get_required_var('ISO');
        if ($vmm_family eq 'vmware') {
            $isofile = basename($isofile);
        }
        $svirt->add_disk(
            {
                cdrom     => 1,
                file      => $isofile,
                dev_id    => 'b',
                bootorder => 2
            });

        # Add addon media (if present at all)
        my $dev_id = 'c';
        foreach my $n (1 .. 9) {
            if (my $addon_isofile = get_var("ISO_" . $n)) {
                if ($vmm_family eq 'vmware') {
                    $addon_isofile = basename($addon_isofile);
                }
                $svirt->add_disk(
                    {
                        cdrom  => 1,
                        file   => $addon_isofile,
                        dev_id => $dev_id
                    });
                $dev_id = chr((ord $dev_id) + 1);    # return next letter in alphabet
            }
        }
    }

    # We need to use 'tablet' as a pointer device, i.e. a device
    # with absolute axis. That needs to be explicitely configured
    # on KVM and Xen HVM only. VMware and Xen PV add pointer
    # device with absolute axis by default.
    if (($vmm_family eq 'kvm') or ($vmm_family eq 'xen' and $vmm_type eq 'hvm')) {
        if ($vmm_family eq 'kvm') {
            $svirt->add_input({type => 'tablet',   bus => 'virtio'});
            $svirt->add_input({type => 'keyboard', bus => 'virtio'});
        }
        elsif ($vmm_family eq 'xen' and $vmm_type eq 'hvm') {
            $svirt->add_input({type => 'tablet',   bus => 'usb'});
            $svirt->add_input({type => 'keyboard', bus => 'ps2'});
        }
    }

    my $console_target_type;
    if ($vmm_family eq 'xen' && $vmm_type eq 'linux') {
        $console_target_type = 'xen';
    }
    else {
        $console_target_type = 'serial';
    }
    # esx driver in libvirt does not support `virsh console' command. We need
    # to export it on our own via TCP.
    my $pty_dev_type;
    if ($vmm_family eq 'vmware') {
        $pty_dev_type = 'tcp';
    }
    else {
        $pty_dev_type = 'pty';
    }
    my $protocol_type;
    my $source = 0;
    if ($vmm_family eq 'vmware') {
        $protocol_type = 'raw';
        $source        = 1;
    }
    $svirt->add_pty(
        {
            pty_dev       => 'console',
            pty_dev_type  => $pty_dev_type,
            target_type   => $console_target_type,
            target_port   => '0',
            protocol_type => $protocol_type,
            source        => $source
        });
    if (!($vmm_family eq 'xen' && $vmm_type eq 'linux')) {
        $svirt->add_pty(
            {
                pty_dev       => 'serial',
                pty_dev_type  => $pty_dev_type,
                target_port   => '0',
                protocol_type => $protocol_type,
                source        => $source
            });
    }

    $svirt->add_vnc({port => get_var('VIRSH_INSTANCE', 1) + 5900});

    my %ifacecfg = ();

    # VMs should be specified with known-to-work network interface.
    # Xen PV and Hyper-V use streams.
    my $iface_model;
    if ($vmm_family eq 'kvm') {
        $iface_model = 'virtio';
    }
    elsif ($vmm_family eq 'xen' && $vmm_type eq 'hvm') {
        $iface_model = 'netfront';
    }
    elsif ($vmm_family eq 'vmware') {
        $iface_model = 'e1000';
    }

    if ($iface_model) {
        $ifacecfg{model} = {type => $iface_model};
    }

    if ($vmm_family eq 'vmware') {
        # `virsh iface-list' won't produce correct bridge name for VMware.
        # It should be provided by the worker or relied upon the default.
        $ifacecfg{type} = 'bridge';
        $ifacecfg{source} = {bridge => get_var('VMWARE_BRIDGE', 'VM Network')};
    }
    elsif ($vmm_family eq 'kvm') {
        $ifacecfg{type} = 'user';
        # This is the default MAC address for user mode networking; same in qemu backend
        $ifacecfg{mac} = {address => '52:54:00:12:34:56'};
    }
    else {
        # We can use bridge or network as a base for network interface. Network named 'default'
        # happens to be omnipresent on workstations, bridges (br0, ...) on servers. If both 'default'
        # network and bridge are defined and active, bridge should be prefered as 'default' network
        # does not work.
        if (my $bridges = $svirt->get_cmd_output("virsh iface-list --all | grep -w active | awk '{ print \$1 }' | tail -n1 | tr -d '\\n'")) {
            $ifacecfg{type} = 'bridge';
            $ifacecfg{source} = {bridge => $bridges};
        }
        elsif (my $networks = $svirt->get_cmd_output("virsh net-list --all | grep -w active | awk '{ print \$1 }' | tail -n1 | tr -d '\\n'")) {
            $ifacecfg{type} = 'network';
            $ifacecfg{source} = {network => $networks};
        }
    }

    $svirt->add_interface(\%ifacecfg);

    if (get_var('NETBOOT')) {
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
        assert_screen "kernel-saved";
        type_string "wget $repo/boot/$arch/$loader/initrd$xen -O /var/lib/libvirt/images/$name.initrd\n";
        assert_screen "initrd-saved";
    }

    $svirt->define_and_start;

    # This sets kernel argument so needle-matching works on Xen PV. It's being
    # done via host's PTY device because we don't see anything unless kernel
    # sets framebuffer (this is a GRUB2's limitation bsc#961638).
    if ($vmm_family eq 'xen' and $vmm_type eq 'linux' and !get_var('NETBOOT')) {
        $svirt->suspend;
        my $cmdline = "";
        if (check_var('VIDEOMODE', 'text')) {
            $cmdline .= "textmode=1 ";
        }
        if (get_var('EXTRABOOTPARAMS')) {
            $cmdline .= get_var('EXTRABOOTPARAMS') . " ";
        }
        type_string "export pty=`virsh dumpxml $name | grep \"console type=\" | sed \"s/'/ /g\" | awk '{ print \$5 }'`\n";
        type_string "echo \$pty\n";
        $svirt->resume;
        wait_serial("Press enter to boot the selected OS", 10) || die "Can't get to Grub";
        type_string "echo e > \$pty\n";    # edit

        if (is_jeos or is_casp) {
            for (1 .. 4) { type_string "echo -en '\\033[B' > \$pty\n"; }    # four-times key down
        }
        else {
            for (1 .. 2) { type_string "echo -en '\\033[B' > \$pty\n"; }    # four-times key down
        }
        type_string "echo -en '\\033[K' > \$pty\n";                         # end of line
        type_string "echo -en ' $cmdline' > \$pty\n";
        if (sle_version_at_least('12-SP2') or is_casp) {
            type_string "echo -en ' xen-fbfront.video=32,1024,768' > \$pty\n";    # set kernel framebuffer
        }
        else {
            type_string "echo -en ' xenfb.video=4,1024,768' > \$pty\n";           # set kernel framebuffer
        }

        type_string "echo -en '\\x18' > \$pty\n";                                 # send Ctrl-x to boot guest kernel
        save_screenshot;
    }

    # If we connect to 'sut' VNC display "too early" the VNC server won't be
    # ready we will be left with a blank screen.
    if ($vmm_family eq 'vmware') {
        sleep 2;
    }
    # connects to a guest VNC session
    select_console('sut');
}

1;
