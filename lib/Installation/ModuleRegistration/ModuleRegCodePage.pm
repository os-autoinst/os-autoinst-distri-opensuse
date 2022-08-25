# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with page that ask for module extra registration code
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ModuleRegistration::ModuleRegCodePage;
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
    $self->{tb_we_code} = $self->{app}->textbox({id => '"sle-we"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tb_we_code}->exist();
}

sub set_regcode {
    my ($self, $code) = @_;
    $self->{tb_we_code}->set($code);
}

1;
