# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Bootloader Options tab
# in Boot Loader Settings.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package YaST::Bootloader::BootloaderOptionsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;


sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{txb_grub_timeout} = $self->{app}->textbox({id => qr /"Bootloader::.*TimeoutWidget"/});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    $self->{txb_grub_timeout}->exist();
}

sub set_grub_timeout {
    my ($self, $timeout) = @_;
    $self->{txb_grub_timeout}->set($timeout);
}

sub bls_disable_timeout {
    my ($self) = @_;
    $self->{chb_automatically_boot} = $self->{app}->checkbox({id => 'cont_boot'});
    $self->{chb_automatically_boot}->uncheck();
}

1;
