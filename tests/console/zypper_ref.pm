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
use strict;
use testapi;

sub run() {
    my $self = shift;

    select_console 'root-console';

    script_run("zypper ref; echo zypper-ref-\$? > /dev/$serialdev", 0);
    # don't trust graphic driver repo
    assert_screen([qw/new-repo-need-key zypper_ref/]);
    if (match_has_tag('new-repo-need-key')) {
        type_string "r\n";
    }
    wait_serial("zypper-ref-0") || die "zypper ref failed";
}

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
