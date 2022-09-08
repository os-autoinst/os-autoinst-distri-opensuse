# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Registration page
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Registration::RegistrationPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{rdb_skip_registration} = $self->{app}->radiobutton({id => 'skip_registration'});
    $self->{txb_email} = $self->{app}->textbox({id => 'email'});
    $self->{txb_reg_code} = $self->{app}->textbox({id => 'reg_code'});
    $self->{rdb_rmt_server} = $self->{app}->radiobutton({id => 'register_local'});
    $self->{cmb_local_url} = $self->{app}->combobox({id => 'custom_url'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{txb_reg_code}->exist();
}

sub enter_email {
    my ($self, $email) = @_;
    return $self->{txb_email}->set($email);
}

sub select_skip_registration {
    my ($self) = @_;
    $self->{rdb_skip_registration}->select();
}

sub enter_reg_code {
    my ($self, $reg_code) = @_;
    return $self->{txb_reg_code}->set($reg_code);
}

sub select_rmt_registration {
    my ($self) = @_;
    $self->{rdb_rmt_server}->select();
}

sub enter_local_server {
    my ($self, $server) = @_;
    return $self->{cmb_local_url}->set($server);
}

1;
