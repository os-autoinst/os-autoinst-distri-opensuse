# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#

# inherit qa_run, but overwrite run
# G-Summary: QA Automation: patch the system before running the test
#    This is to test Test Updates for SP1 and GA
# G-Maintainer: Stephan Kulow <coolo@suse.de>

use base "qa_run";
use strict;
use warnings;
use utils;
use testapi;

sub run {
    my $self = shift;
    $self->system_login();

    pkcon_quit unless check_var('DESKTOP', 'textmode');

    for my $var (qw(OS_TEST_REPO SDK_TEST_REPO)) {
        my $repo = get_var($var);
        next unless $repo;
        assert_script_run("zypper --no-gpg-check -n ar -f '$repo' test-repo-$var");
    }

    fully_patch_system;

    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
