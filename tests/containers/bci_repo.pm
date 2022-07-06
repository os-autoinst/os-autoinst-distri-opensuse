# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
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

sub container_exec {
    my $container = shift;
    my $cmd = shift;
    assert_script_run(qq[podman exec $container /bin/sh -c '$cmd'], @_);
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    my $bci_repo = get_required_var('REPO_BCI');

    # download and start a BCI container
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    record_info('IMAGE', $image);
    script_retry("podman pull $image", timeout => 300, delay => 60, retry => 3);
    record_info('Inspect', script_output("podman inspect $image"));

    for (my $i = 0; $i < (scalar @$tdata); $i++) {
        my $container = "bci-repo-tester$i";

        assert_script_run("podman run --name $container -dt $image");
        # query default setup
        container_exec($container, 'zypper ref', timeout => 180);
        container_exec($container, 'zypper lr -d');
        container_exec($container, 'zypper search -t pattern', timeout => 180);
        container_exec($container, "zypper -q -s 11 pa --orphaned | tee -a repo.org", timeout => 600);
        # remove container-suseconnect, in order to install the Cloud patterns
        container_exec($container, 'zypper -n rm container-suseconnect', timeout => 180);
        # refresh services in order to remove container-suseconnect-zypp orphaned services
        container_exec($container, 'zypper refs');
        # remove SLE_BCI repo pointing to official update servers and add SUT repo
        container_exec($container, 'zypper rr 1');
        container_exec($container, "zypper ar http://openqa.suse.de/assets/repo/$bci_repo BCI_TEST");
        container_exec($container, 'zypper ref', timeout => 180);
        container_exec($container, 'zypper lr -d');
        record_info("Patterns", join(', ', @{$tdata->[$i]->{patterns}}));
        container_exec($container, 'zypper search -t pattern', timeout => 180);
        container_exec($container, "zypper -n in -t pattern @{$tdata->[$i]->{patterns}}", timeout => 600);
        container_exec($container, "zypper -q -s 11 pa --orphaned | grep -v sles-release| tee -a repo.test", timeout => 600);
        container_exec($container, 'sed -i "s/ \+/ /g" repo.{org,test}', timeout => 600);
        container_exec($container, "diff repo.org repo.test", timeout => 600);
        container_exec($container, "rpm -q @{$tdata->[$i]->{packages}}", timeout => 600);
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
