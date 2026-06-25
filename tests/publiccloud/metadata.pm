# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: python3-ec2metadata python3-azuremetadata python3-gcemetadata
# Summary: Test the cloud provider metadata CLI tools:
#   ec2metadata on AWS, azuremetadata on Azure, gcemetadata on GCE
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::utils qw(is_azure is_ec2 is_gce);
use publiccloud::zypper qw(pc_zypper_call);

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};

    if (is_ec2) {
        pc_zypper_call($instance, 'in python3-ec2metadata') unless $instance->ssh_script_run('rpm -q python3-ec2metadata') == 0;
        # Dump all available fields
        record_info('ec2metadata', $instance->ssh_script_output('ec2metadata'));
        # Instance identity document (signed JSON with instanceId, region, accountId, etc.)
        record_info('ec2metadata document', $instance->ssh_script_output('ec2metadata --api latest --document'));
        # Individual fields available on all instance types
        record_info('ec2metadata fields', $instance->ssh_script_output('ec2metadata --api latest --ami-id --instance-type --local-ipv4 --hostname'));
    }
    elsif (is_azure) {
        pc_zypper_call($instance, 'in python3-azuremetadata') unless $instance->ssh_script_run('rpm -q python3-azuremetadata') == 0;
        # Dump all available fields as plain text
        record_info('azuremetadata', $instance->ssh_script_output('/usr/bin/azuremetadata'));
        # JSON output format
        record_info('azuremetadata json', $instance->ssh_script_output('/usr/bin/azuremetadata --json'));
        # List available API versions
        record_info('azuremetadata listapis', $instance->ssh_script_output('/usr/bin/azuremetadata --listapis'));
        # Selected fields in XML format; --billingTag reads the disk tag from a block device, which requires root
        record_info('azuremetadata detail', $instance->ssh_script_output('sudo /usr/bin/azuremetadata --api latest --subscriptionId --billingTag --attestedData --signature --xml'));
    }
    elsif (is_gce) {
        pc_zypper_call($instance, 'in python3-gcemetadata') unless $instance->ssh_script_run('rpm -q python3-gcemetadata') == 0;
        # Dump all instance metadata
        record_info('gcemetadata instance', $instance->ssh_script_output('gcemetadata --query instance'));
        # XML output format
        record_info('gcemetadata instance xml', $instance->ssh_script_output('gcemetadata --query instance --xml'));
        # Disk sub-device query
        record_info('gcemetadata disks', $instance->ssh_script_output('gcemetadata --query instance --disks --diskid 0'));
        # Network interface sub-device query
        record_info('gcemetadata network', $instance->ssh_script_output('gcemetadata --query instance --network-interfaces --netid 0'));
        # Dump all project metadata
        record_info('gcemetadata project', $instance->ssh_script_output('gcemetadata --query project'));
    }
}

sub test_flags {
    return {};
}

1;
