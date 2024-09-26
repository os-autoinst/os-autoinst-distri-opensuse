# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles that Agama is up and running in a generic way, delegating further testing
# to other test modules or proper web automation tool. It acts only as a synchronization point.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::Sle::AgamaUpAndRunningPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_array_ref_any_first_screen_shown => [qw(agama-installing agama-sle-overview)]
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_array_ref_any_first_screen_shown}, 90);
}

1;
