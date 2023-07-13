# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Welcome dialog
# in YaST Firstboot Configuration.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firstboot::WelcomePage;
use parent 'Installation::Navigation::NavigationBase';
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
    my ($self) = @_;
    $self->SUPER::init();
    $self->{rct_welcome} = $self->{app}->richtext({id => 'welcome_text'});
    return $self;
}

sub get_welcome_text {
    my ($self) = @_;
    return $self->{rct_welcome}->text();
}

sub is_shown {
    my ($self) = @_;
    return $self->{rct_welcome}->exist();
}

1;
