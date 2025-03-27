# SUSE's openQA tests
#
# Copyright 2022-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-regionsrv-client
# Summary: Test system (re)registration
# https://github.com/SUSE-Enceladus/cloud-regionsrv-client/blob/master/integration_test-process.txt
# Leave system in *registered* state
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use version_utils;
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils;
use publiccloud::ssh_interactive 'select_host_console';

our $run_count = 0;

my $path = is_sle('=15-SP2') ? '/usr/sbin/' : '';    # 15-SP2 is the oldest version that needs fullpaths
my $regcode_param = (is_byos()) ? "-r " . get_required_var('SCC_REGCODE') : '';

sub run {
    my ($self, $args) = @_;
    my ($provider, $instance);
    select_host_console();

    $run_count++;

    # $self->{my_instance} is used in this test module
    # $args->{my_instance} is used in base module
    # $args->{my_provider} is used in base module
    if (get_var('PUBLIC_CLOUD_QAM', 0)) {
        $provider = $args->{my_provider};
        $instance = $self->{my_instance} = $args->{my_instance};
    } else {
        $provider = $args->{my_provider} = $self->provider_factory();
        $instance = $self->{my_instance} = $args->{my_instance} = $provider->create_instance(check_guestregister => is_openstack ? 0 : 1);
    }

    if (check_var('PUBLIC_CLOUD_SCC_ENDPOINT', 'SUSEConnect')) {
        record_info('SKIP', 'PUBLIC_CLOUD_SCC_ENDPOINT is hardcoded to SUSEConnect - skipping registration testing. Falling back to registration module behavior');
        registercloudguest($instance) if (is_byos() || get_var('PUBLIC_CLOUD_FORCE_REGISTRATION'));
        register_addons_in_pc($instance);
        return;
    }

    # this is special use case needed by dev ops team within SUSE. Should not be used for any product testing.
    # Use this variable ONLY if you really know what you are doing!
    if (check_var('PUBLIC_CLOUD_INFRA', '1')) {
        my $prefix = "PREPARATION PHASE.";
        my $rmt_ipv4 = get_required_var("PUBLIC_CLOUD_INFRA_RMT_V4");
        my $rmt_ipv6 = get_required_var("PUBLIC_CLOUD_INFRA_RMT_V6");
        if (is_ondemand()) {
            $instance->ssh_assert_script_run(cmd => "sudo ${path}registercloudguest --clean", fail_message => "$prefix registercloudguest --clean failed");
            $instance->ssh_script_run(cmd => 'sudo rm /var/log/cloudregister; sudo rm /etc/pki/trust/anchors/*.pem', fail_message => "$prefix Deletion of register log and/or certificates failed");
        }
        $instance->ssh_script_run(cmd => "sudo sed -i \"s/regionsrv.*\$/regionsrv = $rmt_ipv4,$rmt_ipv6/\" /etc/regionserverclnt.cfg");
        $instance->ssh_assert_script_run(cmd => "sudo grep \"regionsrv = $rmt_ipv4,$rmt_ipv6\" /etc/regionserverclnt.cfg", fail_message => "$prefix regionserverclnt.cfg update failed");
        $instance->ssh_assert_script_run(cmd => "sudo curl -k -O --output-dir /usr/lib/regionService/certs https://$rmt_ipv4/$rmt_ipv4.pem", fail_message => "$prefix Download of test cert failed");
        $instance->ssh_assert_script_run(cmd => 'sudo update-ca-certificates', fail_message => "$prefix update-ca-certificates failed");
        $instance->ssh_assert_script_run(cmd => "sudo registercloudguest $regcode_param", timeout => 300);
        check_instance_registered($instance);
    } elsif (is_container_host()) {
        # CHOST images don't have registercloudguest pre-installed. To install it we need to register which make it impossible to do
        # all BYOS related checks. So we just regestering system and going further
        registercloudguest($instance);
    } elsif (is_byos()) {
        if (check_var('PUBLIC_CLOUD_CHECK_CLOUDREGISTER_EXECUTED', '1')) {
            $instance->ssh_assert_script_run(cmd => "sudo ${path}registercloudguest --clean", fail_message => 'Failed to deregister the previously registered BYOS system');
            $instance->ssh_script_run(cmd => 'sudo rm /etc/zypp/repos.d/*.repo');
        } else {
            check_instance_unregistered($instance, 'The BYOS instance should be unregistered and report "Warning: No repositories defined.".');
            if ($instance->ssh_script_output(cmd => 'sudo systemctl is-enabled guestregister.service', proceed_on_failure => 1) !~ /disabled/) {
                die('guestregister.service is not disabled');
            }

            if (is_azure() && $instance->ssh_assert_script_run(cmd => 'sudo systemctl is-enabled regionsrv-enabler-azure.timer')) {
                die('regionsrv-enabler-azure.timer is not enabled');
            }

            if ($instance->ssh_script_run(cmd => 'sudo test -s /var/log/cloudregister') == 0) {
                die('/var/log/cloudregister is not empty');
            }
            $instance->ssh_assert_script_run(cmd => '! sudo SUSEConnect -d', fail_message => 'SUSEConnect succeeds but it is not supported should fail on BYOS');
        }
    } else {
        check_instance_registered($instance);
        if ($instance->ssh_script_output(cmd => 'sudo systemctl is-enabled guestregister.service', proceed_on_failure => 1) !~ /enabled/) {
            die('guestregister.service is not enabled');
        }

        if ($instance->ssh_script_output(cmd => 'sudo stat --printf="%s" /var/log/cloudregister') == 0) {
            die('/var/log/cloudregister is empty');
        }
    }

    cleanup_instance($instance);
    # It might take a bit for the system to remove the repositories
    foreach my $i (1 .. 4) {
        last if ($instance->ssh_script_output(cmd => 'LANG=C zypper -t lr | awk "/^\s?[[:digit:]]+/{c++} END {print c}"', timeout => 300) == 0);
        sleep 15;
    }
    check_instance_unregistered($instance, 'The list of zypper repositories is not empty.');

    # The SUSEConnect registration should still work on BYOS
    if (is_byos()) {
        $instance->ssh_assert_script_run(cmd => 'sudo SUSEConnect --version');
        $instance->ssh_assert_script_run(cmd => "sudo SUSEConnect $regcode_param");
        cleanup_instance($instance);
    }

    new_registration($instance);

    test_container_runtimes($instance) if (is_sle('>=15-SP5'));

    force_new_registration($instance);

    register_addons_in_pc($instance);

    set_var('PUBLIC_CLOUD_CHECK_CLOUDREGISTER_EXECUTED', '1');
}

sub check_instance_registered {
    my ($instance) = @_;
    if ($instance->ssh_script_output(cmd => 'LANG=C zypper -t lr | awk "/^\s?[[:digit:]]+/{c++} END {print c}"', timeout => 300) == 0) {
        record_info('zypper lr', $instance->ssh_script_output(cmd => 'zypper -t lr ||:'));
        die('The list of zypper repositories is empty.');
    }
    if ($instance->ssh_script_output(cmd => 'sudo ls /etc/zypp/credentials.d/ | wc -l') == 0) {
        die('Directory /etc/zypp/credentials.d/ is empty.');
    }
}

sub check_instance_unregistered {
    my ($instance, $error) = @_;
    if ($instance->ssh_script_output(cmd => 'sudo ls /etc/zypp/credentials.d/ | wc -l') != 0) {
        my $creds_output = $instance->ssh_script_output(cmd => 'sudo ls -la /etc/zypp/credentials.d/');
        die("/etc/zypp/credentials.d/ is not empty:\n" . $creds_output);
    }
    my $out = $instance->ssh_script_output(cmd => 'zypper -t lr ||:', timeout => 300);
    return if ($out =~ /No repositories defined/m);

    for (split('\n', $out)) {
        if ($_ =~ /^\s?\d+/ && $_ !~ /SUSE_Maintenance/) {
            record_info('zypper lr', $out);
            die($error);
        }
    }
}

sub new_registration {
    my ($instance) = @_;
    record_info('Starting registration...');
    $instance->ssh_script_retry(cmd => "sudo ${path}registercloudguest $regcode_param", timeout => 300, retry => 3, delay => 120);
    check_instance_registered($instance);
    return 0;
}

sub test_container_runtimes {
    my ($instance) = @_;
    my $image = "registry.suse.com/bci/bci-base:latest";

    record_info('Test docker');
    $instance->ssh_assert_script_run("sudo rm -f /root/.docker/config.json");    # workaround for https://bugzilla.suse.com/show_bug.cgi?id=1231185
    $instance->ssh_assert_script_run("sudo zypper install -y docker", timeout => 300);
    $instance->ssh_assert_script_run("sudo systemctl start docker.service");
    record_info("systemctl status docker.service", $instance->ssh_script_output("systemctl status docker.service"));
    $instance->ssh_script_retry("sudo docker pull $image", retry => 3, delay => 60, timeout => 600);
    $instance->ssh_assert_script_run("sudo systemctl stop docker.service");

    record_info('Test podman');
    # cloud-regionsrv-client creates registries.conf file if it is not pre-installed from the package
    # in such a case the umask of the file is wrong
    # registercloudguest should not change the permissions of already existing file
    if ($instance->ssh_script_output(cmd => 'sudo stat -c "%a" /etc/containers/registries.conf') != 644) {
        record_soft_failure('bsc#1233333');
        if ($instance->ssh_script_run('sudo rpm -q libcontainers-common')) {
            record_info('permissions #1', 'permissions when libcontainers-common is missing');
            $instance->ssh_script_run('sudo stat /etc/containers/registries.conf');
            $instance->ssh_script_run('sudo rm -rf /etc/containers/registries.conf');
            $instance->ssh_assert_script_run("sudo zypper -n install libcontainers-common");
            record_info('permissions #2', 'The previous registries.conf has been removed, then libcontainers-common was installed');
            $instance->ssh_script_run('sudo stat /etc/containers/registries.conf');
            cleanup_instance($instance);
            new_registration($instance);
            record_info('permissions #3', 'The libcontainers-common is present and then the image was re-registered');
            $instance->ssh_script_run('sudo stat /etc/containers/registries.conf');
        }
        $instance->ssh_script_run('sudo chmod 644 /etc/containers/registries.conf');
    }
    $instance->ssh_assert_script_run("sudo zypper install -y podman", timeout => 240);
    $instance->ssh_script_retry("podman --debug pull $image", retry => 3, delay => 60, timeout => 600);
    return 0;
}

sub cleanup_instance {
    my ($instance) = @_;
    record_info('Removing registration data');
    $instance->ssh_assert_script_run(cmd => "sudo ${path}registercloudguest --clean");
    check_instance_unregistered($instance);
}

sub force_new_registration {
    my ($instance) = @_;
    record_info('Forcing a new registration...');
    $instance->ssh_script_retry(cmd => "sudo ${path}registercloudguest $regcode_param --force-new", timeout => 300, retry => 3, delay => 120);
    check_instance_registered($instance);
    return 0;
}

sub post_fail_hook {
    my ($self) = @_;
    if (exists($self->{my_instance})) {
        $self->{my_instance}->ssh_script_run("sudo chmod a+r /var/log/cloudregister", timeout => 0, quiet => 1);
        $self->{my_instance}->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log.txt');
    }
    if (is_azure()) {
        record_info('azuremetadata', $self->{my_instance}->run_ssh_command(cmd => "sudo /usr/bin/azuremetadata --api latest --subscriptionId --billingTag --attestedData --signature --xml"));
    }
    $self->SUPER::post_fail_hook();
    registercloudguest($self->{my_instance});
}

sub test_flags {
    if (check_var('PUBLIC_CLOUD_QAM', 1)) {
        if ($run_count == 1) {
            # If we are in multi module scenario and this is the first run of the test module we wanna not fail the whole run
            return {fatal => 0, publiccloud_multi_module => 1};
        }
        # If we are in multi module scenario and this is not the first run of this test module we wanna fail the whole run
        return {fatal => 1, publiccloud_multi_module => 1};
    }
    # If we are not in multi module scenario it is always the first run and we wanna run basetest cleanup
    return {fatal => 1, publiccloud_multi_module => 0};
}

1;
