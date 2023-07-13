# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Kdump Firmware Assisted Dump Main Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Kdump::FADumpStartUpPage;
use parent 'YaST::Kdump::StartUpPage';
use strict;
use warnings;

sub init {
    my $self = shift;
    $self->SUPER::init();
    $self->{cbox_fadump} = $self->{app}->checkbox({id => "\"use_fadump\""});
    $self->{sect_navigation} = YaST::Kdump::NavigationPage->new();
    return $self;
}

sub get_firmware_assisted_dump_page {
    my ($self) = @_;
    die 'Firmware-Assisted Dump Page is not displayed' unless $self->{cbox_fadump}->exist();
    return $self;
}

sub use_firmware_assisted_dump {
    my ($self) = @_;
    $self->get_firmware_assisted_dump_page()->{cbox_fadump}->check();
    return $self;
}

1;
