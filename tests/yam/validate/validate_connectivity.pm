# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate connectivity.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';
    my $ip_address_show = script_output("ip address show");
    record_info("ip address show", $ip_address_show);
    my $connectivity = check_var('INST_COPY_NETWORK', '0') || check_var('OFFLINE_SUT', '1') ? 'none|unknown' : 'full';
    validate_script_output("nmcli networking connectivity check", sub { m/\b$connectivity\b/ });
}

1;
