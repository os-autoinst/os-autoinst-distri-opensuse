# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test nmtui tool during agama boot up.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::NmtuiNetworkConfigurationPage;

use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_ntui_current_network_configuration => 'ntui_current_network_configuration',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_ntui_current_network_configuration}, 120);
}

sub edit {
    wait_screen_change { send_key 'e' };
}

sub test_connection {
    wait_screen_change { send_key 't' };
}

sub continue {
    wait_screen_change { send_key 'c' };
}

1;
