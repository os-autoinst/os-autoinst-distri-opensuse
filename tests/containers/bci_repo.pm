# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: bci-repo test
#   SUSE Linux Enterprise Base Container Images (SLE BCI)
#   provides truly open, flexible and secure container images and application
#   development tools for immediate use by developers and integrators without
#   the lock-in imposed by alternative offerings.
#
#   This module is used to test BCI repository.
#   We use podman as container engine of reference.
#   Podman is assumed to be installed on the host
#   (e.g. run containers/host_configuration.pm before this test case).
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

my $tdata = [
    {
        patterns => [qw(Amazon_Web_Services_Instance_Init Amazon_Web_Services_Instance_Tools Amazon_Web_Services_Tools)],
        packages => [qw(cloud-init aws-cli cloud-regionsrv-client-plugin-ec2 regionServiceClientConfigEC2)]
    },
    {
        patterns => [qw(Google_Cloud_Platform_Instance_Init Google_Cloud_Platform_Instance_Tools Google_Cloud_Platform_Tools)],
        packages => [qw(google-guest-agent cloud-regionsrv-client-plugin-gce regionServiceClientConfigGCE regionServiceClientConfigGCE)]
    },
    {
        patterns => [qw(Microsoft_Azure_Instance_Init Microsoft_Azure_Instance_Tools Microsoft_Azure_Tools)],
        packages => [qw(python-azure-agent cloud-regionsrv-client-plugin-azure regionServiceClientConfigAzure azure-cli)]
    },
    {
        patterns => [qw(OpenStack_Instance_Init OpenStack_Instance_Tools OpenStack_Tools)],
        packages => [qw(cloud-init python3-heat-cfntools python3-susepubliccloudinfo)]
    },
    {
        patterns => [qw(apparmor base devel_basis documentation enhanced_base fips ofed sw_management)],
        packages => [qw(apparmor-parser kbd gcc e2fsprogs dracut-fips rdma-core zypper)]
    }
];

my @pkg_regex = ('kernel-default', 'yast', 'gnome-desktop', 'qemu-kvm');

sub container_exec {
    my $container = shift;
    my $cmd = shift;
    assert_script_run(qq[podman exec $container /bin/sh -c '$cmd'], @_);
}

sub prepare_repo {
    my $container = shift;
    my $bci_repo = get_required_var('REPO_BCI');
    container_exec($container, 'zypper ref', timeout => 180);
    container_exec($container, 'zypper lr -d');
    container_exec($container, "zypper -q -s 11 pa --orphaned | tee -a repo.org", timeout => 600);
    # remove container-suseconnect to not get packages from registered SLE host
    container_exec($container, 'zypper -n rm container-suseconnect', timeout => 180);
    # refresh services in order to remove container-suseconnect-zypp orphaned services
    container_exec($container, 'zypper refs');
    # remove SLE_BCI repo pointing to official update servers and add SUT repo
    container_exec($container, 'zypper rr SLE_BCI');
    container_exec($container, "zypper ar http://openqa.suse.de/assets/repo/$bci_repo BCI_TEST");
    container_exec($container, 'zypper ref', timeout => 180);
    container_exec($container, 'zypper lr -d');
}

my $errors = 0;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # download and start a BCI container
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    record_info('IMAGE', $image);
    script_retry("podman pull $image", timeout => 300, delay => 60, retry => 3);
    record_info('Inspect', script_output("podman inspect $image"));

    record_info('TEST', 'Test that the repo does not contain certain packages such as kernel, yast, desktop, kvm, etc...');
    my $container = "bci-repo-tester_pkgs";
    assert_script_run("podman run --name $container -dt $image");
    prepare_repo($container);
    foreach my $pkg (@pkg_regex) {
        my $result = script_run(qq[podman exec $container /bin/sh -c 'zypper se $pkg'], die_on_timeout => 1);
        if ($result == 0) {
            # Fail if pkg is present in the repo.
            record_soft_failure("poo#109822 - Package $pkg should not be present in BCI-repo!");
            $errors += 1;
        }
    }

    record_info('TEST', 'Testing patterns and packages can be installed.');
    for (my $i = 0; $i < (scalar @$tdata); $i++) {
        my $container = "bci-repo-tester$i";
        assert_script_run("podman run --name $container -dt $image");
        prepare_repo($container);
        my @patterns = @{$tdata->[$i]->{patterns}};
        record_info("Patterns", join(', ', @patterns));
        container_exec($container, 'zypper search -t pattern', timeout => 180);
        my $result = script_run(qq[podman exec $container /bin/sh -c 'zypper -n in -t pattern @patterns'], die_on_timeout => 1, timeout => 600);
        if ($result != 0) {
            record_soft_failure("poo#109822 - There was an error installing the following patterns: @patterns");
            $errors += 1;
            next;
        }
        container_exec($container, "zypper -q -s 11 pa --orphaned | grep -v sles-release| tee -a repo.test", timeout => 600);
        container_exec($container, 'sed -i "s/ \+/ /g" repo.{org,test}', timeout => 600);
        container_exec($container, "diff repo.org repo.test", timeout => 600);
        container_exec($container, "rpm -q @{$tdata->[$i]->{packages}}", timeout => 600);
    }

    die("Some tests failed.") if ($errors > 0);
}

sub test_flags {
    return {fatal => 1};
}

1;
