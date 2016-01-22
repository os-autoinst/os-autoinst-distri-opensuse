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
    my $self = shift;

    become_root;
    script_run("zypper ref; echo zypper-ref-\$? > /dev/$serialdev", 0);
    # don't trust graphic driver repo
    if (check_screen("new-repo-need-key", 20)) {
        type_string "r\n";
    }
    wait_serial("zypper-ref-0") || die "zypper ref failed";
    assert_screen("zypper_ref");

    type_string "exit\n";
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
