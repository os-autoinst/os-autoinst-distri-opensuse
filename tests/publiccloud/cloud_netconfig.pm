# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-netconfig-{azure, ec2, gce}
# Summary: This test ensures the consistency of cloud-netconfig's
# functionality. The test shall be conducted on a VM in the cloud
# infrastructure of a supported CSP.
#
# This test only contains minimal functionality that needs to be
# extended in future.
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use Test::Assert qw(assert_equals assert_not_equals);
use testapi;
use publiccloud::utils qw(is_azure is_ec2 is_gce);

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};
    my $pers_net_rules = '/etc/udev/rules.d/75-persistent-net-generator.rules';

    $instance->ssh_assert_script_run('systemctl is-enabled cloud-netconfig.service');
    $instance->ssh_assert_script_run('systemctl is-active cloud-netconfig.timer');

    # 75-persistent-net-generator.rules is usually a symlink to /dev/null in SLES 12+
    $instance->ssh_assert_script_run("test -L $pers_net_rules");

    # Get public IP address for eth0
    my $local_eth0_ip = $instance->ssh_script_output(qq(ip -4 -o a s eth0 primary | grep -Po "inet \\K[\\d.]+"));
    chomp($local_eth0_ip);
    my $metadata_eth0_ip = $provider->query_metadata($instance, ifNum => '0', addrCount => '0');
    assert_equals($metadata_eth0_ip, $local_eth0_ip, 'Locally assigned eth0 IP does not equal the IP retrieved from CSP metadata service.');

    if (is_azure) {
        # Get public IP address for eth1
        my $local_eth1_ip = $instance->ssh_script_output(qq(ip -4 -o a s eth1 primary | grep -Po "inet \\K[\\d.]+"));
        chomp($local_eth1_ip);
        my $metadata_eth1_ip = $provider->query_metadata($instance, ifNum => '1', addrCount => '0');
        assert_equals($metadata_eth1_ip, $local_eth1_ip, 'Locally assigned eth1 IP does not equal the IP retrieved from CSP metadata service.');

        # Make sure each interface has also secondary IP address
        my $local_eth0_secondary_ip = $instance->ssh_script_output(qq(ip -4 -o a s dev eth0 secondary | grep -Po "inet \\K[\\d.]+"));
        chomp($local_eth0_secondary_ip);
        my $local_eth1_secondary_ip = $instance->ssh_script_output(qq(ip -4 -o a s dev eth1 secondary | grep -Po "inet \\K[\\d.]+"));
        chomp($local_eth1_secondary_ip);

        # Check that there is default route for each interface
        die('No default route set for eth0') if ($instance->ssh_script_output('ip route show default dev eth0 | wc -l') == 0);
        die('No default route set for eth1') if ($instance->ssh_script_output('ip route show default dev eth1 | wc -l') == 0);

        # Make HTTPS connection from each interface and check they have different public IP address
        my $eth0_public_ip = $instance->ssh_script_output('curl -sLf --interface eth0 -s https://wtfismyip.com/text');
        my $eth1_public_ip = $instance->ssh_script_output('curl -sLf --interface eth1 -s https://wtfismyip.com/text');
        assert_not_equals($eth0_public_ip, $eth1_public_ip, "The connection from eth0 shouldn't have the same public IPv4 address as connection from eth1");

        # Make sure there are IP rules for each IP address
        die('No IP rules for eth0 on primary IP') if ($instance->ssh_script_output("ip rule list all from $local_eth0_ip | wc -l") == 0);
        die('No IP rules for eth0 on secondary IP') if ($instance->ssh_script_output("ip rule list all from $local_eth0_secondary_ip | wc -l") == 0);
        die('No IP rules for eth1 on primary IP') if ($instance->ssh_script_output("ip rule list all from $local_eth1_ip | wc -l") == 0);
        die('No IP rules for eth1 on secondary IP') if ($instance->ssh_script_output("ip rule list all from $local_eth1_secondary_ip | wc -l") == 0);

        # Make sure there is at least one ARP neighbor on each interface
        die('There are no ARP neighbors on eth0') if ($instance->ssh_script_output("ip neighbor show dev eth0 | wc -l") == 0);
        die('There are no ARP neighbors on eth1') if ($instance->ssh_script_output("ip neighbor show dev eth1 | wc -l") == 0);

        # Remove eth0 secondary address and eth1 default route and check if it reappears
        $instance->ssh_assert_script_run("sudo ip addr del $local_eth0_secondary_ip/24 dev eth0");
        $instance->ssh_assert_script_run("sudo ip route del default dev eth1");
        record_info('debug', $instance->ssh_script_output('ip addr show; ip route show'));

        # Force-run cloud-netconfig service
        $instance->ssh_assert_script_run('sudo systemctl start cloud-netconfig.service');

        $instance->ssh_assert_script_run("ip addr show dev eth0 secondary");
        die('There is no secondary address on eth0') if ($instance->ssh_script_output(qq(ip -4 -o a s dev eth0 secondary | grep -Po "inet \\K[\\d.]+" | wc -l)) == 0);
        die('There is no default route on eth1') if ($instance->ssh_script_output("ip route show default dev eth1 | wc -l") == 0);

        # Remove eth0 secondary address and eth1 default route and check if it reappears
        my $resource_group = $provider->get_terraform_output('.resource_group_name.value[0]');
        my $nic_name = script_output(qq(az network nic list --resource-group $resource_group | jq -r '.[]|select(.primary==false).name'));
        my $jq_query = qq('.[]|select(.primary==false).ipConfigurations[]|select(.privateIPAddress=="$local_eth1_secondary_ip").name');
        my $ipConfig_name = script_output("az network nic list --resource-group $resource_group | jq -r $jq_query");
        assert_script_run("az network nic ip-config delete -g $resource_group -n $ipConfig_name --nic-name $nic_name");

        # Force-run cloud-netconfig service
        $instance->ssh_assert_script_run('sudo systemctl start cloud-netconfig.service');

        die('Secondary IP address in eth1 still present after removed via provider') if ($instance->ssh_script_run(qq(ip -4 -o a s dev eth1 secondary | grep -Po "inet \\K[\\d.]+" | wc -l)) != 0);
    }
}

sub post_fail_hook {
    my ($self) = @_;

    debug($self->{run_args}->{my_instance}, $self->{run_args}->{my_provider});
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my ($self) = @_;

    debug($self->{run_args}->{my_instance}, $self->{run_args}->{my_provider});
    $self->SUPER::post_run_hook;
}

sub debug {
    my ($instance, $provider) = @_;
    record_info('DEBUG');

    $instance->ssh_script_run("ip a s");
    $instance->ssh_script_run("ip -6 a s");

    $instance->ssh_script_run("ip route list table all");
    $instance->ssh_script_run("ip -6 route list table all");

    $instance->ssh_script_run("ip rule list all");
    $instance->ssh_script_run("ip -6 rule list all");

    $instance->ssh_script_run("ip neighbor show");
    $instance->ssh_script_run("ip -6 neighbor show");

    if (is_azure) {
        my $resource_group = $provider->get_terraform_output('.resource_group_name.value[0]');
        script_run("az network nic list --resource-group $resource_group");
    }
}

sub test_flags {
    return {publiccloud_multi_module => 1};
}

1;

