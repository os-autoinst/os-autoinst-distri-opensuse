# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Prepare ignition or combustion configuration file for first boot
# configuration
# Maintainer: Wayne Chen <wchen@suse.com>

use base "opensusebasetest";
use testapi;
use utils qw(is_ipxe_boot);
use autoyast qw(expand_template expand_variables upload_profile);

sub run {
    my $self = shift;

    my $firstboot_config = get_var("FIRST_BOOT_CONFIG");
    if (!$firstboot_config) {
        record_info("No firstboot config provided", "Please confirm setting FIRST_BOOT_CONFIG");
        return;
    }
    if ($firstboot_config =~ /ignition/ig) {
        my $ignition_path =
          get_required_var('FIRSTBOOT_CONFIG_DIR') . "/ignition/config.ign." . get_required_var('ARCH') . ".ep";
        set_var('IGNITION_PATH', autoinst_url("/files/" . $self->prepare_profile(path => $ignition_path)));
        record_info("Ignition config is available at:", get_required_var('IGNITION_PATH'));
    }
    if ($firstboot_config =~ /combustion/ig) {
        my $combustion_path =
          get_required_var('FIRSTBOOT_CONFIG_DIR') . "/combustion/script." . get_required_var('ARCH') . ".ep";
        set_var('COMBUSTION_PATH', autoinst_url("/files/" . $self->prepare_profile(path => $combustion_path)));
        record_info("Combustion config is available at:", get_required_var('COMBUSTION_PATH'));
    }
}

sub prepare_profile {
    my ($self, %args) = @_;
    $args{path} //= '';
    die("Profile path must be provided") if (!$args{path});

    my $profile = get_test_data($args{path});
    $profile = expand_template($profile) if ($args{path} =~ s/^(.*)\.ep$/$1/);
    $profile = expand_variables($profile);
    my $path = $args{path};
    $path = join('/', get_required_var('SUT_IP'), $args{path}) if (is_ipxe_boot);
    upload_profile(profile => $profile, path => $path);
    return $path;
}

sub test_flags {
    return {fatal => 1};
}

1;
