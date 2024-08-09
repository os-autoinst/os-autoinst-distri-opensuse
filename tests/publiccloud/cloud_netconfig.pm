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
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use Test::Assert 'assert_equals';
use testapi;
use publiccloud::utils qw(is_azure is_ec2 is_gce);

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};
    my $pers_net_rules = '/etc/udev/rules.d/75-persistent-net-generator.rules';

    # Cloud metadata service API is reachable at local destination
    # 169.254.169.254 in case of all public cloud providers.
    my $pc_meta_api_ip = '169.254.169.254';

    $instance->ssh_assert_script_run('systemctl is-enabled cloud-netconfig.service');

    $instance->ssh_assert_script_run('systemctl status cloud-netconfig.timer');

    # 75-persistent-net-generator.rules is usually a symlink to /dev/null in SLES 12+
    $instance->ssh_assert_script_run("test -L $pers_net_rules");

    my $local_eth0_ip = $instance->ssh_script_output(qq(ip -4 -o a s eth0 | grep -Po "inet \\K[\\d.]+"));
    chomp($local_eth0_ip);

    my $query_meta_ipv4_cmd = "";
    if (is_azure()) {
        $query_meta_ipv4_cmd = qq(curl -H Metadata:true "http://$pc_meta_api_ip/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2023-07-01&format=text");
    } elsif (is_ec2()) {
        my $access_token = $instance->ssh_script_output(qq(curl -X PUT http://$pc_meta_api_ip/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60"));
        record_info("DEBUG", $access_token);
        $query_meta_ipv4_cmd = qq(curl -H "X-aws-ec2-metadata-token: $access_token" "http://$pc_meta_api_ip/latest/meta-data/local-ipv4");
    } elsif (is_gce()) {
        $query_meta_ipv4_cmd = qq(curl -H "Metadata-Flavor: Google" "http://$pc_meta_api_ip/computeMetadata/v1/instance/network-interfaces/0/ip");
    } else {
        die("Unsupported public cloud provider");
    }
    my $metadata_eth0_ip = $instance->ssh_script_output($query_meta_ipv4_cmd);
    die("Failed to get IP from metadata server") unless length($metadata_eth0_ip);
    assert_equals($metadata_eth0_ip, $local_eth0_ip, 'Locally assigned IP does not equal the IP retrieved from CSP metadata service.');
}

1;

