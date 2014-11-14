use base "rescuecdstep";
use strict;
use bmwqemu;

sub run() {
    my $self = shift;
    assert_screen "rescuecd-desktop", 120;

    # Mount and show the local hard disk contect
    assert_and_dclick "hd-volume";
    assert_screen "hd-mounted", 6;

    x11_start_program("xterm");
    script_run "cd `cat /proc/self/mounts | grep /dev/vda2 | cut -d' ' -f2`";
    script_sudo "sh -c 'cat etc/SUSE-brand > /dev/$serialdev'";
    wait_serial("VERSION = 13.1", 2) || die "Not SUSE-brand found";
}

1;

# vim: set sw=4 et:
