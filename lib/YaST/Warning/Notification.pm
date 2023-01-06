# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to control Notification Dialog
# which has only "Ok" button.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Warning::Notification;
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
    $self->{btn_ok} = $self->{app}->button({id => 'ok_msg'});
    $self->{lbl_header} = $self->{app}->label({label => 'Warning'});
    $self->{lbl_warning} = $self->{app}->label({type => 'YLabel'});
    return $self;
}

sub confirm {
    my ($self) = @_;
    YuiRestClient::Wait::wait_until(object => sub {
            $self->is_shown();
    });
    $self->press_ok();
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
}

sub is_shown {
    my ($self) = @_;
    $self->{lbl_header}->exist();
}

1;
