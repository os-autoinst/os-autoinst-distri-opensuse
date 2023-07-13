# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act on the Performing Installation
#          Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::PerformingInstallation::PerformingInstallationPage;
use strict;
use warnings;
use testapi 'save_screenshot';

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{prb_total_packages} = $self->{app}->progressbar({id => 'progressTotal'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{prb_total_packages}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

1;
