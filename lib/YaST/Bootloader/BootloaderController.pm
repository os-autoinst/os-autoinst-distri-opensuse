# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Controller for YaST bootloader module.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Bootloader::BootloaderController;
use strict;
use warnings;
use YuiRestClient;
use YaST::Bootloader::BootCodeOptionsPage;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{BootCodePage} = YaST::Bootloader::BootCodeOptionsPage->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_boot_code_options_page {
    my ($self) = @_;
    die "Boot code options tab is not shown" unless $self->{BootCodePage}->is_shown();
    return $self->{BootCodePage};
}

sub get_current_settings {
    my ($self) = @_;
    my %current_settings;
    $current_settings{bootloader_type}              = $self->get_boot_code_options_page->get_bootloader_type();
    $current_settings{write_to_partition}           = $self->get_boot_code_options_page->get_write_to_partition();
    $current_settings{write_to_mbr}                 = $self->get_boot_code_options_page->get_write_to_mbr();
    $current_settings{select_custom_boot_partition} = $self->get_boot_code_options_page->get_write_to_custom();
    $current_settings{set_active_flag}              = $self->get_boot_code_options_page->get_set_active_flag();
    $current_settings{write_generic_to_mbr}         = $self->get_boot_code_options_page->get_write_generic_to_mbr();
    $current_settings{trusted_boot_support}         = $self->get_boot_code_options_page->get_trusted_boot_support();
    $current_settings{protective_mbr_flag}          = $self->get_boot_code_options_page->get_protective_mbr_flag();
    return %current_settings;
}

sub write_generic_to_mbr {
    my ($self) = @_;
    $self->get_boot_code_options_page->check_write_generic_to_mbr();
}

sub dont_write_to_mbr {
    my ($self) = @_;
    $self->get_boot_code_options_page->uncheck_write_to_mbr();
}

sub write_to_partition {
    my ($self) = @_;
    $self->get_boot_code_options_page->check_write_to_partition();
}

sub accept_changes {
    my ($self) = @_;
    $self->get_boot_code_options_page->press_ok();
}

sub cancel_changes {
    my ($self) = @_;
    $self->get_boot_code_options_page->press_cancel();
}

1;
