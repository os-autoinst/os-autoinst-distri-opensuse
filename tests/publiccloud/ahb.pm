# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test AHB extension
# Maintainer: jesusbv@suse.com
# Author: jesusbv <jesusbv@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

our @license_types = split(
    ",", get_var('PUBLIC_CLOUD_AHB_LT', 'SLES_BYOS')
);
our $api_version = get_var('PUBLIC_CLOUD_AHB_API_VERSION', '2021-02-01');

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;
    my $job_id = get_current_job_id();

    my $provider = $self->provider_factory();
    my $instance = $provider->create_instance();
    $instance->wait_for_guestregister();
    # resource group
    # get instance resource group
    my $resource_group_command = "curl -s -H Metadata:true --noproxy \"*\" \"http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=$api_version&format=text\"";
    my $vm_name_command = "hostname -s";
    my $resource_group = $instance->run_ssh_command(cmd => $resource_group_command);
    my $vm_name = $instance->run_ssh_command(cmd => $vm_name_command);
    my $curl_command = "curl -s -H Metadata:true --noproxy \"*\" \"http://169.254.169.254/metadata/instance/compute?api-version=$api_version\" | cut -d\, -f5-5  | cut -d\: -f 2";
    my $license_type = $instance->run_ssh_command(cmd => $curl_command);
    # loop over the different license types
    foreach my $license_type_change (@license_types) {
        # update license type to license_type_change
        my $update_license_command = "az vm update -g $resource_group -n $vm_name --license-type '$license_type_change'";
        assert_script_run($update_license_command);
        # sleep for 2 min, so license type changes and timer/service re runs
        sleep 120;
        my $instance_license_type = $instance->run_ssh_command(cmd => $curl_command);
        die("Wrong license type: $instance_license_type instead of expected: $license_type_change") if ($instance_license_type ne "\"$license_type_change\"");
        record_info("CHECK OK", "License type has the expected value $instance_license_type");
    }
}

1;
