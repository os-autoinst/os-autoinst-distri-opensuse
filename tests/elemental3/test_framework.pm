# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test K8s distribution through ECM's distros-test-framework.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;
use network_utils qw(get_default_dns is_running_in_isolated_network set_resolv);
use serial_terminal qw(select_serial_terminal);
use transactional qw(trup_call);
use Utils::Architectures qw(is_aarch64);
use Utils::Git;

sub run {
    my $arch = get_required_var('ARCH');
    my ($repo, $branch) = get_required_var('TEST_FRAMEWORK_REPO') =~ /(\S*)@(\S*)/;

    # Split the DNS strings into arrays only if the variable is defined and not empty
    my @default_dns = split(/,/, get_default_dns);
    set_resolv(nameservers => \@default_dns) if (is_running_in_isolated_network());

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 960 : 480;

    # Add git/go package(s)
    trup_call('pkg install git go kubernetes-client-provider', timeout => $timeout);
    trup_call('apply');

    # Configure ssh options
    my $ssh_dir = '/root/.ssh';
    record_info('SSH config', 'Configure password-less SSH access');
    assert_script_run("mkdir -p $ssh_dir");
    assert_script_run("curl -v -o $ssh_dir/config " . data_url('elemental3/config.ssh'));
    assert_script_run("curl -v -o /tmp/id_ssh " . data_url('elemental3/id_ssh'));
    assert_script_run("base64 -d /tmp/id_ssh > $ssh_dir/id_rsa");
    assert_script_run("chmod -R go-rwx $ssh_dir");

    # Clone test framework repository
    git_clone(
        $repo,
        branch => $branch,
        depth => 1,
        single_branch => 1
    );

    # Wait for configuration files to be generated on 1st node
    barrier_wait('FILES_READY');

    # Variables framework configuration
    my $k8s = get_required_var('K8S');
    my $distro_dir = '/root/distros-test-framework';
    my $config_dir = "$distro_dir/config";
    my $env_file = "$config_dir/.env";
    my $tfvars_file = "$config_dir/$k8s.tfvars";

    # Get files from 1st node
    script_run("scp node01:/tmp/env $env_file");
    script_run("scp node01:/tmp/tfvars $tfvars_file");

    # Log some useful informations
    record_info('env file', script_output("cat $env_file"));
    record_info('tfvars file', script_output("cat $tfvars_file"));

    # Run tests
    my $rancher_url = 'https://releases.rancher.com/server-charts/stable';
    my $rancher_args = 'bootstrapPassword=rancherpassword,replicas=1';
    my $certmanager_version = get_required_var('CERTMANAGER_VERSION');
    my $rancher_version = get_required_var('RANCHER_VERSION');
    assert_script_run("cd $distro_dir");
    foreach my $test (split(/,/, get_required_var('TESTS_TO_RUN'))) {
        # Specific options are needed for some tests
        my $opts;
        $opts = "-tags=$test -certManagerVersion $certmanager_version -chartsVersion $rancher_version -chartsRepoName rancher -chartsRepoUrl $rancher_url -chartsArgs $rancher_args" if ($test eq 'deployrancher');

        record_info("$test", "Execute '$test' test with options '$opts'");
        assert_script_run("go test -timeout=45m -v -count=1 ./entrypoint/$test/... $opts", 3600);
    }

    # Tests done, sync with the nodes
    barrier_wait('TEST_FRAMEWORK_DONE');

    # This is used to avoid a sporadic crash with previous
    #  'barrier_wait' when master stopped too quickly
    mutex_wait('wait_nodes');

    # Delete all created barrier
    barrier_destroy('BARRIER_K8S_VALIDATION');
    barrier_destroy('NETWORK_SETUP_DONE');
    barrier_destroy('NETWORK_CHECK_DONE');
    barrier_destroy('FILES_READY');
    barrier_destroy('TEST_FRAMEWORK_DONE');
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
