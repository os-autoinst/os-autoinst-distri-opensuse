# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test net config tui during agama boot up
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::NetConfigTUIPage;

use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_net_config_tui_main => 'agama-net-config-tui-main',
        tag_net_config_tui_edit => 'agama-net-config-tui-edit',
        tag_net_config_tui_test_success => 'net_config_tui_test_success',
    }, $class;
}

sub expect_is_shown {
    my ($self, $timeout) = @_;
    $timeout //= 120;
    assert_screen($self->{tag_net_config_tui_main}, $timeout);
}

sub open_edit {
    my ($self) = @_;
    wait_screen_change { send_key 'e' };
    assert_screen($self->{tag_net_config_tui_edit}, 30);
}

sub cancel_edit_and_exit {
    my ($self) = @_;
    wait_screen_change { send_key 'esc' };
    wait_screen_change { send_key 'ret' };
    assert_screen($self->{tag_net_config_tui_main}, 30);
}

sub test_network {
    my ($self) = @_;
    wait_screen_change { send_key 't' };
    assert_screen($self->{tag_net_config_tui_test_success}, 30);
    wait_screen_change { send_key 'ret' };
    assert_screen($self->{tag_net_config_tui_main}, 30);
}

sub continue_boot {
    wait_screen_change { send_key('c') };
}

1;
