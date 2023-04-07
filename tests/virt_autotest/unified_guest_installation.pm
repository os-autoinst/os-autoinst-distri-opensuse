# CONCURRENT UEFI VIRTUAL MACHINE INSTALLATIONS MODULE
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module supports concurrent multiple virtual machines
# installations with vm names and profiles obtained from UNIFIED_GUEST_LIST
# and UNIFIED_GUEST_PROFILES respectively. There is no restriction on vm names
# to be used, so any desired vm names can be given to UNIFIED_GUEST_LIST=
# "vm_name_1,vm_name_2,vm_name_3". Similary,any vm profile names can be
# given to UNIFIED_GUEST_PROFILES,as long as there are corresponding profile
# files in data/virt_autotest/guest_params_xml_files folder, for example,
# there should be profile file called vm_profile_1.xml,vm_profile_2.xml
# and vm_profile_3.xml in the folder if UNIFIED_GUEST_PROFILES="vm_profile_1,
# vm_profile_2,vm_profile_3".Then vm_name_1 will be created and installed
# using vm_profile_1 and so on by calling instantiate_guests_and_profiles
# and install_guest_instances.
# This module also supports to use guest profile templates to dynamically
# generate profiles. The function can be switched on or off, on per-vm basis.
# If UNIFIED_GUEST_PROFILE_TEMPLATE_FLAGS is set to '1' at the vm's position
# (separated by ',' from string), the UNIFIED_GUEST_PROFILES's value at the same position,
# will be used as the guest profile template, which will then be updated in code
# to generate the final profile for vm installation. The purpose for this is to
# save too many similar profiles in data/virt_autotest/guest_params_xml_files folder.
# For example, if UNIFIED_GUEST_PROFILE_TEMPLATE_FLAGS is set to '0,1,0',
# the second vm's profile will be generated based on template file given in
# UNIFIED_GUEST_PROFILES[1], while the other two vms use static profiles
# specified in UNIFIED_GUEST_PROFILES[0]/[2].
# UNIFIED_GUEST_REG_CODES and UNIFIED_GUEST_REG_EXTS_CODES are two other
# test suite level settings which are given guest os registration codes
# and codes for additional modules/extensions/products to be used by guests.
# For example, for above UNIFIED_GUEST_LIST setting, UNIFIED_GUEST_REG_CODES
# = "vm1_code,vm2_code,vm3_code" and UNIFIED_GUEST_REG_EXTS_CODES = "
# vm1ext1code#vm1ext2code,vm2ext1code#vm2ext2code#vm2ext3code,vm3ext1code".
# Registration codes for different guests should be separated by comma and
# for different modules/extensions/products but the same guest should be
# separated by hash. If not all guests to be installed need code settings,
# those that do not need should be left empty but with explicit separator,
# for example, UNIFIED_GUEST_REG_EXTS_CODES = ",#vm2ext2code#vm2ext3code,",
# UNIFIED_GUEST_REG_CODES = "vm1_code,vm2_code,". The codes for each guest
# will be assigned to guest parameters [guest_registration_code] and
# [guest_registration_extensions_codes], so please refer to base module
# lib/concurrent_guest_installations for detailed information about them.
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
package unified_guest_installation;

use base 'concurrent_guest_installations';
use strict;
use warnings;
use testapi;
use Carp;
use virt_autotest::utils qw(check_guest_health);

sub run {
    my $self = shift;

    $self->reveal_myself;
    my @guest_names = split(/,/, get_required_var('UNIFIED_GUEST_LIST'));
    my @guest_profiles = split(/,/, get_required_var('UNIFIED_GUEST_PROFILES'));
    croak("Guest names and profiles must be given to create, configure and install guests.") if ((scalar(@guest_names) eq 0) or (scalar(@guest_profiles) eq 0));
    my %store_of_guests;
    my @guest_registration_codes = my @guest_registration_extensions_codes = my @guest_profile_template_flags = ('') x scalar @guest_names;
    @guest_registration_codes = split(/,/, get_var('UNIFIED_GUEST_REG_CODES', '')) if (get_var('UNIFIED_GUEST_REG_CODES', '') ne '');
    @guest_registration_extensions_codes = split(/,/, get_var('UNIFIED_GUEST_REG_EXTS_CODES', '')) if (get_var('UNIFIED_GUEST_REG_EXTS_CODES', '') ne '');
    @guest_profile_template_flags = split(/,/, get_var('UNIFIED_GUEST_PROFILE_TEMPLATE_FLAGS', '')) if (get_var('UNIFIED_GUEST_PROFILE_TEMPLATE_FLAGS', '') ne '');
    while (my ($index, $element) = each @guest_names) {
        $store_of_guests{$element}{PROFILE} = $guest_profiles[$index];
        $store_of_guests{$element}{REG_CODE} = $guest_registration_codes[$index];
        $store_of_guests{$element}{REG_EXTS_CODES} = $guest_registration_extensions_codes[$index];
        $store_of_guests{$element}{USE_TEMPLATE} = $guest_profile_template_flags[$index];
    }

    $self->concurrent_guest_installations_run(\%store_of_guests);
    check_guest_health($_) foreach (@guest_names);
    return $self;
}

sub post_fail_hook {
    my $self = shift;

    $self->reveal_myself;
    $self->SUPER::post_fail_hook;
    return $self;
}

1;
