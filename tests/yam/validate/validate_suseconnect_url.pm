# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure inst.register_url provides url to SUSEConnect.

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;

sub run {
    select_console 'root-console';
    my $scc_url = (get_var('AGAMA_PROFILE_OPTIONS') =~ /registration_url="(?<registration_url>.+?)"/) ? $+{registration_url} : get_var('SCC_URL');
    validate_script_output("cat /etc/SUSEConnect", sub { m/\b\Q$scc_url\E\b/i });
}

1;
