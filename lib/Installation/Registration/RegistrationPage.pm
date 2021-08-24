# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The module provides interface to act with Registration page
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::Registration::RegistrationPage;
use parent 'Installation::Navigation::NavigationBar';
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
    $self->{lbl_skip_registration} = $self->{app}->label({label => 'Skip Registration'});
    $self->{tb_email}              = $self->{app}->textbox({id => 'email'});
    $self->{tb_reg_code}           = $self->{app}->textbox({id => 'reg_code'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_skip_registration}->exist();
}

sub enter_email {
    my ($self, $email) = @_;
    return $self->{tb_email}->set($email);
}

sub enter_reg_code {
    my ($self, $reg_code) = @_;
    return $self->{tb_reg_code}->set($reg_code);
}

1;
