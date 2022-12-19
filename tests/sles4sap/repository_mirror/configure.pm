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
    $variables{PROVIDER} = $qesap_provider;
    $variables{REGION} = $provider->provider_client->region;
    $variables{DEPLOYMENT_NAME} = $resource_group_postfix;
    $variables{DEPLOYMENT_OS_VER} = get_required_var("DEPLOYMENT_OS_VER");
    #    $variables{SSH_KEY_PRIV} = '/root/.ssh/id_rsa';
    #    $variables{SSH_KEY_PUB} = '/root/.ssh/id_rsa.pub';
    #    $variables{SCC_REGCODE_SLES4SAP} = get_required_var('SCC_REGCODE_SLES4SAP');
    #   qesap_prepare_env(openqa_variables => \%variables, provider => $qesap_provider);

    # Clone the terraform and ansible files from the gitlab
    my $work_dir = '~/deployment/';
    # Get the code for the Trento deployment
    my $gitlab_repo = get_var('GITLAB_REPO', 'gitlab.suse.de/jkohoutek/plan-b');

    # The usage of a variable with a different name is to
    # be able to overwrite the token when manually triggering
    # the setup_jumphost test.
    my $gitlab_token = get_var('GITLAB_TOKEN', get_required_var('SECRET_GITLAB_TOKEN'));
    my $gitlab_clone_url = 'https://git:' . $gitlab_token . '@' . $gitlab_repo;
    #     my $gitlab_clone_url = 'https://' . $gitlab_repo;

    assert_script_run("export PATH=\$PATH:~/.local/bin");
    assert_script_run("export ANSIBLE_HOST_KEY_CHECKING=False ");
    record_info('ENVIROMENT', script_output('export -p |cut -d " " -f 3'));
    record_info('ANSIBLE', script_output('ansible --version'));
    assert_script_run("mkdir $work_dir");
    assert_script_run("cd $work_dir");
    #assert_script_run("git clone $gitlab_clone_url .  2>&1 | tee " . GITLAB_CLONE_LOG);
    assert_script_run("git clone $gitlab_clone_url . 2>&1 | tee /tmp/gitlab_clone.log");
    record_info('GIT', "$gitlab_repo is successfully cloned in the $work_dir");
    assert_script_run("cat $work_dir/keyring.pub | tee -a ~/.ssh/authorized_keys");
    record_info('GAOLER', "You have 5 minutes, no more!");
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
