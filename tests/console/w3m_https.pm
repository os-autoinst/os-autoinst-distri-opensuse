# SUSE's openQA tests - FIPS tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1525204 - FIPS: w3m_https

# Summary: Add w3m_https test case and fips test entry
#    Add w3m_https.pm test case was located in console/w3m_https.pm
#    Add w3m_https.pm test entry in load_fips_tests_web() in sle/main.pm
# Maintainer: Ben Chou <bchou@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils 'zypper_call';

sub run {
    select_console "root-console";

    assert_script_run('rpm -q w3m');
    zypper_call('--no-refresh search -it pattern fips');

    my %https_url = (
        google => "https://www.google.com/ncr",
        suse   => "https://www.suse.com/",
        OBS    => "https://build.opensuse.org/",
    );

    for my $p (keys %https_url) {
        type_string "clear\n";
        script_run "w3m $https_url{$p}", 0;
        assert_screen "w3m-connect-$p-webpage";
        send_key "q";
        send_key "y";
    }
}

1;
