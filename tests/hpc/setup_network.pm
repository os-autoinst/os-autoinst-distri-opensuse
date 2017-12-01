# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: HPC helper module which sets up static network needed by HPC multimachine tests
# Maintainer: soulofdestiny <mgriessmeier@suse.com>

use base "hpcbase";
use strict;
use testapi;
use utils;

sub run {
    my $self = shift;

    select_console 'root-console';
    $self->setup_static_network(get_required_var('HPC_HOST_IP'));

    # stop firewall, so key can be copied
    systemctl 'stop ' . $self->firewall;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
