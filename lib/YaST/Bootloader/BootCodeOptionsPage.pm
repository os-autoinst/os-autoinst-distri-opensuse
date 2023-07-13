# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Boot Code Options tab
# in Boot Loader Settings.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Bootloader::BootCodeOptionsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{cmb_bootloader} = $self->{app}->combobox({id => "\"Bootloader::LoaderTypeWidget\""});
    $self->{chb_write_to_partition} = $self->{app}->checkbox({id => 'boot'});
    $self->{chb_bootdev} = $self->{app}->checkbox({id => 'mbr'});
    $self->{chb_custom_boot} = $self->{app}->checkbox({id => 'custom'});
    $self->{cmb_mbr_flag} = $self->{app}->combobox({id => '"Bootloader::PMBRWidget"'});
    $self->{chb_trusted_boot} = $self->{app}->checkbox({id => '"Bootloader::TrustedBootWidget"'});
    $self->{chb_generic_to_mbr} = $self->{app}->checkbox({id => '"Bootloader::GenericMBRWidget"'});
    $self->{chb_set_active_flag} = $self->{app}->checkbox({id => '"Bootloader::ActivateWidget"'});
    $self->{tab_boot_loader_settings} = $self->{app}->tab({id => '"CWM::DumbTabPager"'});
    $self->{btn_ok} = $self->{app}->button({id => 'next'});
    $self->{btn_cancel} = $self->{app}->button({id => 'abort'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_bootloader}->exist();
}

sub get_bootloader_type {
    my ($self) = @_;
    return $self->{cmb_bootloader}->value();
}

sub get_write_to_mbr {
    my ($self) = @_;
    return $self->{chb_bootdev}->is_checked();
}

sub get_write_to_custom {
    my ($self) = @_;
    return $self->{chb_custom_boot}->is_checked();
}

sub get_trusted_boot_support {
    my ($self) = @_;
    return $self->{chb_custom_boot}->is_checked();
}

sub get_write_to_partition {
    my ($self) = @_;
    return $self->{chb_write_to_partition}->is_checked();
}

sub get_protective_mbr_flag {
    my ($self) = @_;
    return $self->{cmb_mbr_flag}->value();
}

sub get_set_active_flag {
    my ($self) = @_;
    return $self->{chb_set_active_flag}->is_checked();
}

sub get_write_generic_to_mbr {
    my ($self) = @_;
    return $self->{chb_generic_to_mbr}->is_checked();
}

sub check_write_to_partition {
    my ($self) = @_;
    $self->{chb_write_to_partition}->check();
}

sub check_write_generic_to_mbr {
    my ($self) = @_;
    $self->{chb_generic_to_mbr}->check();
}

sub uncheck_write_to_mbr {
    my ($self) = @_;
    $self->{chb_bootdev}->uncheck();
}

sub switch_to_bootloader_options_tab {
    my ($self) = @_;
    $self->{tab_boot_loader_settings}->select('Bootloader Options');
}

sub switch_to_kernel_parameters_tab {
    my ($self) = @_;
    $self->{tab_boot_loader_settings}->select('Kernel Parameters');
}

1;
