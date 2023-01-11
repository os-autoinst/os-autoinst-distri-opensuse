# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Navigation base
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Navigation::NavigationBase;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{btn_next} = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_next}->exist();
}

sub press_next {
    my ($self) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            return $self->{btn_next}->is_enabled();
    }, message => "Next button takes too long to be enabled");
    return $self->{btn_next}->click();
}

1;
