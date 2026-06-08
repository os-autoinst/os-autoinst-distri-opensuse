# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Flexible License BYOS->PAYG and PAYG->BYOS
# Source: https://www.suse.com/c/switching-licensing-models-on-google-cloud-for-sles-and-sles-for-sap-instances-flexible-licenses/
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::ssh_interactive "select_host_console";
use publiccloud::utils qw(registercloudguest is_byos);
use version_utils 'is_sle';

sub run {
    my ($self, $args) = @_;

    select_host_console();
    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};
    my $instance_id = $instance->instance_id();
    my $zone = $provider->{provider_client}->region . "-" . $provider->{provider_client}->availability_zone;

    record_info('SUSEConnect', $instance->ssh_script_output("sudo SUSEConnect --status-text", timeout => 300));
    record_info('Repos', $instance->ssh_script_output("sudo zypper lr", timeout => 300));

    my ($old_license, $new_license);
    if (is_byos()) {
        record_info('BYOS->PAYG', "Switching from BYOS to on-demand");
        $old_license = 'projects/suse-byos-cloud/global/licenses/sles-15-byos';
        $new_license = 'projects/suse-cloud/global/licenses/sles-15';
    } else {
        record_info('PAYG->BYOS', "Switching from on-demand to BYOS");
        $old_license = 'projects/suse-cloud/global/licenses/sles-15';
        $new_license = 'projects/suse-byos-cloud/global/licenses/sles-15-byos';
    }

    $instance->ssh_assert_script_run("sudo systemctl stop guestregister-lic-watcher.timer") unless (is_sle('=12-SP5'));
    $instance->ssh_assert_script_run("sudo registercloudguest --clean", timeout => 180);

    record_info('Repos cleared', $instance->ssh_script_output("sudo zypper lr ||:", timeout => 300));

    $provider->stop_instance($instance);
    assert_script_run("gcloud compute disks update $instance_id --zone $zone --replace-license=$old_license,$new_license", timeout => 120);
    $provider->start_instance($instance);
    $instance->wait_for_ssh(scan_ssh_host_key => 1);

    if (is_byos()) {
        set_var('FLAVOR', 'GCE-Updates');
    } else {
        set_var('FLAVOR', 'GCE-BYOS-Updates');
    }

    registercloudguest($instance);
    record_info('SUSEConnect', $instance->ssh_script_output("sudo SUSEConnect --status-text", timeout => 300));
    record_info('Repos', $instance->ssh_script_output("sudo zypper lr", timeout => 300));
}

1;

