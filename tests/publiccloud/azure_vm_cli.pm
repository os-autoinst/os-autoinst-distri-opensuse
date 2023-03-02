# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic azure_cli test
#
#   This test does the following
#    - Create SLES15 vm in azure
#    - Prepare public cloud and install azure_cli
#    - load azure_cli test
#
# Author: Yogalakshmi Arunachalam <yarunachalam@suse.com>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use publiccloud::utils;

our $azure_repo = get_required_var('PY_AZURE_REPO');
our $backports_repo = get_required_var('PY_BACKPORTS_REPO');
our $cloud_tools_repo = get_required_var('CLOUD_TOOLS_REPO');

sub run {
    my ($self, $args) = @_;
    select_serial_terminal();
    my $provider = $args->{my_provider};
    my $instance = $provider->create_instance();
    $instance->wait_for_guestregister();
    registercloudguest($instance) if is_byos();

    # call addons for pcm and phub
    # register module-public-cloud and PackageHub
    register_addons_in_pc($instance);

    #Add Repos and install azure-cli
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $azure_repo, timeout => 600);
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $backports_repo, timeout => 600);
    $instance->run_ssh_command(cmd => 'sudo zypper -n addrepo -fG ' . $cloud_tools_repo, timeout => 600);
    $instance->ssh_assert_script_run('sudo zypper ref; sudo zypper -n up', timeout => 300);
    $instance->ssh_assert_script_run('sudo zypper install --allow-vendor-change --force azure-cli', timeout => 300);


    record_info('azure cli installed');

    sleep 90;    # wait for a bit for zypper to be available

    loadtest 'publiccloud/azure_cli';
}

1;
