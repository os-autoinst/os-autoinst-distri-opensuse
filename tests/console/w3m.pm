# SUSE's openQA tests - FIPS tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case 1525204 - FIPS: w3m

use base "consoletest";
use strict;
use testapi;

sub run() {
    select_console "root-console";

    assert_script_run('rpm -q w3m');
    script_run("zypper --no-refresh se -it pattern fips");

    my %https_url = (
        google => "https://www.google.com/",
        suse   => "https://www.suse.com/",
        OBS    => "https://build.opensuse.org/",
    );

    for my $p (keys %https_url) {
        send_key "ctrl-l";
        script_run "w3m $https_url{$p}", 0;
        assert_screen "w3m-connect-$p-webpage";
        send_key "q";
        send_key "y";
    }
}
1;
# vim: set sw=4 et:
