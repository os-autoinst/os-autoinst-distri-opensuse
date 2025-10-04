# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Public Cloud - Resource Cleanup
# This module deletes resources from cloud:
# - Free up cloud resources
# - Avoid additional cost
# - Clean up the environment
# It's also implemented as a post_fail_hook to ensure resources
# are deleted even if a test module fails.

use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';


sub run {
    my ($self) = @_;

    die('CSP not supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', get_required_var('PUBLIC_CLOUD_PROVIDER'));

    select_serial_terminal;

    my $provider_cloud_name = get_required_var('PUBLIC_CLOUD_PROVIDER');
    if ($provider_cloud_name eq 'AZURE') {
        my $rg = get_required_var('RG');
        record_info('AZURE CLEANUP', "Deleting resource group: $rg");
        assert_script_run("az group delete --name $rg -y", timeout => 600);
        assert_script_run("az group wait --name $rg --deleted");
    }
    if ($provider_cloud_name eq 'EC2') {
        my $instance_id = get_required_var('INS_ID');
        my $region = get_required_var('PUBLIC_CLOUD_REGION');
        my $vpc_id = get_required_var('VPC_ID');
        # Terminate instance and wait
        script_run("aws ec2 terminate-instances --instance-ids $instance_id --region $region");
        script_run("aws ec2 wait instance-terminated --instance-ids $instance_id --region $region", timeout => 300);
        # Delete all resources
        assert_script_run("aws ec2 delete-security-group --group-id " . get_required_var('SG_ID') . " --region $region");
        assert_script_run("aws ec2 delete-subnet --subnet-id " . get_var('SUBNET') . " --region $region");
        my $igw_id = get_required_var('IGW');
        script_run("aws ec2 detach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id --region $region");
        script_run("aws ec2 delete-internet-gateway --internet-gateway-id $igw_id --region $region");
        my $rtb_ids = script_output(
            "aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id" .
              " --query 'RouteTables[?Associations[0].Main!=\`true\`].RouteTableId'" .
              " --output text --region $region");
        assert_script_run("aws ec2 delete-route-table --route-table-id $_ --region $region") for split(/\s+/, $rtb_ids);

        # Delete everything else (AWS handles dependencies automatically if we wait)
        script_run("aws ec2 delete-vpc --vpc-id $vpc_id --region $region");
    }
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
