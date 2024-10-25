# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles that Agama is up and running in a generic way, delegating further testing
# to other test modules or proper web automation tool. It acts only as a synchronization point.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::AgamaUpAndRunningSlePage;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        agama_up_and_running_base => $args->{agama_up_and_running_base},
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{agama_up_and_running_base}->{tag_array_ref_any_first_screen_shown} =
      [qw(agama-installing agama-sle-overview)];
    return $self;
}

sub expect_is_shown { shift->{agama_up_and_running_base}->expect_is_shown() }

1;
