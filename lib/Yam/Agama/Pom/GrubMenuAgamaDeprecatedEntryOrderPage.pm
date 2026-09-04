# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB screen.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::GrubMenuAgamaDeprecatedEntryOrderPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        grub_menu_agama => $args->{grub_menu_agama},
        tag_first_entry_highlighted => 'grub-menu-first-entry-highlighted',
    }, $class;
}

sub select_install_product {
    record_info('bsc#1247438', 'Deprecated entry order is still present in this build. New entry order expected');
}

sub expect_is_shown { shift->{grub_menu_agama}->expect_is_shown() }

sub boot_from_hd { shift->{grub_menu_agama}->boot_from_hd() }

sub select_check_installation_medium_entry { shift->{grub_menu_agama}->select_check_installation_medium_entry() }

sub select_rescue_system_entry { shift->{grub_menu_agama}->select_rescue_system_entry() }

sub edit_current_entry { shift->{grub_menu_agama}->edit_current_entry() }

1;
