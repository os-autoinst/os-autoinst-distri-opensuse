# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure inst.register_url provides url to SUSEConnect.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    my $scc_url = get_required_var('SCC_URL');
    validate_script_output("cat /etc/SUSEConnect", sub { m/\b$scc_url\b/ });
}

1;
