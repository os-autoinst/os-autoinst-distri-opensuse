# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in EC2 using aws binary
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();

    # If 'aws' is preinstalled, we test that version
    if (script_run("which aws") != 0) {
        add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef));
        add_suseconnect_product(get_addon_fullname('phub')) if is_sle('=12-sp5');
        zypper_call 'in aws-cli jq';
    }

    set_var 'PUBLIC_CLOUD_PROVIDER' => 'EC2';
    my $provider = $self->provider_factory();

    my $image_id = script_output("aws ec2 describe-images --filters 'Name=name,Values=suse-sles-15-sp3-v*-x86_64' 'Name=state,Values=available'  --output=json | jq -r '.Images[] | select( (.Name | contains(\"-ecs\") | not)).ImageId' | head -n1", 240);
    record_info("EC2 AMI", "EC2 AMI query: " . $image_id);

    my $ssh_key = "openqa-cli-test-key-$job_id";
    assert_script_run("aws ec2 import-key-pair --key-name '$ssh_key' --public-key-material fileb://~/.ssh/id_rsa.pub");

    my $machine_name = "openqa-cli-test-vm-$job_id";
    my $security_group_name = "openqa-cli-test-sg-$job_id";
    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $openqa_url = get_required_var('OPENQA_URL');
    my $created_by = "$openqa_url/t$job_id";
    my $tag = "{Key=openqa-cli-test-tag,Value=$job_id},{Key=openqa_created_by,Value=$created_by},{Key=openqa_ttl,Value=$openqa_ttl}";

    my $create_security_group = "aws ec2 create-security-group --group-name $security_group_name --description 'aws_cli openqa test security group'";
    $create_security_group .= " --tag-specifications 'ResourceType=security-group,Tags=[$tag]'";
    assert_script_run($create_security_group, 180);
    my $security_group_id = script_output("aws ec2 describe-security-groups --filters Name=group-name,Values=$security_group_name --query 'SecurityGroups[*].GroupId' --output=text", 180);
    my $worker_public_ip = script_output('curl -q http://checkip.amazonaws.com');
    assert_script_run("aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 22 --cidr $worker_public_ip/32");

    my $run_instances = "aws ec2 run-instances --image-id $image_id --count 1 --security-group-ids $security_group_id --instance-type t2.micro --key-name $ssh_key";
    $run_instances .= " --tag-specifications 'ResourceType=instance,Tags=[$tag]' 'ResourceType=volume,Tags=[$tag]'";
    assert_script_run($run_instances, 240);
    assert_script_run("aws ec2 describe-instances --filters 'Name=tag:openqa-cli-test-tag,Values=$job_id'", 90);
    my $instance_id = script_output("aws ec2 describe-instances --filters 'Name=tag:openqa-cli-test-tag,Values=$job_id' --output=text --query 'Reservations[*].Instances[*].InstanceId'", 90);

    # Wait until the instance is really running
    script_retry("aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[*].Instances[*].State.Name' --output text | grep 'running'", 90, delay => 15, retry => 12);

    # Check that the machine is reachable via ssh
    my $ip_address = script_output("aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[*].Instances[*].PublicIpAddress' --output text", 90);
    script_retry("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user\@$ip_address hostnamectl", 90, delay => 15, retry => 12);
}

sub cleanup {
    my $job_id = get_current_job_id();
    my $instance_id = script_output("aws ec2 describe-instances --filters 'Name=tag:openqa-cli-test-tag,Values=$job_id' --output=text --query 'Reservations[*].Instances[*].InstanceId'", 90);
    my $security_group_name = "openqa-cli-test-sg-$job_id";
    record_info("InstanceId", "InstanceId: " . $instance_id);
    assert_script_run("aws ec2 terminate-instances --instance-ids $instance_id", 240);
    my $ssh_key = "openqa-cli-test-key-$job_id";
    assert_script_run "aws ec2 delete-key-pair --key-name $ssh_key";
    # The security group can be deleted only after the instance is terminated which takes a moment
    script_retry "aws ec2 delete-security-group --group-name $security_group_name", delay => 15, retry => 12;
}

sub test_flags {
    return {fatal => 0, milestone => 0, always_rollback => 1};
}

1;

