# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Controller for YaST bootloader module.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Bootloader::BootloaderSettingsController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Bootloader::BootCodeOptionsPage;
use YaST::Bootloader::BootloaderOptionsPage;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{BootCodePage} = YaST::Bootloader::BootCodeOptionsPage->new({app => YuiRestClient::get_app()});
    $self->{BootloaderPage} = YaST::Bootloader::BootloaderOptionsPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_boot_code_options_page {
    my ($self) = @_;
    die "Boot code options tab is not shown" unless $self->{BootCodePage}->is_shown();
    return $self->{BootCodePage};
}

sub get_bootloader_options_page {
    my ($self) = @_;
    die "Boot loader options tab is not shown" unless $self->{BootloaderPage}->is_shown();
    return $self->{BootloaderPage};
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

sub disable_grub_timeout {
    my ($self) = @_;
    $self->get_boot_code_options_page->switch_tab_bootloader_options();
    $self->get_bootloader_options_page->disable_grub_timeout();
    $self->get_bootloader_options_page->press_next();
}

1;
