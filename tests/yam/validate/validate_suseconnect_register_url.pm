# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate SUSEConnect after using "inst.register_url".

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    my $suse_connect = script_output("cat /etc/SUSEConnect");
    record_info("cat /etc/SUSEConnect", $suse_connect);
    my $scc_url = get_var('SCC_URL', 'https://scc.suse.com');
    validate_script_output("cat /etc/SUSEConnect", sub { m/\b$scc_url\b/ });
}

1;
