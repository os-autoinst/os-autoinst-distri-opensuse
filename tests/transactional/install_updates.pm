# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install Update repos in transactional server
# Maintainer: qac team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use qam;
use transactional;
use version_utils 'is_sle_micro';

sub run {
    my ($self) = @_;
    select_console 'root-console';
    if (is_sle_micro) {
        assert_script_run 'curl http://ca.suse.de/certificates/ca/SUSE_Trust_Root.crt -o /etc/pki/trust/anchors/SUSE_Trust_Root.crt';
        assert_script_run 'update-ca-certificates -v';
    }
    add_test_repositories;
    record_info 'Updates', script_output('zypper lu');
    trup_call 'up';
    check_reboot_changes;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
