use base "installbasetest";

use testapi;

use strict;
use warnings;

sub run() {

    my $self = shift;

    my $svirt = select_console('svirt');
    my $name  = $svirt->name;

    my $cmdline = get_var('VIRSH_CMDLINE') . " ";

    my $repo = "ftp://openqa.suse.de/" . get_var('REPO_0');
    $cmdline .= "install=$repo ";

    $cmdline .= "vnc=1 VNCPassword=$testapi::password ";     # trigger VNC installation
    $cmdline .= "sshpassword=$testapi::password sshd=1 ";    # we need ssh access to gather logs

    $svirt->define_domain(
        {
            initrd    => "/var/lib/libvirt/images/$name.initrd",
            kernel    => "/var/lib/libvirt/images/$name.kernel",
            cmdline   => $cmdline,
            on_reboot => 'destroy',
        });
    $svirt->add_disk({size => '4G', create => 1});
    # need that for s390
    $svirt->add_pty({type => 'sclp', port => '0'});

    # direct access to the tap device
    $svirt->add_interface({type => 'direct', source => {dev => "enccw0.0.0600", mode => 'bridge'}, target => {dev => 'macvtap1'}});

    # use proper virtio
    # $svirt->add_interface({ type => 'network', source => { network => 'default' }, model => { type => 'virtio' } });

    # show this on screen
    type_string "wget $repo/boot/s390x/initrd -O /var/lib/libvirt/images/$name.initrd\n";
    sleep 2;    # TODO: assert_screen
    type_string "wget $repo/boot/s390x/linux -O /var/lib/libvirt/images/$name.kernel\n";
    sleep 2;    # TODO: assert_screen

    $svirt->define_and_start;

    # now wait
    wait_serial(' Starting YaST2 ', 300) || die "yast didn't start";

    select_console('installation');

}

1;
