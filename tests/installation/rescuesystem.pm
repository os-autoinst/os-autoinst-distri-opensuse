use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "inst-bootmenu", 15;

    $self->bootmenu_down_to('inst-rescuesystem');
    send_key "ret";

    # Login as root (no password)
    assert_screen "rescuesystem-login", 120;
    type_string "root\n";

    # Clean the screen
    sleep 1;
    type_string "reset\n";
    assert_screen "rescuesystem-prompt", 4;

    # Check that there is access to the local hard disk
    type_string "mount /dev/vda2 /mnt\n";
    type_string "cat /mnt/etc/SUSE-brand > /dev/$serialdev\n";
    wait_serial("VERSION = 13.1", 2) || die "Not SUSE-brand found";
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
