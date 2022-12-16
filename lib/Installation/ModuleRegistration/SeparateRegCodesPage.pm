# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with page that ask for module extra registration code
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ModuleRegistration::SeparateRegCodesPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{lbl_separate_code} = $self->{app}->label({type => 'YLabel', label => qr/The extension you selected needs a separate registration code/});
    $self->{txb_we_code} = $self->{app}->textbox({id => '"sle-we"'});
    $self->{txb_ha_code} = $self->{app}->textbox({id => '"sle-ha"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_separate_code}->exist();
}

sub set_we_regcode {
    my ($self, $code) = @_;
    $self->{txb_we_code}->set($code);
}

sub set_ha_regcode {
    my ($self, $code) = @_;
    $self->{txb_ha_code}->set($code);
}

1;
