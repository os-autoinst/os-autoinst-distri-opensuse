use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    # Check that there is access to the local hard disk
    type_string "mount /dev/vda2 /mnt\n";
    type_string "cat /mnt/etc/SUSE-brand > /dev/$serialdev\n";
    wait_serial("VERSION = 13.1", 2) || die "Not SUSE-brand found";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
