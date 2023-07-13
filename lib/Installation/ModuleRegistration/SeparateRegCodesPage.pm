# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with page that ask for module extra registration code
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
    $self->{txb_ltss_code} = $self->{app}->textbox({id => '"SLES-LTSS"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_separate_code}->exist();
}

sub set_regcode {
    my ($self, $addon, $code) = @_;
    my $key = "txb_$addon" . "_code";
    $self->{$key}->set($code);
}

1;
