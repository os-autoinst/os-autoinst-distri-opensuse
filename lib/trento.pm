# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for Trento tests
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

Trento test lib

=head1 COPYRIGHT

Copyright 2022 SUSE LLC
SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE SAP <qe-sap@suse.de>

=cut

package trento;

use strict;
use warnings;
use mmapi 'get_current_job_id';
use File::Basename qw(basename);
use Mojo::JSON qw(decode_json);
use YAML::PP;
use utils qw(script_retry);
use testapi;
use qesapdeployment;

use Exporter 'import';

our @EXPORT = qw(
  clone_trento_deployment
  get_trento_deployment
  get_resource_group
  get_qesap_resource_group
  config_cluster
  get_vm_name
  get_acr_name
  get_trento_ip
  get_vnet
  get_trento_password
  deploy_vm
  deploy_qesap
  destroy_qesap
  install_agent
  get_agents_number
  VM_USER
  SSH_KEY
  cypress_configs
  cypress_install_container
  CYPRESS_LOG_DIR
  PODMAN_PULL_LOG
  cypress_version
  cypress_exec
  cypress_test_exec
  cypress_log_upload
  k8s_logs
);

# Exported constants
use constant VM_USER => 'cloudadmin';
use constant SSH_KEY => '/root/.ssh/id_rsa';
use constant CYPRESS_LOG_DIR => '/root/result';
use constant PODMAN_PULL_LOG => '/tmp/podman_pull.log';

# Lib internal constants
use constant TRENTO_AZ_PREFIX => 'openqa-trento';
use constant TRENTO_QESAPDEPLOY_PREFIX => 'qesapdep';
use constant TRENTO_SCRIPT_RUN => 'set -o pipefail ; ./';
use constant GITLAB_CLONE_LOG => '/tmp/gitlab_clone.log';

# Parameter 'registry_name' must conform to
# the following pattern: '^[a-zA-Z0-9]*$'.
# Azure does not support dash or underscore in ACR name
use constant TRENTO_AZ_ACR_PREFIX => 'openqatrentoacr';
use constant CYPRESS_IMAGE_TAG => 'goofy';
use constant CYPRESS_IMAGE => 'docker.io/cypress/included';

=head1 DESCRIPTION

Package with common methods and default or
constant values for Trento tests

=head2 Methods
=cut

=hean3 clone_trento_deployment

Clone gitlab.suse.de/qa-css/trento
=cut

sub clone_trento_deployment {
    my ($self, $work_dir) = @_;
    # Get the code for the Trento deployment
    my $gitlab_repo = get_var(TRENTO_GITLAB_REPO => 'gitlab.suse.de/qa-css/trento');

    # The usage of a variable with a different name is to
    # be able to overwrite the token when manually triggering
    # the setup_jumphost test.
    my $gitlab_token = get_var(TRENTO_GITLAB_TOKEN => get_required_var('_SECRET_TRENTO_GITLAB_TOKEN'));

    my $gitlab_clone_url = 'https://git:' . $gitlab_token . '@' . $gitlab_repo;

    record_info('CLONE', "Clone $gitlab_repo in $work_dir");
    assert_script_run("cd $work_dir");
    assert_script_run("git clone $gitlab_clone_url .  2>&1 | tee " . GITLAB_CLONE_LOG);
}

=head3 get_trento_deployment

Get the set of scripts for the Trento deployment
=cut

sub get_trento_deployment {
    my ($self, $work_dir) = @_;

    enter_cmd "cd $work_dir";
    script_run 'read -s GITLAB_TOKEN', 0;
    type_password get_var(TRENTO_GITLAB_TOKEN => get_required_var('_SECRET_TRENTO_GITLAB_TOKEN')) . "\n";

    # Script from a release
    if (get_var('TRENTO_DEPLOY_VER')) {

        # Clean up whatever is present in the indicated working folder
        # of the qcow2 image, to avoid confusion
        enter_cmd 'rm -rf *';

        # Get some 'coordinates' from the test settings
        my $ver = get_var('TRENTO_DEPLOY_VER');
        my $gitlab_repo = get_var(TRENTO_GITLAB_REPO => 'gitlab.suse.de/qa-css/trento');
        my @gitlab_url = split('/', $gitlab_repo);
        my $gitlab_namespace = $gitlab_url[-2];
        my $gitlab_project = $gitlab_url[-1];

        assert_script_run('echo "PRIVATE-TOKEN: ${GITLAB_TOKEN}" > gitlab_conf');
        my $curl_cmd = 'curl -s -H @gitlab_conf';
        my $gitlab_api = 'https://gitlab.suse.de/api/v4/projects';

        # Get the ID of the requested project
        my $repo_id_cmd = $curl_cmd .
          " \"$gitlab_api/$gitlab_namespace%2F$gitlab_project\"";
        my $repo_output = decode_json(script_output($repo_id_cmd));
        my $repo_id = $repo_output->{id};

        my $repo_url = "$gitlab_api/$repo_id";
        my $rel_api_url = "$repo_url/releases/v$ver";

        # Get the file name of the release archive
        my $ver_artifact_cmd = "basename \$($curl_cmd $rel_api_url " .
          "| jq -r '.assets.sources[]|select(.format == \"tar.gz\")" .
          "|.url')";
        my $ver_artifact = script_output($ver_artifact_cmd);

        # Get the commit ID of the release
        my $commit_id_cmd = "$curl_cmd $rel_api_url " .
          "| jq -r .commit.id";
        my $commit_id = script_output($commit_id_cmd);

        # Download the release archive
        my $download_api_url = "$repo_url/repository/archive.tar.gz?sha=$commit_id";
        my $download_cmd = $curl_cmd .
          " \"$download_api_url\"" .
          " --output $ver_artifact ";
        assert_script_run($download_cmd);

        # Extract and test file presence
        my $tar_cmd = "tar xvf $ver_artifact --strip-components=1";
        assert_script_run($tar_cmd);
        enter_cmd 'ls -lai';
    }

    # Script from Gitlab
    else {
        my $git_branch = get_var(TRENTO_GITLAB_BRANCH => 'master');

        if (script_run('git rev-parse --is-inside-work-tree') != 0) {
            $self->clone_trento_deployment($work_dir);
        }
        else {
            # Test that the token in worker.ini and the one in the qcow2 match
            my $qcow_token_cmd = 'git config --get remote.origin.url' .
              '|cut -d@ -f1|cut -d: -f3';
            assert_script_run "QCOW_TOKEN=\"\$($qcow_token_cmd)\"";
            my $different_tokens = script_run '[[ "$GITLAB_TOKEN" == "$QCOW_TOKEN" ]]';
            die "Invalid gitlab token" if ($different_tokens);
        }
        # Switch branch and get latest
        assert_script_run("git checkout $git_branch");
        assert_script_run("git pull origin $git_branch");
    }
}

=head3 get_resource_group

Return a string to be used as cloud resource group.
It contains the JobId
=cut

sub get_resource_group {
    return TRENTO_AZ_PREFIX . '-rg-' . get_current_job_id();
}

=head3 get_qesap_resource_group

Query and return the resource group used
by the qe-sap-deployment
=cut

sub get_qesap_resource_group {
    my $job_id = get_current_job_id();
    my $result = script_output("az group list --query \"[].name\" -o tsv | grep $job_id | grep " . TRENTO_QESAPDEPLOY_PREFIX);
    record_info('QESAP RG', "result:$result");
    return $result;
}

=head3 config_cluster

=cut

sub config_cluster {
    my ($self, $region) = @_;

    my $resource_group_postfix = $self->TRENTO_QESAPDEPLOY_PREFIX . get_current_job_id();
    my $ssh_key_pub = SSH_KEY . '.pub';
    my $qesap_provider = lc get_required_var('PUBLIC_CLOUD_PROVIDER');

    # Get the code for the qe-sap-deployment
    qesap_create_folder_tree();
    qesap_get_deployment_code();
    qesap_pip_install();

    my %variables;
    $variables{PROVIDER} = $qesap_provider;
    $variables{REGION} = $region;
    $variables{DEPLOYMENTNAME} = $resource_group_postfix;
    $variables{TRENTO_CLUSTER_OS_VER} = get_required_var("TRENTO_CLUSTER_OS_VER");
    $variables{SSH_KEY_PRIV} = SSH_KEY;
    $variables{SSH_KEY_PUB} = $ssh_key_pub;
    $variables{SCC_REGCODE_SLES4SAP} = get_required_var('SCC_REGCODE_SLES4SAP');
    $variables{HANA_SAR} = get_required_var("QESAPDEPLOY_SAPCAR");
    $variables{HANA_CLIENT_SAR} = get_required_var("QESAPDEPLOY_IMDB_SERVER");
    $variables{HANA_SAPCAR} = get_required_var("QESAPDEPLOY_IMDB_CLIENT");
    qesap_prepare_env(openqa_variables => \%variables, provider => $qesap_provider);
}

=head3 deploy_vm

Deploy the main VM for the Trento application
Based on 00.040-trento_vm_server_deploy_azure.sh
=cut

sub deploy_vm {
    # Run the Trento deployment

    my $script_id = '00.040';
    my $resource_group = get_resource_group();
    my $machine_name = get_vm_name();
    record_info($script_id);
    my $vm_image = get_var(TRENTO_VM_IMAGE => 'SUSE:sles-sap-15-sp3-byos:gen2:latest');
    my $deploy_script_log = "script_$script_id.log.txt";
    my $cmd = join(' ', TRENTO_SCRIPT_RUN . $script_id . '-trento_vm_server_deploy_azure.sh ',
        '-g', $resource_group,
        '-s', $machine_name,
        '-i', $vm_image,
        '-a', VM_USER,
        '-k', SSH_KEY . '.pub',
        '-v', "2>&1|tee $deploy_script_log");
    assert_script_run($cmd, 360);
    upload_logs($deploy_script_log);
}

=head3 deploy_qesap

Deploy a SAP Landscape using a previously configured qe-sap-deployment
=cut

sub deploy_qesap {
    qesap_execute(cmd => 'terraform', verbose => 1, timeout => 1800);
    qesap_execute(cmd => 'ansible', verbose => 1, timeout => 1800);
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    enter_cmd "cat $inventory";
    upload_logs($inventory);
}

=head3 destroy_qesap

Destroy the qe-sap-deployment SAP Landscape
=cut

sub destroy_qesap {
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 900);
}

=head3 get_vm_name

Return a string to be used as cloud VM name.
It contains the JobId
=cut

sub get_vm_name {
    my $job_id = get_current_job_id();
    return TRENTO_AZ_PREFIX . "-vm-$job_id";
}

=head3 get_acr_name

Return a string to be used as cloud ACR name.
It contains the JobId
=cut

sub get_acr_name {
    return TRENTO_AZ_ACR_PREFIX . get_current_job_id();
}

=head3 get_trento_ip

Return the running VM public IP
=cut

sub get_trento_ip {
    my $machine_ip = get_var('TRENTO_EXT_DEPLOY_IP');
    return $machine_ip if ($machine_ip);
    my $az_cmd = sprintf 'az vm show -d -g %s -n %s --query "publicIps" -o tsv',
      get_resource_group(),
      get_vm_name();
    return script_output($az_cmd, 180);
}

=head3 get_vnet

Return the output of az network vnet list
=cut

sub get_vnet {
    my ($resource_group) = @_;
    my $az_cmd = join(' ', 'az', 'network',
        'vnet', 'list',
        '-g', $resource_group,
        '--query', '"[0].name"',
        '-o', 'tsv');
    return script_output($az_cmd, 180);
}

=head3 get_trento_password

Return the password for the Trento WebUI
=cut

sub get_trento_password {
    my $self = shift;
    my $trento_web_password;

    if (get_var('TRENTO_EXT_DEPLOY_IP')) {
        $trento_web_password = get_required_var('TRENTO_WEB_PASSWORD');
    }
    else {
        my $machine_ip = get_trento_ip;
        record_info("TRENTO IP", $machine_ip);
        my $trento_web_password_cmd = az_vm_ssh_cmd(
            'kubectl get secret trento-server-web-secret' .
              " -o jsonpath='{.data.ADMIN_PASSWORD}'" .
              '|base64 --decode', $machine_ip);
        $trento_web_password = script_output($trento_web_password_cmd);
    }
    return $trento_web_password;
}

=head3 az_delete_group

Delete the resource group associated to this JobID and all its content
=cut

sub az_delete_group {
    script_run('echo "Delete all resources"');
    my $az_cmd = sprintf 'az group delete --resource-group %s --yes', get_resource_group();
    script_retry($az_cmd, timeout => 600, retry => 5, delay => 60);
}

=head3 az_vm_ssh_cmd

Compose I<ssh> command for remote execution on the VM machine.
The function optionally accept the VM public IP.
If not provided, the IP is calculated on the fly with an I<az> query,
take care that is a time consuming I<az> query.

=over 2

=item B<CMD_ARG> - String of the command to be executed remotely

=item B<VM_IP_ARG> - Public IP of the remote machine where to execute the command

=back
=cut

sub az_vm_ssh_cmd {
    my ($cmd_arg, $vm_ip_arg) = @_;
    record_info('REMOTE', "cmd:$cmd_arg");

    # Undef comparison operator
    $vm_ip_arg //= get_trento_ip();
    return 'ssh' .
      ' -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR' .
      ' -i ' . SSH_KEY . ' ' .
      VM_USER . '@' . $vm_ip_arg .
      ' -- ' . $cmd_arg;
}

=head3 install_agent

Install trento-agent on all the nodes.
Installation is performed using ansible.

=over 4

=item B<WORK_DIRECTORY> - Working directory, used to eventually download .rpm

=item B<PLAYBOOK> - Playbook location

=item B<API_KEY> - Api key needed to configure trento-agent

=item B<PRIVATE_IP> - Trento server private IP, used to configure server-url in agent

=back
=cut

sub install_agent {
    my ($self, $wd, $playbook_location, $agent_api_key, $priv_ip) = @_;
    my $local_rpm_arg = '';
    my $cmd;
    if (get_var('TRENTO_AGENT_RPM')) {
        my $package = get_var('TRENTO_AGENT_RPM');
        my $ibs_location = get_var(TRENTO_AGENT_REPO => 'https://dist.suse.de/ibs/Devel:/SAP:/trento:/factory/SLE_15_SP3/x86_64');
        $cmd = "curl \"$ibs_location/$package\" --output $wd/$package";
        assert_script_run($cmd);
        $local_rpm_arg = " -e agent_rpm=$wd/$package";
    }

    $cmd = join(' ', 'ansible-playbook', '-vv',
        '-i', qesap_get_inventory(lc get_required_var('PUBLIC_CLOUD_PROVIDER')),
        "$playbook_location/trento-agent.yaml",
        $local_rpm_arg,
        '-e', "api_key=$agent_api_key",
        '-e', "trento_private_addr=$priv_ip");
    assert_script_run($cmd);
}

=head3 get_agents_number

Get the number of SAP cluster nodes where the trento-agent has been installed
=cut

sub get_agents_number {
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $yp = YAML::PP->new();

    my $inventory_content = script_output("cat $inventory");
    my $parsed_inventory = $yp->load_string($inventory_content);
    my $num_hosts = 0;
    while ((my $key, my $value) = each(%{$parsed_inventory->{all}->{children}})) {
        $num_hosts += keys %{$value->{hosts}};
    }
    return $num_hosts;
}

=head3 k8s_logs

Get all relevant info out from the cluster

=over 2

=item B<CMD_ARG> - String of the command to be executed remotely

=item B<VM_IP_ARG> - Public IP of the remote machine where to execute the command

=back
=cut

sub k8s_logs {
    my (@pods_list) = @_;
    my $machine_ip = get_trento_ip();

    return unless ($machine_ip);

    my $kubectl_pods = script_output(az_vm_ssh_cmd('kubectl get pods', $machine_ip), 180);

    # For each pod that I'm interested to inspect
    for my $s (@pods_list) {
        # For each running pod from 'kubectl get pods'
        foreach my $row (split(/\n/, $kubectl_pods)) {
            # Name of the file where we will eventually dump the log
            my $describe_txt = "pod_describe_$s.txt";
            my $log_txt = "pod_log_$s.txt";
            # If the running pod is one of the ones I'm interested in...
            if ($row =~ m/trento-server-$s/) {
                # ...extract this pod name
                my $pod_name = (split /\s/, $row)[0];

                # ...get the description
                my $kubectl_describe_cmd = az_vm_ssh_cmd("kubectl describe pods/$pod_name > $describe_txt", $machine_ip);
                script_run($kubectl_describe_cmd, 180);
                upload_logs($describe_txt);

                # ...get the log
                my $kubectl_logs_cmd = az_vm_ssh_cmd("kubectl logs $pod_name > $log_txt", $machine_ip);
                script_run($kubectl_logs_cmd, 180);
                upload_logs($log_txt);
            }
        }
    }
}

=head3 podman_self_check

Perform some generic checks related to the podman installation itself
and the relevant parameters of the current machine environment.
=cut

sub podman_self_check {
    record_info('PODMAN', 'Check podman');
    assert_script_run('which podman');
    assert_script_run('podman --version');
    assert_script_run('podman info --debug');
    assert_script_run('podman ps');
    assert_script_run('podman images');
    assert_script_run('df -h');
}

=head3 cypress_configs

Prepare all the configuration files for cypress

=over 1

=item B<CYPRESS_TEST_DIR> - Cypress test code location.

=back
=cut

sub cypress_configs {
    my ($cypress_test_dir) = @_;

    my $machine_ip = get_trento_ip();
    enter_cmd "cd " . $cypress_test_dir;
    my $cypress_env_cmd = sprintf './cypress.env.py' .
      ' -u http://%s' .
      ' -p %s' .
      ' -f Premium' .
      ' -n %s' .
      ' --trento-version %s',
      $machine_ip, get_trento_password(), get_agents_number(), get_required_var('TRENTO_VERSION');

    assert_script_run($cypress_env_cmd);
    assert_script_run('cat cypress.env.json');
    upload_logs('cypress.env.json');
}

=head3 cypress_install_container

Prepare whatever is needed to run cypress tests using container

=over 1

=item B<CYPRESS_VER> - String used as tag for the cypress/included image.

=back
=cut

sub cypress_install_container {
    my ($self, $cypress_ver) = @_;
    podman_self_check();

    # List all the available cypress images
    assert_script_run('podman search --list-tags ' . CYPRESS_IMAGE);

    # Pull in advance the cypress container
    my $podman_pull_cmd = 'time podman ' .
      '--log-level trace ' .
      'pull ' .
      '--quiet ' .
      CYPRESS_IMAGE . ':' . $cypress_ver .
      ' | tee ' . PODMAN_PULL_LOG;
    assert_script_run($podman_pull_cmd, 1800);
    assert_script_run('df -h');
    assert_script_run('podman images');
}

=head3 cypress_log_upload

Upload to openQA the relevant logs

=over 1

=item B<LOG_FILTER> - List of strings. List of file extensions (dot needed) 

=back
=cut

sub cypress_log_upload {
    my ($self, @log_filter) = @_;
    my $find_cmd = 'find ' . CYPRESS_LOG_DIR . ' -type f \( -iname \*' . join(' -o -iname \*', @log_filter) . ' \)';

    upload_logs("$_") for split(/\n/, script_output($find_cmd));
}

=head3 cypress_exec

Return the cypress.io version to use.
It could be the default one or one fixed by the user using TRENTO_CYPRESS_VERSION

=cut

sub cypress_version {
    my $self = shift;
    return get_var(TRENTO_CYPRESS_VERSION => '9.6.1');
}

=head3 cypress_exec

Execute a cypress command within the container 

=over 5

=item B<CYPRESS_TEST_DIR> - String of the path where the cypress Trento code is available.
It is the I<test> folder within the path used by L<setup_jumphost>

=item B<CMD> - String of cmd to be used as main argument for the cypress
executable call. 

=item B<TIMEOUT> - Integer used as timeout for the cypress command execution

=item B<LOG_PREFIX> - String of the command to be executed remotely

=item B<FAILOK> - Integer boolean value. 0:test marked as failure if the podman/cypress
return not 0 exit code. 1:all not 0 podman/cypress exit code are ignored. SoftFail reported.

=back
=cut

sub cypress_exec {
    my ($self, $cypress_test_dir, $cmd, $timeout, $log_prefix, $failok) = @_;
    my $ret = 0;

    record_info('CY EXEC', 'Cypress exec:' . $cmd);
    my $image_name = CYPRESS_IMAGE . ":" . $self->cypress_version;

    # Container is executed with --name to simplify the log retrieve.
    # To do so, we need to rm present container with the same name
    assert_script_run('podman images');
    script_run('podman rm ' . CYPRESS_IMAGE_TAG . ' || echo "No ' . CYPRESS_IMAGE_TAG . ' to delete"');
    my $cypress_run_cmd = 'podman run ' .
      '-it --name ' . CYPRESS_IMAGE_TAG . ' ' .
      '-v ' . CYPRESS_LOG_DIR . ':/results ' .
      "-v $cypress_test_dir:/e2e -w /e2e " .
      '-e "DEBUG=cypress:*" ' .
      '--entrypoint=\'[' .
      '"/bin/sh", "-c", ' .
      '"/usr/local/bin/cypress ' . $cmd .
      ' 2>/results/cypress_' . $log_prefix . '_log.txt"' .
      ']\' ' . $image_name .
      ' | tee cypress_' . $log_prefix . '_result.txt';
    $ret = script_run($cypress_run_cmd, $timeout);
    if ($ret != 0) {
        # Look for SIGTERM
        script_run('podman logs -t ' . CYPRESS_IMAGE_TAG);
        $self->result("fail");
    }
    if ($failok) {
        record_soft_failure("Cypress exit code:$ret at $log_prefix") if ($ret);
        $ret = 0;
    }
    die "Cypress exec error at '$cmd'" unless ($ret == 0);
}

=head3 cypress_test_exec

Execute a set of cypress tests.
Execute, one by one, all tests in all .js files in the provided folder.

=over 3 

=item B<CYPRESS_TEST_DIR> - String of the path where the cypress Trento code is available.
It is the I<test> folder within the path used by L<setup_jumphost>

=item B<TEST_TAG> - String of the test subfolder within I<$cypress_test_dir/cypress/integration>
Also used as tag for each test result file

=item B<TIMEOUT> - Integer used as timeout for the internal L<cypress_exec> call

=back
=cut

sub cypress_test_exec {
    my ($self, $cypress_test_dir, $test_tag, $timeout) = @_;
    my $ret = 0;

    my $test_file_list = script_output("find $cypress_test_dir/cypress/integration/$test_tag -type f -iname \"*.js\"");

    for (split(/\n/, $test_file_list)) {
        # Compose the JUnit .xml file name, starting from the .js filename
        my $test_filename = basename($_);
        my $test_result = 'test_result_' . $test_tag . '_' . $test_filename;
        $test_result =~ s/js$/xml/;
        my $test_cmd = 'run' .
          ' --spec \"cypress/integration/' . $test_tag . '/' . $test_filename . '\"' .
          ' --reporter junit' .
          ' --reporter-options \"mochaFile=/results/' . $test_result . ',toConsole=true\"';
        record_info('CY INFO', "test_filename:$test_filename test_result:$test_result test_cmd:$test_cmd");

        # Execute the test: force $failok=1 to keep the execution going.
        # Any cypress test failure will be reported during the XUnit parsing
        $self->cypress_exec($cypress_test_dir, $test_cmd, $timeout, $test_tag, 1);

        # Parse the results
        my $find_cmd = 'find ' . $self->CYPRESS_LOG_DIR . ' -type f -iname "' . $test_result . '"';
        parse_extra_log("XUnit", $_) for split(/\n/, script_output($find_cmd));

        # Upload all logs at once
        $self->cypress_log_upload(qw(.txt .mp4));
    }
}

1;
