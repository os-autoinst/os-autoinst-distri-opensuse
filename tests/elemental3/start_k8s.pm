# Copyright 2023-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test installation and boot of Elemental OS image.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(exec_and_insert_password systemctl);
use mm_network qw(configure_hostname);
use network_utils qw(get_default_dns is_running_in_isolated_network set_resolv);
use utils qw(file_content_replace);
use Utils::Architectures qw(is_aarch64);
use Mojo::File qw(path);

=head2 kubectl_cmd

 kubectl_cmd( cmd => <value> [, timeout => <value> ] );

Checks for up to B<$timeout> seconds whether kubectl command is executed.
Returns 0 if command is successful or croaks on timeout.

=cut

sub kubectl_cmd {
    my (%args) = @_;
    $args{timeout} //= 120;
    $timeout = bmwqemu::scale_timeout($args{timeout});
    my $starttime = time;
    my $ret = undef;

    while ($ret = script_run("kubectl $args{cmd}", $timeout / 10)) {
        if (time - $starttime >= $timeout) {
            record_info('kubectl failed command: ', script_output("kubectl $args{cmd}", proceed_on_failure => 1));
            die("kubectl command timed out after $timeout seconds!");
        }
        sleep 5;
    }

    # Return the command status
    die('Check did not return a defined value!') unless defined $ret;
    return $ret;
}

=head2 wait_kubectl_cmd

 wait_kubectl_cmd( [ timeout => <value> ] );

Wait for kubectl command to be available.

=cut

sub wait_kubectl_cmd {
    my (%args) = @_;
    $args{timeout} //= 120;
    $timeout = bmwqemu::scale_timeout($args{timeout});
    my $starttime = time;
    my $ret = undef;

    while ($ret = script_run('which kubectl', $timeout / 10)) {
        die("kubectl command did not appear within $timeout seconds!") if (time - $starttime >= $timeout);
        sleep 5;
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
    my (%args) = @_;
    $args{timeout} //= 120;
    $timeout = bmwqemu::scale_timeout($args{timeout});
    my $starttime = time;
    my $ret = undef;
    my $chk_cmd = 'kubectl get pod -A 2>&1';

    die('A regex should be defined!') unless (defined $args{regex} && $args{regex} ne '');

    while (
        $ret = script_run(
            "! ($chk_cmd | grep -E -i -v -q '$args{regex}')",
            $timeout / 10
        )
      )
    {
        if (time - $starttime >= $timeout) {
            record_info('K8s failed state', script_output("$chk_cmd", proceed_on_failure => 1));
            die("K8s cluster did not start within $timeout seconds!");
        }
        sleep 10;
    }

    # Return the command status
    die('Check did not return a defined value!') unless defined $ret;
    return $ret;
}

=head2 wait_nodes_ready

 wait_nodes_ready( [ timeout => <value> ] );

Wait for up to B<$timeout> seconds until K8s nodes are ready.
Returns 0 if nodes are ready or croaks on timeout.

=cut

sub wait_nodes_ready {
    my (%args) = @_;
    $args{timeout} //= 120;
    $timeout = bmwqemu::scale_timeout($args{timeout});
    my $starttime = time;
    my $chk_cmd = 'kubectl get nodes 2>&1';
    my $out = ' NotReady ';    # Spaces are needed for the next regex to work!

    while ($out =~ m/\s+NotReady\s+/s) {
        $out = script_output("$chk_cmd", proceed_on_failure => 1);
        if (time - $starttime >= $timeout) {
            record_info('K8s nodes state', script_output("$chk_cmd", proceed_on_failure => 1));
            die("K8s nodes not ready within $timeout seconds!");
        }
        sleep 10;
    }

    return 0;
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
    $arch = 'arm' if ($args{arch} eq 'aarch64');
    $arch = 'amd64' if ($args{arch} eq 'x86_64');

    # Get some informations from the cluster
    my ($k8s_version) = script_output('kubectl version') =~ /[Ss]erver.*:\s*(.*)/;
    my $fqdn = script_output('hostnamectl hostname');
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

    # Tells the master that it can download the files
    barrier_wait('FILES_READY');

    # mutex_lock/unlock are used to avoid a sporadic crash with
    #  next 'barrier_wait' when master stopped too quickly
    mutex_lock('wait_nodes');

    # Wait for tests to be executed on master node
    barrier_wait('TEST_FRAMEWORK_DONE');
    mutex_unlock('wait_nodes');
}

sub run {
    my $arch = get_required_var('ARCH');
    my $k8s = get_required_var('K8S');

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD');

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 960 : 480;

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Set hostname and get IP address
    my $hostname = get_var('HOSTNAME', script_output('hostnamectl hostname'));
    configure_hostname($hostname) unless (get_var('PARALLEL_WITH'));

    my $ip = script_output('ip -o route get 1 2>/dev/null | cut -d" " -f7');
    die('No IP defined on the node!') unless (defined $ip && $ip ne '');

    # Split the DNS strings into arrays only if the variable is defined and not empty
    my @default_dns = split(/,/, get_default_dns);
    set_resolv(nameservers => \@default_dns) if (is_running_in_isolated_network());

    # We may have to modify some settings if a config.yaml file is present
    # NOTE: We have to invert the return code as it is inverted between Bash and Perl
    my $config_yaml = "/etc/rancher/$k8s/config.yaml";
    unless (check_var('TESTED_CMD', 'customize')) {
        # Update K8s configuration file
        file_content_replace(
            "$config_yaml", '--sed-modifier' => 'g',
            '%NODE_NAME%' => $hostname,
            '%NODE_IP%' => $ip
        );

        # Update SELinux policy if needed
        unless (script_run("grep -q '^selinux:.*true\$' $config_yaml")) {
            record_info('SELinux detected', "Updating SELinux policy for $k8s");
            assert_script_run('semodule -i /usr/share/selinux/packages/rke2.pp');
        }
    } else {
        assert_script_run("echo -e 'node-name: $hostname\nnode-external-ip: $ip' >> $config_yaml");
    }

    # Start K8s server
    # NOTE: autostart fails here because we changed some parameters in the config file
    my $k8s_svc;
    $k8s_svc = 'k3s' if ($k8s eq 'k3s');
    $k8s_svc = 'rke2-server' if ($k8s eq 'rke2');
    systemctl("stop $k8s_svc", timeout => $timeout);
    systemctl("start $k8s_svc", timeout => $timeout);

    # Wait for kubectl command to be available
    wait_kubectl_cmd(timeout => $timeout);

    # Check K8s status
    wait_k8s_state(regex => 'status.*restarts|(1/1|2/2).*running|0/1.*completed', timeout => $timeout);

    # Record K8s status (we want all, stderr as well)
    record_info('K8s status', script_output('kubectl get pod -A 2>&1'));

    # Wait until node(s) is/are in Ready state
    wait_nodes_ready(timeout => $timeout);

    # Record K8s version/nodes
    record_info('K8s version/nodes', script_output('kubectl version; kubectl get nodes'));

    # Check toolkit version
    record_info('Elemental version', script_output('elemental3ctl version'));

    # Check that test namespace has been created (only for images built from release-manifest)
    if (check_var('TESTED_CMD', 'customize')) {
        kubectl_cmd(cmd => 'get namespace openqa-ns', timeout => $timeout);
        record_info('Test Namespace creation', 'Namespace created!');
    }

    # Only in multi-nodes configuration
    prepare_test_framework(arch => $arch, k8s => $k8s) if (get_var('PARALLEL_WITH'));
}

sub post_fail_hook {
    my ($self) = @_;

    record_info(__PACKAGE__ . ':' . 'post_fail_hook');

    # Useful to debug K8s starting issues
    script_run("journalctl -xeu $_.service") foreach ('k3s', 'rke2-server');

    # Execute the common part
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
