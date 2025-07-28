# Copyright 2014-2018 SUSE Linux GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: harmorize zypper_ref between SLE and openSUSE
# Maintainer: Max Lin <mlin@suse.com>

use base "y2_module_consoletest";
use testapi;
use registration;

sub run {
    select_console 'root-console';

    if (my $u = get_var('SCC_URL')) {
        enter_cmd "echo 'url: $u' > /etc/SUSEConnect";
    }
    yast_scc_registration;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    verify_scc;
    investigate_log_empty_license;
}

1;
