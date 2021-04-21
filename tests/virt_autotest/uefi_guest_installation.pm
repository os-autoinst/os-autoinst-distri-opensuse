# CONCURRENT UEFI VIRTUAL MACHINE INSTALLATIONS MODULE
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: This module supports concurrent multiple uefi virtual machine
# installations with vm names and profiles obtained from UEFI_GUEST_LIST
# and UEFI_GUEST_PROFILES respectively. There is no restriction on vm names
# to be used, so any desired vm names can be given to UEFI_GUEST_LIST=
# "vm_name_1,vm_name_2,vm_name_3". Similary,any vm profile names can be
# given to UEFI_GUEST_PROFILES,as long as there are corresponding profile
# files in data/virt_autotest/guest_params_xml_files folder, for example,
# there should be profile file called vm_profile_1.xml,vm_profile_2.xml
# and vm_profile_3.xml in the folder if UEFI_GUEST_PROFILES="vm_profile_1,
# vm_profile_2,vm_profile_3".Then vm_name_1 will be created and installed
# using vm_profile_1 and so on by calling:
# generate_guest_instances,
# generate_guest_profiles and
# install_guest_instances.
# Installation progress monitoring,result validation, junit log provision,
# environment cleanup and failure handling are also included and supported
# by calling other subroutines:
# monitor_concurrent_guest_installations
# validate_guest_installations_results
# clean_up_guest_installations and
# junit_log_provision.
# All above called subroutines are wrapped up in one single subroutine:
# concurrent_guest_installations_run base concurrent_guest_installations.
#
# Please refer to lib/concurrent_guest_installations for detailed information
# about subroutines in base module being called.
#
# Maintainer: Wayne Chen <wchen@suse.com>
package uefi_guest_installation;

use base 'concurrent_guest_installations';
use strict;
use warnings;
use testapi;
use Carp;

sub run {
    my $self = shift;

    $self->reveal_myself;
    my @guest_names    = split(/,/, get_required_var('UEFI_GUEST_LIST'));
    my @guest_profiles = split(/,/, get_required_var('UEFI_GUEST_PROFILES'));
    croak("Guest names and profiles must be given to create, configure and install guests.") if ((scalar(@guest_names) eq 0) or (scalar(@guest_profiles) eq 0));
    $self->concurrent_guest_installations_run(\@guest_names, \@guest_profiles);
    return $self;
}

sub post_fail_hook {
    my $self = shift;

    $self->reveal_myself;
    $self->SUPER::post_fail_hook;
    return $self;
}

1;
