# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check system role selection screen or select system role. Added in SLE 12 SP2
# Maintainer: Jozef Pupava <jpupava@suse.com>
# Tags: poo#16650, poo#25850

use strict;
use base "y2logsstep";
use testapi;


my %role_hotkey = (
    gnome    => 's',
    textmode => 't',
    minimal  => 'm',
    kvm      => 'k',
    xen      => 'x',
);

sub change_system_role {
    my ($system_role) = @_;
    send_key 'alt-' . $role_hotkey{$system_role};
    assert_screen "system-role-$system_role-selected";
    # every system role other than default will end up in textmode
    set_var('DESKTOP', 'textmode');
}

sub assert_system_role {
    # Still initializing the system at this point, can take some time
    # Verify default role for SLE15, it's text for sles and gnome for sled
    assert_screen 'system-role-default-system', 180;
    my $system_role = get_var('SYSTEM_ROLE', 'default');
    if (get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default')) {
        change_system_role($system_role);
    }
    send_key $cmd{next};
}

sub run {
    # Define default role
    assert_system_role;
}

1;
# vim: set sw=4 et:
