# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Boot loader options tab in bootloader module
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Bootloader::BootloaderOptionsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{txt_grub_timeout} = $self->{app}->textbox({id => "\"Bootloader::TimeoutWidget\""});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    $self->{txt_grub_timeout}->exist();
}

sub disable_grub_timeout {
    my ($self) = @_;
    $self->{txt_grub_timeout}->set("-1");
}

1;
