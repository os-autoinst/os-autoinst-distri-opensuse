# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Bootloader Options tab
# in Boot Loader Settings.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Bootloader::BootloaderOptionsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{txb_grub_timeout} = $self->{app}->textbox({id => "\"Bootloader::TimeoutWidget\""});
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

1;
