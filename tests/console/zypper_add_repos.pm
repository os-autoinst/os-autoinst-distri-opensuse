# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use testapi;

sub run() {
    my $val = get_var("ZYPPER_ADD_REPOS");
    return unless $val;

    become_root;

    my $prefix = get_var("ZYPPER_ADD_REPO_PREFIX") || 'openqa';

    my $i = 0;
    for my $url (split(/,/, $val)) {
        assert_script_run("zypper -n ar -c -f $url $prefix$i");
        ++$i;
    }

    type_string "exit\n";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
