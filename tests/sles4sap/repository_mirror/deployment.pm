# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Configuration steps for repository mirror
# Maintainer: QE-SAP <qe-sap@suse.de>, Jan Kohoutek <jan.kohoutek@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Init al the PC gears (ssh keys)
    my $provider = $self->provider_factory();

    my $resource_group_postfix = 'ibsmirror' . get_current_job_id();
    my $qesap_provider = lc get_required_var('PUBLIC_CLOUD_PROVIDER');

    my %variables;
    $variables{PROVIDER} = $qesap_provider; # Beware, this is uppcase
    $variables{REGION} = $provider->provider_client->region;
    $variables{DEPLOYMENT_NAME} = $resource_group_postfix;
    $variables{DEPLOYMENT_OS_VER} = get_required_var("DEPLOYMENT_OS_VER");
#    $variables{SSH_KEY_PRIV} = '/root/.ssh/id_rsa';
#    $variables{SSH_KEY_PUB} = '/root/.ssh/id_rsa.pub';

# Clone the terraform and ansible files from the gitlab
    my $work_dir = '~/deployment';
    # Get the code for the Trento deployment

    # The usage of a variable with a different name is to
    # be able to overwrite the token when manually triggering
    # the setup_jumphost test.

    record_info('TERRAFORM', "Terrafrom the public cloud host");
    assert_script_run("cd $work_dir/apache2/terraform/".lc("$qesap_provider"));
    assert_script_run("terraform init 2>&1 | tee /tmp/terraform.log");
    assert_script_run("terraform plan -var-file=configuration.tfvars -out planned_deploy.tfplan -detailed-exitcode  2>&1 | tee /tmp/terraform.log");
    assert_script_run("terraform apply planned_deploy.tfplan 2>&1 | tee /tmp/terraform.log");
    assert_script_run("ls $work_dir");
    record_info('ANSIBLE', "SCC registration");
    assert_script_run("ansible-playbook \
                        -i ../../ansible/inventory.yaml \
                        ../../ansible/registration.yaml \
                        --extra-vars \"$(terraform output --json | jq 'with_entries(.value |= .value)')\"");
    record_info('ANSIBLE', "Apache 2 install and configure");
    assert_script_run("ansible-playbook \
                        -i ../../ansible/inventory.yaml \
                        ../../ansible/httpd_ibsim_config.yaml \
                        --extra-vars \"$(terraform output --json | jq 'with_entries(.value |= .value)')\"");
    assert_script_run("ps -fax | grep httpd");
    assert_script_run("az group list -o table");
    assert_script_run("az vm list -o table");
    assert_script_run("az network \
                          vnet \
                          list \
                          --output table
                          ");


}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
 #   qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}


1;
