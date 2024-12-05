# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles that Agama is up and running in a generic way, delegating further testing
# to other test modules or proper web automation tool. It acts only as a synchronization point.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::AgamaUpAndRunningPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_array_ref_any_first_screen_shown => [
            qw(agama-product-selection
              agama-configuring-the-product
              agama-installing
              agama-sle-overview)],
        timeout_expect_is_shown => $args->{timeout_expect_is_shown} // 120
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_array_ref_any_first_screen_shown}, $self->{timeout_expect_is_shown});
}

1;
