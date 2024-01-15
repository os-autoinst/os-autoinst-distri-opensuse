# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: azure-cli
# Summary: Network performance for Azure Accelerated NICs
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

use base "publiccloud::basetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use publiccloud::utils qw(is_container_host);

=head2 prepare_vm

Creates a VM in Azure and installs IPERF binaries on it

=cut
sub prepare_vms {
    my ($self, $provider) = @_;
    my $repo = get_required_var('IPERF_REPO');
    record_info('INFO', "Create VM\nInstalling iperf package from $repo");
    my @instances = $provider->create_instances(check_guestregister => 0, count => 2);
    foreach my $instance (@instances) {
        record_info('Instance', 'Instance ' . $instance->instance_id . ' created');
        record_info('Iperf', 'Install IPerf binaries in VM');
        $instance->run_ssh_command(cmd => "sudo zypper -n ar --no-gpgcheck $repo net_perf");
        $instance->run_ssh_command(cmd => "sudo zypper -n in -r net_perf iperf");
    }

    return \@instances;
}

=head2 get_new_ip

Gets the PrivateIP or PublicIP of the given C<instance>. This is useful when stopping and starting
a VM again, since the IPs will differ.

=cut
sub get_new_ip {
    my ($instance, $need_pub) = @_;
    my $resgroup = (split('/', $instance->instance_id))[4];
    assert_script_run("az vm list -g $resgroup -d");
    my $cmd = 'az vm list-ip-addresses --ids ' . $instance->instance_id . ' --query "[].virtualMachine.network.privateIpAddresses[]" -o tsv';
    if (!!$need_pub) {
        $cmd = 'az vm list-ip-addresses --ids ' . $instance->instance_id . ' --query "[].virtualMachine.network.publicIpAddresses[].ipAddress" -o tsv';
    }
    my $ip = script_output($cmd);
    record_info('Instance', "VM has new IP: $ip");
    return $ip;
}

=head2 enable_accelerated_net

Enable accelerated network on the given pre-created C<instance>.
It follows the instructions in https://goo.gl/Px6kou

=cut
sub enable_accelerated_net {
    my ($self, $instance) = @_;
    my $inst_id = $instance->{instance_id};
    my $name = (split('/', $inst_id))[-1];
    my $resgroup = (split('/', $inst_id))[4];
    my $subs = $instance->{provider}->{provider_client}->{subscription};
    assert_script_run("az vm deallocate --ids $inst_id", timeout => 60 * 10);
    assert_script_run("az network nic update --resource-group $resgroup --name $name-nic --accelerated-networking true", timeout => 60 * 10);
    assert_script_run("az vm start --ids $inst_id", timeout => 60 * 20);
    sleep 60 * 3;    # Sometimes, IP is not reachable after the restart and 5 minutes is enough.
    $instance->{private_ip} = get_new_ip($instance);
    $instance->public_ip(get_new_ip($instance, 1));
    die('SR-IOV flags not found') if (!$self->check_sriov($instance));
}

=head2 check_sriov

Check that SR-IOV feature is enabled on the given C<instance>.
It follows the instructions in https://goo.gl/jK3LMr.
lspci output must contain the word Mellanox when SR-IOV is enabled.
ethtool |grep vf_ must show numbers different than 0 if SR-IOV is enabled.

=cut
sub check_sriov {
    my ($self, $instance) = @_;
    record_info('sr-iov', 'Checking SRIOV feature for instance ' . $instance->instance_id);
    my $lspci_output = $instance->run_ssh_command(cmd => "sudo lspci");
    $instance->run_ssh_command(cmd => 'sudo zypper -n in ethtool') if is_container_host();
    my $ethtool_output = $instance->run_ssh_command(cmd => "sudo ethtool -S eth0 | grep vf_");
    record_info('lspci', $lspci_output);
    record_info('ethtool', $ethtool_output);
    if (($lspci_output =~ m/Mellanox/) && ($ethtool_output !~ m/^\s+vf_rx_bytes: 0$/)) {
        record_info('sr-iov', 'SR-IOV is enabled');
        return 1;
    }
    record_info('sr-iov', 'SR-IOV is disabled');
    return 0;
}

=head2 run_test

Given C<client> and C<server> instances, it starts IPerf server and runs the
test on the client side. The test runs TEST_TIME seconds.

=cut
sub run_test {
    my ($self, $client, $server) = @_;
    record_info('server', 'Start IPERF in server ' . $server->public_ip);
    $server->run_ssh_command(cmd => 'nohup iperf3 -s -D &', no_quote => 1);
    sleep 60;    # Wait 60 seconds so that the server starts up safely and the clinet can connect to it
    record_info('client', 'Start IPERF in client');
    my $ttime = get_required_var('TEST_TIME');
    my $output = $client->run_ssh_command(cmd => 'iperf3 -t ' . $ttime . ' -c ' . $server->{private_ip}, timeout => $ttime * 3);
    record_info('RESULTS', $output);
}


sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $provider = $self->provider_factory();
    my ($client, $server) = @{$self->prepare_vms($provider)};

    $self->enable_accelerated_net($client);
    $self->enable_accelerated_net($server);

    $self->run_test($client, $server);
}

1;

=head1 Discussion

Test module to run performance test on Azure with accelerated network (SRIOV). The test creates
2 VMs with the needed type to be able to enable accelerated network. Since we are using custom
image to start the VMs, Azure can't enable accelerated network at start time. Therefore, the only
way to do this is to enable it stopping the VM and starting it again.
More info here: https://goo.gl/3SGkMX

