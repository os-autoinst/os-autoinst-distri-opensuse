# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods in Expert Partitioner to handle
# a generic popup containing the message in YRichText Widget.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Popups::OkPopup;
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
    $self->{rt_warning} = $self->{app}->label({type => 'YRichText'});
    $self->{btn_ok}     = $self->{app}->button({id => 'ok'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_ok}->exist();
}

sub text {
    my ($self) = @_;
    return $self->{rt_warning}->text();
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
}

1;
