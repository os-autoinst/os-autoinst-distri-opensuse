# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The abstract class introduces methods to handle
# an abstract progreess bar with unknown content.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ProgressBarHandler::AbstractProgressBar;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{prb_any} = $self->{app}->progressbar({type => 'YProgressBar'});
    return $self;
}

sub is_shown {
    my ($self, $args) = @_;
    return $self->{prb_any}->exist($args);
}

1;
