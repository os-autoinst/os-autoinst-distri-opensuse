# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test nmtui tool's connection test result page.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::NmtuiConnectionTestResultPage;

use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_ntui_test_succeeded => 'ntui_test_succeeded',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_ntui_test_succeeded});
}

sub ok {
    wait_screen_change { send_key 'ret' };
}

1;
