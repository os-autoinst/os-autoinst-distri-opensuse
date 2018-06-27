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
use version_utils qw(is_sle is_caasp);


my %role_hotkey = (
    gnome    => 's',
    textmode => 't',
    minimal  => 'm',
    kvm      => 'k',
    xen      => 'x',
);

sub change_system_role {
    my ($system_role) = @_;
    # Since SLE 15 we do not have shortcuts for system roles anymore
    if ((is_sle '15+') || (is_caasp 'kubic')) {
        if (check_var('VIDEOMODE', 'text')) {
            # Expect that no actions are done before and default system role is preselected
            send_key_until_needlematch "system-role-$system_role-focused",  'down';    # select role
            send_key_until_needlematch "system-role-$system_role-selected", 'spc';     # enable role
        }
        else {
            assert_and_click "system-role-$system_role";
            assert_screen "system-role-$system_role-selected";
        }
    }
    else {
        send_key 'alt-' . $role_hotkey{$system_role};
        assert_screen "system-role-$system_role-selected";
    }
    # every system role other than default will end up in textmode
    set_var('DESKTOP', 'textmode');
}

sub assert_system_role {
    # Still initializing the system at this point, can take some time
    # Asserting screen with preselected role
    # Proper default role assertion will be addressed in poo#37504
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
