# SUSE's openQA tests
#
# Copyright 2022-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-regionsrv-client
# Summary: Test system (re)registration
# https://github.com/SUSE-Enceladus/cloud-regionsrv-client/blob/master/integration_test-process.txt
# Leave system in *registered* state
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use version_utils;
use registration;
use testapi;
use utils;
use publiccloud::utils;
use publiccloud::zypper qw(pc_pkg_call);
use publiccloud::ssh_interactive 'select_host_console';
use 5.018;

our $run_count = 0;
my $archive = '/var/log/cloudregister_logs.tar';

my $regcode_param = (is_byos()) ? "-r " . get_required_var('SCC_REGCODE') : '';

sub rotate_cloudregister_log {
    my $i = shift;
    my $logfile = '/var/log/cloudregister';
    state $counter = 0;

    # nothing to rotate, either empty or non-existing
    return if ($i->ssh_script_run("test -s $logfile"));

    # rotate and add the rotated file into archive
    $i->ssh_assert_script_run(sprintf('sudo mv %s %s%d', $logfile, $logfile, ++$counter));
    $i->ssh_assert_script_run("sudo touch $logfile");
    $i->ssh_assert_script_run(sprintf('sudo tar --append --file=%s %s%d', $archive, $logfile, $counter));
}

sub run {
    my ($self, $args) = @_;
    my ($provider, $instance);
    select_host_console();

    $run_count++;

    # $self->{my_instance} is used in this test module
    # $args->{my_instance} is used in base module
    # $args->{my_provider} is used in base module
    $provider = $args->{my_provider};
    $instance = $self->{my_instance} = $args->{my_instance};

    if (check_var('PUBLIC_CLOUD_SCC_ENDPOINT', 'SUSEConnect')) {
        record_info('SKIP', 'PUBLIC_CLOUD_SCC_ENDPOINT is hardcoded to SUSEConnect - skipping registration testing. Falling back to registration module behavior');
        rotate_cloudregister_log($instance);
        registercloudguest($instance) if (is_byos() || get_var('PUBLIC_CLOUD_FORCE_REGISTRATION'));
        register_addons_in_pc($instance);
        return;
    }

    if (is_container_host()) {
        # CHOST images don't have registercloudguest pre-installed. To install it we need to register which make it impossible to do
        # all BYOS related checks. So we just regestering system and going further
        rotate_cloudregister_log($instance);
        registercloudguest($instance);
    } elsif (is_byos()) {
        if (check_var('PUBLIC_CLOUD_CHECK_CLOUDREGISTER_EXECUTED', '1')) {
            rotate_cloudregister_log($instance);
            $instance->ssh_assert_script_run(cmd => "sudo registercloudguest --clean", fail_message => 'Failed to deregister the previously registered BYOS system');
        } else {
            check_instance_unregistered($instance, 'The BYOS instance should be unregistered and report "Warning: No repositories defined.".');
            if ($instance->ssh_script_output(cmd => 'sudo systemctl is-enabled guestregister.service', proceed_on_failure => 1) !~ /disabled/) {
                die('guestregister.service is not disabled');
            }

            # The cloud-regionsrv-client-license-watcher package is only useful on Azure and GCE as they offer
            # the feature to switch from BYOS to PAYG and vice versa.  AWS doesn't have this capability yet.
            if (!is_ec2() && $instance->ssh_script_run('systemctl is-active guestregister-lic-watcher.timer') != 0) {
                # guestregister-lic-watcher.timer replaces regionsrv-enabler-azure.timer on all images except Azure 12-SP5.
                if (is_sle("=12-SP5") && is_azure) {
                    $instance->ssh_assert_script_run('systemctl is-active regionsrv-enabler-azure.timer', fail_message => "neither guestregister-lic-watcher.timer nor regionsrv-enabler-azure.timer is not present");
                    $instance->ssh_assert_script_run('systemctl show guestregister-lic-watcher.timer | grep LoadState=not-found', fail_message => "guestregister-lic-watcher.timer must not be present when regionsrv-enabler-azure.timer is there");
                } else {
                    die "guestregister-lic-watcher.timer is not active";
                }
            } elsif (is_azure()) {
                record_soft_failure('poo#190068 - The legacy check for regionsrv-enabler-azure.timer should be removed') if is_sle("=12-SP5");
                # Ensure the legacy timer is not present
                $instance->ssh_assert_script_run('systemctl show regionsrv-enabler-azure.timer | grep LoadState=not-found', fail_message => "regionsrv-enabler-azure.timer must not be present");
            }

            if ($instance->ssh_script_run(cmd => 'sudo test -s /var/log/cloudregister') == 0) {
                die('/var/log/cloudregister is not empty');
            }
            rotate_cloudregister_log($instance);
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

    rotate_cloudregister_log($instance);
    cleanup_instance($instance);
    # It might take a bit for the system to remove the repositories
    foreach my $i (1 .. 4) {
        last if ($instance->ssh_script_output(cmd => 'zypper -t lr | awk "/^\s?[[:digit:]]+/{c++} END {print c}"', timeout => 300) == 0);
        sleep 15;
    }
    check_instance_unregistered($instance, 'The list of zypper repositories is not empty.');

    # The SUSEConnect registration should still work on BYOS
    if (is_byos()) {
        rotate_cloudregister_log($instance);
        $instance->ssh_assert_script_run(cmd => 'sudo SUSEConnect --version');
        $instance->ssh_assert_script_run(cmd => "sudo SUSEConnect $regcode_param");
        cleanup_instance($instance);
    }

    rotate_cloudregister_log($instance);
    new_registration($instance);

    test_container_runtimes($instance) if (is_sle('>=15-SP5'));

    rotate_cloudregister_log($instance);
    force_new_registration($instance);

    rotate_cloudregister_log($instance);
    register_addons_in_pc($instance);

    set_var('PUBLIC_CLOUD_CHECK_CLOUDREGISTER_EXECUTED', '1');
}

sub check_instance_registered {
    my ($instance) = @_;
    if ($instance->ssh_script_output(cmd => 'zypper -t lr | awk "/^\s?[[:digit:]]+/{c++} END {print c}"', timeout => 300) == 0) {
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
        # bsc#1252277 - The NVIDIA repos are added by SUSEConnect but not removed
        if ($_ =~ /^\s?\d+/ && $_ !~ /SUSE_Maintenance|:NVIDIA-|ToTest/) {
            record_info('Repo leftover', "The following repository is not expected and should have been probably removed:\n$out", result => 'fail');
            die($error);
        }
    }
}

sub new_registration {
    my ($instance) = @_;
    record_info('Starting registration...');
    $instance->ssh_script_retry(cmd => "sudo registercloudguest $regcode_param", timeout => 300, retry => 3, delay => 120);
    check_instance_registered($instance);
    # https://progress.opensuse.org/issues/196370 workaround for a known issue on 15-SP5
    if (is_sle('=15-SP5')) {
        $instance->ssh_assert_script_run("sudo zypper update -y");
        $instance->softreboot(timeout => 3600);
    }
    return 0;
}

sub test_container_runtimes {
    my ($instance) = @_;
    my $image = "registry.suse.com/bci/bci-base:latest";

    record_info('Test docker');
    $instance->ssh_assert_script_run("sudo rm -f /root/.docker/config.json");    # workaround for https://bugzilla.suse.com/show_bug.cgi?id=1231185
    pc_pkg_call($instance, "in -y docker", timeout => 600, retry => 3, delay => 30);
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
            pc_pkg_call($instance, "in libcontainers-common");
            record_info('permissions #2', 'The previous registries.conf has been removed, then libcontainers-common was installed');
            $instance->ssh_script_run('sudo stat /etc/containers/registries.conf');
            cleanup_instance($instance);
            new_registration($instance);
            record_info('permissions #3', 'The libcontainers-common is present and then the image was re-registered');
            $instance->ssh_script_run('sudo stat /etc/containers/registries.conf');
        }
        $instance->ssh_script_run('sudo chmod 644 /etc/containers/registries.conf');
    }
    pc_pkg_call($instance, "in -y podman", timeout => 240, retry => 3, delay => 30);
    $instance->ssh_script_retry("podman --debug pull $image", retry => 3, delay => 60, timeout => 600);
    return 0;
}

sub cleanup_instance {
    my ($instance) = @_;
    record_info('Removing registration data');
    my $rc = $instance->ssh_script_run(cmd => "sudo registercloudguest --clean > registercloudguest-clean.log 2>&1", timeout => 180);
    if ($rc != 0) {
        # Check for bsc#1260603
        my $output = $instance->ssh_script_output("sudo cat registercloudguest-clean.log");
        record_info("register-cleanup", $output);
        if (is_sle("16+") && $output =~ "Error parsing config file") {
            record_soft_failure("bsc#1260603 registercloudguest cleanup partially failed");
            # Manually cleanup remnants and try again
            $instance->ssh_script_run(cmd => "sudo rm /etc/zypp/repos.d/*.repo");
            rotate_cloudregister_log($instance);
            $instance->ssh_assert_script_run(cmd => "sudo registercloudguest --clean");
        } else {
            die "registercloudguest --clean failed with return code $rc";
        }
    }
    check_instance_unregistered($instance);
}

sub force_new_registration {
    my ($instance) = @_;
    record_info('Forcing a new registration...');
    $instance->ssh_script_retry(cmd => "sudo registercloudguest $regcode_param --force-new", timeout => 300, retry => 3, delay => 120);
    # https://progress.opensuse.org/issues/196370 workaround for a known issue on 15-SP5
    if (is_sle('=15-SP5')) {
        $instance->ssh_assert_script_run("sudo zypper update -y");
        $instance->softreboot(timeout => 3600);
    }
    check_instance_registered($instance);
    return 0;
}

sub post_fail_hook {
    my ($self) = @_;
    if (exists($self->{my_instance})) {
        $self->{my_instance}->ssh_script_run("sudo chmod a+r /var/log/cloudregister", timeout => 0, quiet => 1);
        $self->{my_instance}->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log.txt');
        $self->{my_instance}->upload_log($archive, log_name => $autotest::current_test->{name} . '-cloudregister_archives.tar');
    }
    if (is_azure()) {
        record_info('azuremetadata', $self->{my_instance}->ssh_script_output(cmd => "sudo /usr/bin/azuremetadata --api latest --subscriptionId --billingTag --attestedData --signature --xml"));
    }
    $self->SUPER::post_fail_hook();
    registercloudguest($self->{my_instance});
}

sub test_flags {
    if (check_var('PUBLIC_CLOUD_QAM', 1)) {
        if ($run_count == 1) {
            # If we are in multi module scenario and this is the first run of the test module we wanna not fail the whole run
            return {fatal => 0};
        }
        # If we are in multi module scenario and this is not the first run of this test module we wanna fail the whole run
        return {fatal => 1};
    }
    # If we are not in multi module scenario it is always the first run and we wanna run basetest cleanup
    return {fatal => 1};
}

1;
