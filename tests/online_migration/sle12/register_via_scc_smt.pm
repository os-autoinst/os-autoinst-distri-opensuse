use base "installbasetest";
use strict;
use testapi;
use registration;

sub run() {
    my $self = shift;
    become_root;

    # register via smt
    if (my $u = get_var('SCC_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }

    yast_scc_registration;
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
