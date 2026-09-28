# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test nmtui tool's edit connection page.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::NmtuiEditConnectionPage;

use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_ntui_edit_a_connection => 'ntui_edit_a_connection',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_ntui_edit_a_connection});
}

sub quit {
    wait_screen_change { send_key 'esc' };
}

1;
