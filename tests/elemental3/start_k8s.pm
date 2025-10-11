# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test installation and boot of Elemental OS image.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;
use experimental qw(switch);
use serial_terminal qw(select_serial_terminal);
use utils qw(exec_and_insert_password systemctl);
use mm_network qw(configure_hostname);
use network_utils qw(get_default_dns is_running_in_isolated_network set_resolv);
use utils qw(file_content_replace);
use Utils::Architectures qw(is_aarch64);
use Mojo::File qw(path);

=head2 wait_kubectl_cmd

 wait_kubectl_cmd( [ timeout => <value> ] );

Wait for kubectl command to be available.

=cut

sub wait_kubectl_cmd {
    my %args = @_;
    $args{timeout} //= 120;
    my $starttime = time;
    my $ret = undef;

    while ($ret = script_run('which kubectl', ($args{timeout} / 10))) {
        my $timerun = time - $starttime;
        if ($timerun < $args{timeout}) {
            sleep 5;
        }
        else {
            die("kubectl command did not appear within $args{timeout} seconds!");
        }
    }

    # Return the command status
    die('Check did not return a defined value!') unless defined $ret;
    return $ret;
}

=head2 wait_k8s_state

 wait_k8s_state( regex => <value> [, timeout => <value> ] );

Checks for up to B<$timeout> seconds whether K8s cluster is running.
Returns 0 if cluster is running or croaks on timeout.

=cut

sub wait_k8s_state {
    my %args = @_;
    $args{timeout} //= 120;
    my $starttime = time;
    my $ret = undef;
    my $chk_cmd = 'kubectl get pod -A 2>&1';

    die('A regex should be defined!') if (!defined $args{regex} || $args{regex} eq '');

    while (
        $ret = script_run(
            "! ($chk_cmd | grep -E -i -v -q '$args{regex}')",
            ($args{timeout} / 10)
        )
      )
    {
        my $timerun = time - $starttime;
        if ($timerun < $args{timeout}) {
            sleep 10;
        }
        else {
            record_info('RKE2 failed state', script_output("$chk_cmd"));
            die("K8s cluster did not start within $args{timeout} seconds!");
        }
    }

    # Return the command status
    die('Check did not return a defined value!') unless defined $ret;
    return $ret;
}

=head2 prepare_test_framework

 prepare_test_framework( arch => <value>, k8s => <value> );

Prepare for K8s tests to be done with ECM's distro-test-framework.
It can be executed on different architectures and K8s distributions.

=cut

sub prepare_test_framework {
    my (%args) = @_;

    # Define architecture
    my $arch;
    given ($args{arch}) {
        when ('aarch64') {
            $arch = 'arm64';
        }
        when ('x86_64') {
            $arch = 'amd64';
        }
    }

    # Get some informations from the cluster
    my ($k8s_version) = script_output('kubectl version') =~ /[Ss]erver.*:\s*(.*)/;
    my $fqdn = script_output('hostname -f');
    my $k8s_yaml = "/etc/rancher/$args{k8s}/$args{k8s}.yaml";
    my $k8s_config = script_output("sed 's/127\.0\.0\.1/$fqdn/g' $k8s_yaml | base64 -w0");

    # Framework configuration files
    foreach my $file ('/tmp/env', '/tmp/tfvars') {
        assert_script_run(
            "curl -v -o $file "
              . data_url('elemental3/test-framework/' . path($file)->basename)
        );
        file_content_replace(
            $file, '--sed-modifier' => 'g',
            '%ARCH%' => $arch,
            '%ACCESS_KEY%' => '/root/.ssh/id_rsa',
            '%K8S%' => $args{k8s},
            '%K8S_VERSION%' => $k8s_version,
            '%K8S_CONFIG%' => $k8s_config,
            '%FQDN%' => $fqdn
        );
    }
    barrier_wait('FILES_READY');

    # Wait for tests to be executed on master node
    barrier_wait('TEST_FRAMEWORK_DONE');
}

sub run {
    my $arch = get_required_var('ARCH');
    my $hostname = get_var('HOSTNAME', 'localhost');
    my $k8s = get_var('K8S', 'rke2');

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD');

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 960 : 480;

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Set hostname and get IP address
    configure_hostname($hostname) unless (get_var('PARALLEL_WITH'));

    my $ip = script_output('ip -o route get 1 2>/dev/null | cut -d" " -f7');
    die('No IP defined on the node!') if (!defined $ip || $ip eq '');

    # Update RKE2 configuration file
    file_content_replace(
        "/etc/rancher/$k8s/config.yaml", '--sed-modifier' => 'g',
        '%NODE_NAME%' => $hostname,
        '%NODE_IP%' => $ip
    );

    # Split the DNS strings into arrays only if the variable is defined and not empty
    my @default_dns = split(",", get_default_dns);
    set_resolv(nameservers => \@default_dns) if (is_running_in_isolated_network());

    # Start rke2-server
    # TODO: use the ReleaseManifest functionality later?
    systemctl('start rke2-server', timeout => $timeout);

    # Wait for kubectl command to be available
    wait_kubectl_cmd(timeout => $timeout);

    # Check RKE2 status
    wait_k8s_state(regex => 'status.*restarts|(1/1|2/2).*running|0/1.*completed', timeout => $timeout);

    # Record RKE2 status (we want all, stderr as well)
    record_info('RKE2 status', script_output('kubectl get pod -A 2>&1'));

    # Record RKE2 version/node
    record_info('RKE2 version/node',
        script_output('kubectl version; kubectl get nodes'));

    # Check toolkit version
    record_info('Toolkit version', script_output('elemental3ctl version'));

    # Only in multi-nodes configuration
    prepare_test_framework(arch => $arch, k8s => $k8s) if (get_var('PARALLEL_WITH'));
}

sub post_fail_hook {
    my ($self) = @_;

    record_info(__PACKAGE__ . ':' . 'post_fail_hook');

    # Useful to debug RKE2 starting issues
    script_run('journalctl -xeu rke2-server.service');

    # Execute the common part
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
