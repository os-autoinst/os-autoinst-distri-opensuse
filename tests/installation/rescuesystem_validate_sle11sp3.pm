use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    # Check that there is access to the local hard disk
    type_string "mount /dev/vda2 /mnt && cat /mnt/etc/SuSE-release > /dev/$serialdev\n";
    wait_serial("SUSE Linux Enterprise Server 11", 10) || die "Not SLES found";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
