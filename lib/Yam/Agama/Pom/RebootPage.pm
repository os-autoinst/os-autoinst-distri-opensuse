# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installation reboot screen.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::RebootPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_installation_complete => 'agama-install-finished',
        tag_reboot_button => 'reboot'
    }, $class;
}

sub expect_is_shown {
    my $self = shift;
    my $timeout = 2400;

    while ($timeout > 0) {
        my $ret = check_screen($self->{tag_installation_complete}, 30);
        $timeout -= 30;
        diag("left total await_install timeout: $timeout");
        last if $ret;
        die "timeout ($timeout) hit awaiting installation to be finished" if $timeout <= 0;
    }
}

sub reboot {
    my ($self) = @_;
    select_console('installation');
    assert_and_click($self->{tag_reboot_button});
}

1;
