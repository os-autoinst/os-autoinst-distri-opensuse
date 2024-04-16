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
    my $os_version = get_var('VERSION');
    my $pers_net_rules = '/etc/udev/rules.d/75-persistent-net-generator.rules';

    # Cloud metadata service API is reachable at local destination
    # 169.254.169.254 in case of all public cloud providers.
    my $pc_meta_api_ip = '169.254.169.254';

    my $cloud_netconfig_svc_status = $instance->ssh_script_run(
        cmd => 'systemctl status cloud-netconfig.service');
    if ($cloud_netconfig_svc_status == 0 || $cloud_netconfig_svc_status == 3)
    {
        record_info('Success', 'Status of cloud-netconfig.service is OK.');
    }
    else {
        die('cloud-netconfig.service status appears to be incorrect!');
    }

    $instance->ssh_assert_script_run(
        cmd => 'systemctl status cloud-netconfig.timer',
        fail_message => 'cloud-netconfig.timer appears not to be started.'
    );

    # 75-persistent-net-generator.rules is usually a symlink to /dev/null in SLES 12+
    $instance->ssh_assert_script_run(
        cmd => "test -L $pers_net_rules",
        fail_message => "File \"$pers_net_rules\" should be a symlink to "
          . "\"/dev/null\" in SLES 12+."
    );

    my $grep_cloudvm_ipv4_cmd =
      'ip -4 addr show eth0 | grep -oP "^\s+inet\s(\d+\.){3}\d+" | '
      . 'sed "s/ *inet //g"';
    my $local_eth0_ip =
      $instance->ssh_script_output(cmd => $grep_cloudvm_ipv4_cmd);
    chomp($local_eth0_ip);

    my $query_meta_ipv4_cmd = "";
    if (is_azure()) {
        $query_meta_ipv4_cmd =
          'curl -H Metadata:true '
          . "\"http://$pc_meta_api_ip/metadata/instance/network/interface/0/"
          . 'ipv4/ipAddress/0/privateIpAddress?api-version=2023-07-01'
          . '&format=text"';
    }
    elsif (is_ec2()) {
        $query_meta_ipv4_cmd =
          "curl \"http://$pc_meta_api_ip/latest/meta-data/local-ipv4\"";
    }
    elsif (is_gce()) {
        $query_meta_ipv4_cmd =
          'curl -H "Metadata-Flavor: Google" '
          . "\"http://$pc_meta_api_ip/computeMetadata/v1/instance/"
          . 'network-interfaces/0/ip"';
    } else {
        die("Unsupported public cloud provider.");
    }
    my $metadata_eth0_ip =
      $instance->ssh_script_output(cmd => $query_meta_ipv4_cmd);
    assert_equals($metadata_eth0_ip, $local_eth0_ip,
        'Locally assigned IP does not equal the IP retrieved from CSP '
          . ' metadata service.');
}
1;

