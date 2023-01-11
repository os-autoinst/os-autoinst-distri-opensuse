# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles the pop-up that allows to select users from previous installation.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::LocalUser::SelectUsersPage;
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
    my ($self) = @_;
    $self->{chb_select_all} = $self->{app}->checkbox({id => 'all'});
    $self->{btn_ok} = $self->{app}->button({id => 'ok'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    my $is_shown = $self->{chb_select_all}->exist();
    save_screenshot if $is_shown;
    return $is_shown;
}

sub select_all {
    my ($self) = @_;
    return $self->{chb_select_all}->check();
}

sub press_ok {
    my ($self) = @_;
    return $self->{btn_ok}->click();
}

1;
