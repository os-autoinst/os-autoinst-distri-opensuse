# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run test executed by TEST-01-BASIC from upstream after openSUSE/SUSE patches.
# Maintainer: Sergio Lindo Mansilla <slindomansilla@suse.com>, Thomas Blume <tblume@suse.com>

use base 'systemd_testsuite_test';
use warnings;
use strict;
use testapi;

sub run {
    my ($self) = @_;
    $self->testsuiteinstall;

    #run binary tests
    assert_script_run 'cd /var/opt/systemd-tests';
    assert_script_run './run-tests.sh | tee /tmp/testsuite.log', 600;
    assert_screen("systemd-testsuite-binary-tests-summary");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}


1;
