# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in EC2 using aws binary
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl';
use version_utils 'is_sle';
use transactional qw(process_reboot trup_call);
use registration qw(add_suseconnect_product get_addon_fullname);
use containers::common 'install_docker_when_needed';
use version_utils 'get_os_release';

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;
    install_docker_when_needed($host_distri);

    # Initialize the AWS provider
    my $provider = $self->provider_factory();

    # Prepare the role
    assert_script_run 'aws iam list-attached-role-policies --role-name ecsExternalInstanceRole';
    assert_script_run 'aws ssm create-activation --iam-role ecsExternalInstanceRole | tee ssm-activation.json';

    # Activate the amazon-ssm-agent
    my $ActivationId = script_output q(jq -r '.ActivationId' ssm-activation.json);
    my $ActivationCode = script_output q(jq -r '.ActivationCode' ssm-activation.json);
    assert_script_run "amazon-ssm-agent --register --id $ActivationId --code $ActivationCode --region \$AWS_DEFAULT_REGION";
    systemctl 'enable --now amazon-ssm-agent.service';
    systemctl 'status amazon-ssm-agent.service';

    # Configure and run amazon-ecs
    assert_script_run 'echo "ECS_CLUSTER=ecsExternalInstanceRole" >> /etc/ecs/ecs.config';
    assert_script_run 'mkdir /var/lib/ecs';
    assert_script_run 'echo "AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION" >> /var/lib/ecs/ecs.config';
    assert_script_run 'echo "ECS_EXTERNAL=true" >> /var/lib/ecs/ecs.config';
    systemctl 'enable --now amazon-ecs.service';
    systemctl 'status amazon-ecs.service';
    assert_script_run 'aws ecs list-container-instances --cluster jose-test';

    # Debug
    assert_script_run 'journalctl --no-pager -u amazon-ecs.service > /tmp/amazon-ecs.service.log';
    upload_logs '/tmp/amazon-ecs.service.log';
    assert_script_run 'docker ps --all';
    systemctl 'status amazon-ssm-agent.service';
    systemctl 'status amazon-ecs.service';
}

sub test_flags {
    return {fatal => 0, milestone => 1};
}

1;
