use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $check_state    = "systemctl show --no-pager sshd | grep ActiveState | cut -d'=' -f2";
    my $check_substate = "systemctl show --no-pager sshd | grep SubState | cut -d'=' -f2";

    validate_script_output $check_state,    sub { m/^active$/ };
    validate_script_output $check_substate, sub { m/^running$/ };
}

sub test_flags() {
    return {important => 1};
}

1;
