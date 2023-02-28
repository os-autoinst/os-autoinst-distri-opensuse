# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller for YaST bootloader module.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Bootloader::BootloaderSettingsController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Bootloader::BootCodeOptionsPage;
use YaST::Bootloader::KernelParametersPage;
use YaST::Bootloader::BootloaderOptionsPage;
use YaST::Bootloader::BootloaderOptionsNavTab 'use_navigating_tabs';

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{BootCodeOptionsPage} = YaST::Bootloader::BootCodeOptionsPage->new({app => YuiRestClient::get_app()});
    $self->{KernelParametersPage} = YaST::Bootloader::KernelParametersPage->new({app => YuiRestClient::get_app()});
    $self->{BootloaderOptionsPage} = YaST::Bootloader::BootloaderOptionsPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_boot_code_options_page {
    my ($self) = @_;
    die 'Boot Code Options tab is not shown' unless $self->{BootCodeOptionsPage}->is_shown();
    return $self->{BootCodeOptionsPage};
}

sub get_kernel_parameters_page {
    my ($self) = @_;
    die 'Kernel Parameters tab is not shown' unless $self->{KernelParametersPage}->is_shown();
    return $self->{KernelParametersPage};
}

sub get_bootloader_options_page {
    my ($self) = @_;
    die 'Bootloader Options tab is not shown' unless $self->{BootloaderOptionsPage}->is_shown();
    return $self->{BootloaderOptionsPage};
}

sub get_current_settings {
    my ($self) = @_;
    my %current_settings;
    $current_settings{bootloader_type} = $self->get_boot_code_options_page->get_bootloader_type();
    $current_settings{write_to_partition} = $self->get_boot_code_options_page->get_write_to_partition();
    $current_settings{write_to_mbr} = $self->get_boot_code_options_page->get_write_to_mbr();
    $current_settings{select_custom_boot_partition} = $self->get_boot_code_options_page->get_write_to_custom();
    $current_settings{set_active_flag} = $self->get_boot_code_options_page->get_set_active_flag();
    $current_settings{write_generic_to_mbr} = $self->get_boot_code_options_page->get_write_generic_to_mbr();
    $current_settings{trusted_boot_support} = $self->get_boot_code_options_page->get_trusted_boot_support();
    $current_settings{protective_mbr_flag} = $self->get_boot_code_options_page->get_protective_mbr_flag();
    $self->get_boot_code_options_page->press_next();
    return %current_settings;
}

sub write_generic_to_mbr {
    my ($self) = @_;
    $self->get_boot_code_options_page->check_write_generic_to_mbr();
    $self->get_boot_code_options_page->press_next();
}

sub dont_write_to_mbr {
    my ($self) = @_;
    $self->get_boot_code_options_page->uncheck_write_to_mbr();
    $self->get_boot_code_options_page->press_next();
}

sub write_to_partition {
    my ($self) = @_;
    $self->get_boot_code_options_page->check_write_to_partition();
    $self->get_boot_code_options_page->press_next();
}

sub disable_grub_timeout_navigating_tabs {
    my ($self) = @_;
    use_navigating_tabs();
    $self->get_bootloader_options_page->set_grub_timeout('-1');
    $self->get_bootloader_options_page->press_next();
}

sub disable_grub_timeout {
    my ($self) = @_;
    $self->get_boot_code_options_page->switch_to_bootloader_options_tab();
    $self->get_bootloader_options_page->set_grub_timeout('-1');
    $self->get_bootloader_options_page->press_next();
}

sub disable_plymouth {
    my ($self) = @_;
    $self->get_boot_code_options_page()->switch_to_kernel_parameters_tab();
    my $param = $self->get_kernel_parameters_page()->get_optional_kernel_param();
    $param =~ s/plymouth.*?\s+//g;
    $self->get_kernel_parameters_page()->set_optional_kernel_param($param);
    $self->get_kernel_parameters_page()->press_next();
}

1;
