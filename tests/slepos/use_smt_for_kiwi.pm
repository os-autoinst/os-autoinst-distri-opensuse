# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use testapi;
use utils;


sub run() {
    my $self = shift;

    my $smt = get_var('SMT_SERVER');

    assert_script_run "sed -i -e 's|/srv/www/htdocs/|http://$smt/|' /etc/kiwi/repoalias";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
