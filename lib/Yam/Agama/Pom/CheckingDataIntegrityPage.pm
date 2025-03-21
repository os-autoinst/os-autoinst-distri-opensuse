# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles that Agama mediacheck results page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::CheckingDataIntegrityPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_ref_mediacheck_screen_shown => [
            qw(agama-mediacheck-test)],
        timeout_expect_finish => $args->{timeout_expect_finish} // 240
    }, $class;
}

sub expect_successful_result {
    my ($self) = @_;
    assert_screen($self->{tag_ref_mediacheck_screen_shown}, $self->{timeout_expect_finish});
}

1;
