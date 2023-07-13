# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This file handles the guest installation for ALP.
#          It supports configuring vm profiles with template.
#
# Maintainer: Alice <xlai@suse.com>, or VT squad <qe-virt@suse.de>

package alp_guest_installation;

use base unified_guest_installation;
use strict;
use warnings;
use testapi;
use Data::Dumper;

sub edit_guest_profile_with_template {
    my ($self, $guest_name, $_guest_config) = @_;
    my %_guest_config_from_testsuite = %$_guest_config;

    # Initialize config
    my %_guest_profile = %{$concurrent_guest_installations::guest_instances_profiles{$guest_name}};

    # Handle guest_boot_settings
    my $_boot_value = '';
    $_boot_value = 'uefi' if (get_var('VIRT_UEFI_GUEST_INSTALL', ''));
    $_boot_value = 'firmware=efi' if (get_var('VIRT_SEV_ES_GUEST_INSTALL', ''));
    $_guest_profile{guest_boot_settings} =~ s/##guest_boot_settings##/$_boot_value/g;

    # Handle guest_storage_others
    my $_backing_disk_name = $_guest_config_from_testsuite{BACKING_DISK};
    $_backing_disk_name =~ /([^\/]+)\.([^\/\.]+)$/m;
    my $_new_back_name = "$1-back.$2";
    my $_back_format = $2;
    $_guest_profile{guest_storage_others} =~ s/##backing_disk_name##/$_new_back_name/g;
    $_guest_profile{guest_storage_others} =~ s/##backing_format##/$_back_format/g;

    # Handle version
    my $_version = $_guest_config_from_testsuite{VM_VERSION};
    $_version =~ /[a-zA-Z]+-([0-9\.]+)/m;
    $_version = $1;
    $_guest_profile{guest_version} =~ s/##guest_version##/$_version/g;

    # Handle build
    my $_build = $_guest_config_from_testsuite{VM_BUILD};
    $_guest_profile{guest_build} =~ s/##guest_build##/$_build/g;

    # Handle SEV-ES realted settings
    my $_memory_back = '';
    my $_launch_security = '';
    if (get_var('VIRT_SEV_ES_GUEST_INSTALL', '')) {
        $_memory_back = 'locked=yes';
        $_launch_security = 'sev,policy=0x07';
    }
    $_guest_profile{guest_memorybacking} =~ s/##guest_memorybacking##/$_memory_back/g;
    $_guest_profile{guest_launchsecurity} =~ s/##guest_launchsecurity##/$_launch_security/g;

    # TODO: when alp products other than bedrock/micro need to test,
    #       more extensions may be needed here

    # Overwrite $guest_instances_profiles
    $concurrent_guest_installations::guest_instances_profiles{$guest_name} = \%_guest_profile;
    record_info("$guest_name profile has been created from template.", "Content is:\n" . Dumper($concurrent_guest_installations::guest_instances_profiles{$guest_name}));
}

1;
