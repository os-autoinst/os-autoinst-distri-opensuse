# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use testapi;
use utils;


sub run {
    my $smt = get_var('SMT_SERVER');

    assert_script_run "sed -i -e 's|/srv/www/htdocs/|http://$smt/|' /etc/kiwi/repoalias";
}

sub test_flags {
    return {fatal => 1};
}

1;
