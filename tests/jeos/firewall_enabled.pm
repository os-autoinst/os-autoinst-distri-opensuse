use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $check_state    = "systemctl show --no-pager SuSEfirewall2 | grep ActiveState | cut -d'=' -f2";
    my $check_substate = "systemctl show --no-pager SuSEfirewall2 | grep SubState | cut -d'=' -f2";
    my $check_ssh_port = "grep 'FW_SERVICES_EXT_TCP=' /etc/sysconfig/SuSEfirewall2 | cut -d'\"' -f2";

    validate_script_output $check_state,    sub { /^active$/ };
    validate_script_output $check_substate, sub { /^exited$/ };
    validate_script_output $check_ssh_port, sub { /^22$/ };
}

sub test_flags() {
    return {important => 1};
}

1;
