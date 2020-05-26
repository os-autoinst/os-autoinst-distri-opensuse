# SUSE's openQA tests
#
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use warnings;
use base "consoletest";
use strict;
use testapi;
use utils;


sub run {
    my $self = shift;
    $self->select_serial_terminal;

    assert_script_run('set -o pipefail');
    for (1..10) {
        assert_script_run("for u in `grep https /etc/zypp/repos.d/*|awk -F= '/baseurl=/ {print\$2}'`;do curl -f -v \$u || exit 1 |& tee -a /tmp/curl.log ;done");
    }
}

sub post_fail_hook {
    upload_logs('/tmp/curl.log');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
