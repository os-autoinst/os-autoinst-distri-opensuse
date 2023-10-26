# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-netconfig-{azure, gc2, gce}
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
use version_utils 'is_sle';

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};
    my $os_version = get_var('VERSION');
    my $pers_net_rules = '/etc/udev/rules.d/75-persistent-net-generator.rules';
    my $wr_net_rules = '/usr/lib/udev/write_net_rules';

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

    # 75-persistent-net-generator.rules is required for SLES 12-SPX
    if (is_sle('<=12-sp5')) {
        $instance->ssh_assert_script_run(
            cmd => "test -s $pers_net_rules",
            fail_message => "File \"$pers_net_rules\" is required but missing."
        );

        $instance->ssh_assert_script_run(
            cmd => "test -x $wr_net_rules",
            fail_message => "Executable \"$wr_net_rules\" is required to "
              . 'persist network configuration but missing.'
        );
    }
    # 75-persistent-net-generator.rules is usually a symlink to /dev/null in SLES 15+
    if (is_sle('15+')) {
        $instance->ssh_assert_script_run(
            cmd => "test -L $pers_net_rules",
            fail_message => "File \"$pers_net_rules\" should be a symlink to "
              . "\"/dev/null\" in SLES 15+."
        );
    }

    my $grep_cloudvm_ipv4_cmd =
      'ip -4 addr show eth0 | grep -oP "^\s+inet\s(\d+\.){3}\d+" | '
      . 'sed "s/ *inet //g"';
    my $local_eth0_ip =
      $instance->ssh_script_output(cmd => $grep_cloudvm_ipv4_cmd);
    chomp($local_eth0_ip);

    my $query_meta_ipv4_cmd =
      'curl -H Metadata:true '
      . '"http://169.254.169.254/metadata/instance/network/interface/0/ipv4/'
      . 'ipAddress/0/privateIpAddress?api-version=2023-07-01&format=text"';
    my $metadata_eth0_ip =
      $instance->ssh_script_output(cmd => $query_meta_ipv4_cmd);
    assert_equals($metadata_eth0_ip, $local_eth0_ip,
        'Locally assigned IP does not equal the IP retrieved from CSP '
          . ' metadata service.');
}
1;

