# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for
# YaST Firstboot Finish Setup Configuration.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firstboot::ConfigurationCompletedPage;
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
    $self->{rct_finish_setup} = $self->{app}->richtext({type => 'YRichText'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rct_finish_setup}->exist();
}

sub get_text {
    my ($self) = @_;
    return $self->{rct_finish_setup}->text();
}

1;
