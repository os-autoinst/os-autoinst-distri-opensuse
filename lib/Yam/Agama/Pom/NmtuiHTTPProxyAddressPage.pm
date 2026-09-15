# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test nmtui tool's HTTP proxy address page.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::NmtuiHTTPProxyAddressPage;

use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_ntui_http_proxy_address => 'ntui_http_proxy_address',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_ntui_http_proxy_address});
}

sub ok {
    wait_screen_change { send_key 'ret' };
}

1;
