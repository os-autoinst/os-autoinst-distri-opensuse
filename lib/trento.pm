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
use Carp;
use utils qw(script_retry random_string);
use testapi;
use qesapdeployment;

use Exporter 'import';

our @EXPORT = qw(
  clone_trento_deployment
  get_trento_deployment
  az_delete_group
  cluster_config
  cluster_deploy
  cluster_destroy
  cluster_install_agent
  cluster_print_cluster_status
  cluster_hdbadm
  cluster_trento_net_peering
  cluster_wait_status
  cluster_wait_status_by_regex
  podman_wait
  podman_delete_all
  podman_exec
  get_trento_ip
  deploy_vm
  trento_acr_azure
  install_trento
  cypress_configs
  cypress_install_container
  CYPRESS_LOG_DIR
  PODMAN_PULL_LOG
  cypress_exec
  cypress_test_exec
  cypress_log_upload
  k8s_logs
  k8s_test
  trento_support
  trento_collect_scenarios
  trento_api_key
);

# Exported constants
use constant CYPRESS_LOG_DIR => '/root/result';
use constant PODMAN_PULL_LOG => '/tmp/podman_pull.log';

# Lib internal constants
use constant VM_USER => 'cloudadmin';
use constant SSH_KEY => '/root/.ssh/id_rsa';
use constant TRENTO_AZ_PREFIX => 'openqa-trento';
use constant TRENTO_QESAPDEPLOY_PREFIX => 'qesapdep';
use constant TRENTO_SCRIPT_RUN => 'set -o pipefail ; ./';
use constant GITLAB_CLONE_LOG => '/tmp/gitlab_clone.log';

# Parameter 'registry_name' must conform to
# the following pattern: '^[a-zA-Z0-9]*$'.
# Azure does not support dash or underscore in ACR name
use constant TRENTO_AZ_ACR_PREFIX => 'openqatrentoacr';

# Constants used for cypress image
use constant CYPRESS_IMAGE_TAG => 'trento_cy';
use constant CYPRESS_IMAGE => 'docker.io/cypress/included';
use constant CYPRESS_DEFAULT_VERSION => '9.6.1';


=head1 DESCRIPTION

Package with common methods and default or
constant values for Trento tests

=head2 Methods
=cut

=hean3 clone_trento_deployment

Clone gitlab.suse.de/qa-css/trento

=over 1

=item B<WORK_DIR> - folder where to clone the repo

=back
=cut

sub clone_trento_deployment {
    my ($work_dir) = @_;
    # Get the code for the Trento deployment
    my $gitlab_repo = get_var('TRENTO_GITLAB_REPO', 'gitlab.suse.de/qa-css/trento');

    # The usage of a variable with a different name is to
    # be able to overwrite the token when manually triggering
    # the setup_jumphost test.
    my $gitlab_token = get_var('TRENTO_GITLAB_TOKEN', get_required_var('_SECRET_TRENTO_GITLAB_TOKEN'));

    my $gitlab_clone_url = 'https://git:' . $gitlab_token . '@' . $gitlab_repo;

    record_info('CLONE', "Clone $gitlab_repo in $work_dir");
    assert_script_run("cd $work_dir");
    assert_script_run("git clone $gitlab_clone_url .  2>&1 | tee " . GITLAB_CLONE_LOG);
}

=head3 get_trento_deployment

Get the set of scripts for the Trento deployment

=over 1

=item B<WORK_DIR> - folder where to clone the repo

=back
=cut

sub get_trento_deployment {
    my ($work_dir) = @_;

    enter_cmd "cd $work_dir";
    script_run 'read -s GITLAB_TOKEN', 0;
    type_password get_var('TRENTO_GITLAB_TOKEN', get_required_var('_SECRET_TRENTO_GITLAB_TOKEN')) . "\n";

    # Script from a release
    if (get_var('TRENTO_DEPLOY_VER')) {

        # Clean up whatever is present in the indicated working folder
        # of the qcow2 image, to avoid confusion
        enter_cmd 'rm -rf *';

        # Get some 'coordinates' from the test settings
        my $ver = get_var('TRENTO_DEPLOY_VER');
        my $gitlab_repo = get_var('TRENTO_GITLAB_REPO', 'gitlab.suse.de/qa-css/trento');
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
        my $download_cmd = $curl_cmd . ' -f' .
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
        my $git_branch = get_var('TRENTO_GITLAB_BRANCH', 'master');

        if (script_run('git rev-parse --is-inside-work-tree') != 0) {
            clone_trento_deployment($work_dir);
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
        assert_script_run("git pull");
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

=head3 cluster_config

Create a variable map and prepare the qe-sap-deployment using it
=over 3

=item B<PROVIDER> - CloudProvider name

=item B<REGION> - region for the deployment

=item B<SCC> - SCC_REGCODE

=back
=cut

sub cluster_config {
    my ($provider, $region, $scc) = @_;

    my $resource_group_postfix = TRENTO_QESAPDEPLOY_PREFIX . get_current_job_id();
    my $ssh_key_pub = SSH_KEY . '.pub';

    # to match sub-folder name in terraform folder of qe-sap-deployment
    my $qesap_provider = lc($provider);

    my %variables;
    $variables{PROVIDER} = $qesap_provider;
    $variables{REGION} = $region;
    $variables{DEPLOYMENTNAME} = $resource_group_postfix;
    $variables{TRENTO_CLUSTER_OS_VER} = get_required_var("TRENTO_QESAPDEPLOY_CLUSTER_OS_VER");
    $variables{CLUSTER_USER} = VM_USER;
    $variables{SSH_KEY_PRIV} = SSH_KEY;
    $variables{SSH_KEY_PUB} = $ssh_key_pub;
    $variables{SCC_REGCODE_SLES4SAP} = $scc;

    $variables{HANA_ACCOUNT} = get_required_var("TRENTO_QESAPDEPLOY_HANA_ACCOUNT");
    $variables{HANA_CONTAINER} = get_required_var("TRENTO_QESAPDEPLOY_HANA_CONTAINER");
    if (get_var("TRENTO_QESAPDEPLOY_HANA_TOKEN")) {
        $variables{HANA_TOKEN} = get_required_var("TRENTO_QESAPDEPLOY_HANA_TOKEN");
        # escape needed by 'sed'
        # but not implemented in file_content_replace() yet poo#120690
        $variables{HANA_TOKEN} =~ s/\&/\\\&/g;
    }
    $variables{HANA_SAR} = get_required_var("TRENTO_QESAPDEPLOY_SAPCAR");
    $variables{HANA_CLIENT_SAR} = get_required_var("TRENTO_QESAPDEPLOY_IMDB_CLIENT");
    $variables{HANA_SAPCAR} = get_required_var("TRENTO_QESAPDEPLOY_IMDB_SERVER");
    qesap_prepare_env(openqa_variables => \%variables, provider => $qesap_provider);
}

=head3 deploy_vm

Deploy the main VM for the Trento application
Based on 00.040-trento_vm_server_deploy_azure.sh

=over 1

=item B<WORK_DIR> - folder where to clone the repo

=back
=cut

sub deploy_vm {
    my ($work_dir) = @_;
    enter_cmd "cd $work_dir";
    my $script_id = '00.040';
    my $resource_group = get_resource_group();
    my $machine_name = get_vm_name();
    record_info($script_id);
    my $vm_image = get_var('TRENTO_VM_IMAGE', 'SUSE:sles-sap-15-sp3-byos:gen2:latest');
    my $deploy_script_log = "script_$script_id.log.txt";
    my $cmd = join(' ', TRENTO_SCRIPT_RUN . 'trento_deploy/trento_deploy.py', '--verbose', '00_040',
        '-g', $resource_group,
        '-s', $machine_name,
        '-i', $vm_image,
        '-a', VM_USER,
        '-k', SSH_KEY . '.pub',
        "2>&1|tee $deploy_script_log");
    assert_script_run($cmd, 360);
    upload_logs($deploy_script_log);
}

=head3 trento_acr_azure

Create ACR in Azure and upload from IBS needed images
Based on trento_acr_azure.sh

=over 1

=item B<WORK_DIR> - folder where to clone the repo

=back
=cut

sub trento_acr_azure {
    my ($work_dir) = @_;
    enter_cmd "cd $work_dir";
    my $script_id = 'trento_acr_azure';
    my $resource_group = get_resource_group();
    my $acr_name = get_acr_name();
    record_info($script_id);
    my $trento_registry_chart = get_var('TRENTO_REGISTRY_CHART', 'registry.suse.com/trento/trento-server');
    my $cfg_json = 'config_images_gen.json';
    my @imgs = qw(WEB RUNNER WANDA);

    # this setting combination require config_helper.py and trento_cluster_install.sh
    my $rolling_mode = (get_var("TRENTO_REGISTRY_IMAGE_$imgs[0]") || get_var("TRENTO_REGISTRY_IMAGE_$imgs[1]") || get_var('TRENTO_REGISTRY_CHART_VERSION'));

    my @cfg_helper_cmd = (TRENTO_SCRIPT_RUN . 'trento_deploy/config_helper.py',
        '-o', $cfg_json,
        '--chart', $trento_registry_chart);
    push @cfg_helper_cmd, ('--chart-version', get_var('TRENTO_REGISTRY_CHART_VERSION')) if (get_var('TRENTO_REGISTRY_CHART_VERSION'));
    foreach my $img (@imgs) {
        if (get_var("TRENTO_REGISTRY_IMAGE_$img")) {
            push @cfg_helper_cmd, ('--' . lc($img), get_var("TRENTO_REGISTRY_IMAGE_$img"));
            push @cfg_helper_cmd, '--' . lc($img) . '-version';
            push @cfg_helper_cmd, get_var("TRENTO_REGISTRY_IMAGE_${img}_VERSION", 'latest');
        }
    }
    if ($rolling_mode) {
        assert_script_run(join(' ', @cfg_helper_cmd));
        upload_logs($cfg_json);
        $trento_registry_chart = $cfg_json;
    }
    my $deploy_script_log = "script_$script_id.log.txt";
    my $trento_cluster_install = "${work_dir}/trento_cluster_install.sh";
    my $trento_acr_azure_timeout = bmwqemu::scale_timeout(360);
    my @cmd_list = (TRENTO_SCRIPT_RUN . $script_id . '.sh',
        '-g', $resource_group,
        '-n', $acr_name,
        '-u', VM_USER,
        '-r', $trento_registry_chart);
    if ($rolling_mode) {
        $trento_acr_azure_timeout += bmwqemu::scale_timeout(240);
        push @cmd_list, ('-o', $work_dir);
    }
    push @cmd_list, ('-v', '2>&1|tee', $deploy_script_log);
    assert_script_run(join(' ', @cmd_list), $trento_acr_azure_timeout);
    upload_logs($deploy_script_log);
    upload_logs($trento_cluster_install) if ($rolling_mode);

    my $acr_server = script_output("az acr list -g $resource_group --query \"[0].loginServer\" -o tsv");
    my $acr_username = script_output("az acr credential show -n $acr_name --query username -o tsv");
    my $acr_secret = script_output("az acr credential show -n $acr_name --query 'passwords[0].value' -o tsv");

    # Check what registry has been created by trento_acr_azure
    assert_script_run("az acr repository list -n $acr_name");

    my %return_values = (
        trento_cluster_install => $trento_cluster_install,
        acr_server => $acr_server,
        acr_username => $acr_username,
        acr_secret => $acr_secret);
    return %return_values;
}

=head3 install_trento

Install Trento on the VM. Based on 01.010-trento_server_installation_premium_v.sh
=cut

sub install_trento {
    my (%args) = @_;
    my $work_dir = $args{work_dir};
    my $acr = $args{acr};

    enter_cmd "cd $work_dir";

    my $script_id = '01.010';
    record_info($script_id);
    my $machine_ip = get_trento_ip();
    my $deploy_script_log = "script_$script_id.log.txt";
    my @imgs = qw(WEB RUNNER);
    my @cmd_list = (TRENTO_SCRIPT_RUN . $script_id . '-trento_server_installation_premium_v.sh',
        '-i', $machine_ip,
        '-k', SSH_KEY,
        '-u', VM_USER);

    if (get_var('TRENTO_REGISTRY_CHART_VERSION')) {
        push @cmd_list, ('-c', get_var('TRENTO_REGISTRY_CHART_VERSION'));
    }
    elsif (get_var('TRENTO_VERSION')) {
        push @cmd_list, ('-c', get_var('TRENTO_VERSION'));
    }
    if (get_var("TRENTO_REGISTRY_IMAGE_$imgs[0]") || get_var("TRENTO_REGISTRY_IMAGE_$imgs[1]")) {
        push @cmd_list, ('-x', $acr->{'trento_cluster_install'});
    }
    push @cmd_list, ('-t', get_var('TRENTO_WEB_PASSWORD')) if (get_var('TRENTO_WEB_PASSWORD'));

    push @cmd_list, ('-p', '$(pwd)');
    push @cmd_list, ('-r', $acr->{'acr_server'} . '/trento/trento-server');
    push @cmd_list, ('-s', $acr->{'acr_username'});
    push @cmd_list, ('-w', $acr->{'acr_secret'});
    push @cmd_list, ('-v', '2>&1|tee', $deploy_script_log);
    assert_script_run(join(' ', @cmd_list), 600);
    upload_logs($deploy_script_log);
}

=head3 cluster_deploy

Deploy a SAP Landscape using a previously configured qe-sap-deployment
=cut

sub cluster_deploy {
    my @ret = qesap_execute(cmd => 'terraform', verbose => 1, timeout => bmwqemu::scale_timeout(1800));
    die "'qesap.py terraform' return: $ret[0]" if ($ret[0]);
    @ret = qesap_execute(cmd => 'ansible', verbose => 1, timeout => bmwqemu::scale_timeout(3600));
    die "'qesap.py ansible' return: $ret[0]" if ($ret[0]);
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    upload_logs($inventory);
}

=head3 cluster_destroy

Destroy the qe-sap-deployment SAP Landscape
=cut

sub cluster_destroy {
    my @ret = qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => bmwqemu::scale_timeout(300));
    die "'qesap.py ansible -d' return: $ret[0]" if ($ret[0]);
    @ret = qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => bmwqemu::scale_timeout(3600));
    die "'qesap.py terraform -d' return: $ret[0]" if ($ret[0]);
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

=head3 get_trento_private_ip

Return the private IP of the Trento instance, needed by the agent configuration
=cut

sub get_trento_private_ip {
    my $az_cmd = sprintf 'az vm list -g %s --show-details --query "[?publicIps==\'%s\'].{PrivateIP:privateIps}" -o tsv',
      get_resource_group(),
      get_trento_ip();
    return script_output($az_cmd, 180);
}

=head3 get_trento_password

Return the password for the Trento WebUI
=cut

sub get_trento_password {
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
    my $az_cmd = sprintf 'az group delete --resource-group %s --yes', get_resource_group();
    script_retry($az_cmd, timeout => bmwqemu::scale_timeout(600), retry => 5, delay => 60);
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
    return join(' ', 'ssh',
        '-o', 'UserKnownHostsFile=/dev/null',
        '-o', 'StrictHostKeyChecking=no',
        '-o', 'LogLevel=ERROR',
        '-i', SSH_KEY,
        VM_USER . '@' . $vm_ip_arg,
        '--', $cmd_arg);
}

=head3 cluster_install_agent

Install trento-agent on all the nodes.
Installation is performed using ansible.

=over 3

=item B<WORK_DIRECTORY> - Working directory, used to eventually download .rpm

=item B<PLAYBOOK_LOCATION> - Path where to find trento-agent.yaml file

=item B<API_KEY> - Api key needed to configure trento-agent

=back
=cut

sub cluster_install_agent {
    my ($wd, $playbook_location, $agent_api_key) = @_;
    my $local_rpm_arg = '';
    my $cmd;
    if (get_var('TRENTO_AGENT_RPM')) {
        my $package = get_var('TRENTO_AGENT_RPM');
        my $ibs_location = get_var('TRENTO_AGENT_REPO', 'https://dist.suse.de/ibs/Devel:/SAP:/trento:/factory/SLE_15_SP3/x86_64');
        $cmd = "curl -f --verbose \"$ibs_location/$package\" --output $wd/$package";
        assert_script_run($cmd);
        $local_rpm_arg = " -e agent_rpm=$wd/$package";
    }
    my $private_ip = get_trento_private_ip();
    $cmd = join(' ', 'ansible-playbook', '-vv',
        '-i', qesap_get_inventory(lc get_required_var('PUBLIC_CLOUD_PROVIDER')),
        "$playbook_location/trento-agent.yaml",
        $local_rpm_arg,
        '-e', "api_key=$agent_api_key",
        '-e', "trento_private_addr=$private_ip",
        '-e', 'trento_server_pub_key=' . SSH_KEY . '.pub');
    assert_script_run($cmd);
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

=head3 k8s_test

Test Trento VM and k8s cluster running on it

=cut

sub k8s_test {
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        my $machine_ip = get_trento_ip();
        my $resource_group = get_resource_group();

        # check if VM is still there :-)
        assert_script_run("az vm list -g $resource_group --query \"[].name\"  -o tsv", 180);

        # get deployed version from the cluster
        my $kubectl_pods = script_output(az_vm_ssh_cmd('kubectl get pods', $machine_ip), 180);
        foreach my $row (split(/\n/, $kubectl_pods)) {
            if ($row =~ m/trento-server-web/) {
                my $pod_name = (split /\s/, $row)[0];
                my $trento_ver_cmd = az_vm_ssh_cmd("kubectl exec --stdin $pod_name -- /app/bin/trento version", $machine_ip);
                script_run($trento_ver_cmd, 180);
            }
        }
    }
}

=head3 trento_support

Call trento-support.sh and dump_scenario_from_k8.sh
and upload the logs
=cut

sub trento_support {
    my $machine_ip = get_trento_ip();
    return unless ($machine_ip);

    my $log_dir = 'remote_logs/';
    enter_cmd "mkdir $log_dir";
    my $scp_cmd = sprintf 'scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i %s %s@%s',
      SSH_KEY, VM_USER, $machine_ip;
    my $cmd = join(' ',
        'sudo',
        'KUBECONFIG=/etc/rancher/k3s/k3s.yaml', 'PATH=${PATH}:/home/' . VM_USER . '/bin/',
        './trento-support.sh',
        '--output', 'file-tgz',
        '--collect', 'all');
    script_run(az_vm_ssh_cmd($cmd, $machine_ip));
    script_run("$scp_cmd:'*.tar.gz' $log_dir");

    foreach my $this_file (split("\n", script_output('ls -1 ' . $log_dir . '*.tar.gz'))) {
        upload_logs($this_file, failok => 1);
    }
    enter_cmd("rm -f $log_dir/*.tar.gz");
}

=head3 trento_collect_scenarios

Call dump_scenario_from_k8.sh
and upload the logs
=cut

sub trento_collect_scenarios {
    my ($scenario) = @_;
    my $machine_ip = get_trento_ip();

    return unless ($machine_ip);

    my $log_dir = 'remote_logs/';
    enter_cmd "mkdir $log_dir";
    my $scp_cmd = sprintf 'scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i %s %s@%s',
      SSH_KEY, VM_USER, $machine_ip;

    my $scenario_name = $scenario || 'openqa_scenario';
    script_run(az_vm_ssh_cmd("./dump_scenario_from_k8.sh -n $scenario_name", $machine_ip));
    script_run(az_vm_ssh_cmd("tar -czvf $scenario_name.photofinish.tar.gz scenarios/$scenario_name/*.json", $machine_ip));
    script_run(az_vm_ssh_cmd("rm -rf scenarios/$scenario_name/*.json", $machine_ip));
    script_run("$scp_cmd:'$scenario_name.photofinish.tar.gz' $log_dir");
    script_run(az_vm_ssh_cmd('rm -rf *.photofinish.tar.gz', $machine_ip));

    foreach my $this_file (split("\n", script_output('ls -1 ' . $log_dir . '*.photofinish.tar.gz'))) {
        upload_logs($this_file, failok => 1);
    }
    enter_cmd("rm -rf $log_dir/*.photofinish.tar.gz");
}

=head3 trento_api_key

Get the api-key from the Trento installation

=over 1

=item B<BASEDIR> - Folder of the trento installer repo clone

=back
=cut

sub trento_api_key {
    my ($basedir) = @_;
    my $cmd = join(' ', $basedir . '/trento_deploy/trento_deploy.py',
        '--verbose', 'api_key',
        '-u', 'admin',
        '-p', get_trento_password(),
        '-i', get_trento_ip());
    my $agent_api_key = '';
    my @lines = split(/\n/, script_output($cmd));
    foreach my $line (@lines) {
        if ($line =~ /api_key:(.*)/) {
            $agent_api_key = $1;
        }
    }
    return $agent_api_key;
}

=head3 cluster_print_cluster_status

Run `crm status` and `SAPHanaSR-showAttr --format=script`
on the specified host. Command is executed remotely with
Ansible and nothing more (no output collected for further processing)
=cut

sub cluster_print_cluster_status {
    my ($host) = @_;
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(
        cmd => 'crm status',
        provider => $prov,
        filter => $host);
    qesap_ansible_cmd(cmd => 'SAPHanaSR-showAttr --format=script',
        provider => $prov,
        filter => $host);
}

=head3 cluster_hdbadm

Remotly run on $host as user hdbadm
=cut

sub cluster_hdbadm {
    my ($host, $cmd) = @_;
    # Stop the primary DB
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(
        cmd => "su - hdbadm -c '$cmd'",
        provider => $prov,
        filter => $host);
}

=head3 cluster_wait_status

This function allow to wait for a specific output
for 'SAPHanaSR-showAttr', on one specific remote host.
Remotely runs 'SAPHanaSR-showAttr' on $host.
Runs 'SAPHanaSR-showAttr' multiple times in a loop,
retying until the output PASS the test 'f_status'.
The 'f_status' test is passed as a "function pointer".

Usage example:
    cluster_wait_status($primary_host, sub { ((shift =~ m/.+UNDEFINED.+SFAIL/) && (shift =~ m/.+PROMOTED.+PRIM/)); });

This one result in SAPHanaSR-showAttr to be called on the HANA PRIMARY until :
the line about vmhana01 match with regexp .+UNDEFINED.+SFAIL
AND
the line about vmhana02 match with regexp .+PROMOTED.+PRIM

=over 3

=item B<HOST> - Ansible name or filter for the remote host where to run 'SAPHanaSR-showAttr'

=item B<F_STATUS> - Function pointer to test the 'SAPHanaSR-showAttr' stdout.
                    Provided function has to support two arguments.
                    `cluster_wait_status` will call the `f_status` passing as first arguments
                    only the output lines of 'SAPHanaSR-showAttr' about the vmhana01,
                    and as second arguments lines about vmhana02

=item B<TIMEOUT> - Max time to retry. Die if timeout

=back
=cut

sub cluster_wait_status {
    my ($host, $f_status, $timeout) = @_;
    $timeout //= bmwqemu::scale_timeout(300);
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $done = 0;
    my $start_time = time();
    while ((time() - $start_time <= $timeout) && (!$done)) {
        my $show_attr = qesap_ansible_script_output(
            cmd => 'SAPHanaSR-showAttr',
            provider => $prov,
            host => $host,
            root => 1);

        my %status = ();
        for my $line (split("\n", $show_attr)) {
            $status{$1} = $line if ($line =~ m/^(vmhana\d+)/);
        }
        $done = $f_status->($status{vmhana01}, $status{vmhana02});
        record_info("SAPHanaSR-showAttr",
            join("\n------------\n", "Output : $show_attr",
                'status{vmhana01} : ' . $status{vmhana01},
                'status{vmhana02} : ' . $status{vmhana02},
                "done : $done"));
        sleep 30 unless $done;
    }
    die "Timeout waiting for the change" if !$done;
}

=head3 cluster_wait_status_by_regex

Remotely run 'SAPHanaSR-showAttr' in a loop on $host, wait output that matches regular expression
=over 3

=item B<HOST> - Ansible name or filter for the remote host where to run 'SAPHanaSR-showAttr'

=item B<TIMEOUT> - Max time to retry. Die if timeout

=item B<REGULAR_EXPRESSION> - Regular expression to match the text to find

=back
=cut

sub cluster_wait_status_by_regex {
    my ($host, $regular_expression, $timeout) = @_;
    croak 'No regular expression provided' unless (ref $regular_expression eq 'Regexp');
    $timeout //= bmwqemu::scale_timeout(300);
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $done = 0;
    my $start_time = time();
    while ((time() - $start_time <= $timeout) && (!$done)) {
        my $show_attr = qesap_ansible_script_output(
            cmd => 'SAPHanaSR-showAttr',
            provider => $prov,
            host => $host,
            root => 1);

        for my $line (split("\n", $show_attr)) {
            $done = 1 if ($line =~ $regular_expression);
        }
        record_info("SAPHanaSR-showAttr",
            join("\n------------\n", "Output : $show_attr",
                "regexp : $regular_expression",
                "done : $done",));
        sleep 30 unless $done;
    }
    die "Timeout waiting for the change" if !$done;
}

=head3 cluster_trento_net_peering

Run 00.050 net peering script
=cut

sub cluster_trento_net_peering {
    my ($basedir) = @_;
    my $trento_rg = get_resource_group();
    my $cluster_rg = qesap_az_get_resource_group(substring => TRENTO_QESAPDEPLOY_PREFIX);
    my $cmd = join(' ',
        $basedir . '/00.050-trento_net_peering_tserver-sap_group.sh',
        '-s', $trento_rg,
        '-n', qesap_az_get_vnet($trento_rg),
        '-t', $cluster_rg,
        '-a', qesap_az_get_vnet($cluster_rg));
    record_info('NET PEERING');
    assert_script_run($cmd, 360);
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

=head3 podman_delete_all

Delete all podman containers with name containing CYPRESS_IMAGE_TAG

=cut

sub podman_delete_all {
    my $cmd = join(' ',
        'podman', 'ps',
        '--all',
        '--format', '"{{.Status}},{{.Names}}"');
    for my $container (split(/\n/, script_output($cmd, bmwqemu::scale_timeout(10), proceed_on_failure => 1))) {
        record_info('podman_delete_all', "container: $container");
        # Note about the regexp: it is composed using a constant variable
        #    - outer round bracket are for a Perl regexp match group
        #    - inner round bracket and backslash are to "escape" the constant
        enter_cmd("podman rm $1") if ($container =~ qr/.*,(${\(CYPRESS_IMAGE_TAG)}.*)/);
    }
}

=head3 podman_wait

Check for status of running container with given name.
Polling state until container Status become Exit or timeout.
Gently terminate podman in case of timeout.
Return the container Exit status.

=over 3

=item B<NAME> - Name of the running container used to filter the podman ps

=item B<TIMEOUT> - Timeout waiting container to exit

=item B<CYPRESS_LOG> - File used to redirect the cypress console output

=back
=cut

sub podman_wait {
    my (%args) = @_;
    croak 'Missing mandatory name argument' unless $args{name};
    croak 'Missing mandatory timeout argument' unless $args{timeout};

    my $cmd = join(' ',
        'podman', 'ps',
        '--all',
        '--filter', '"name=' . $args{name} . '"',
        '--format', '"{{.Status}},{{.Names}}"');

    my $start_time = time();
    my $done = 0;
    my $ret = undef;
    while ((time() - $start_time <= $args{timeout}) && (!defined $ret)) {
        # This code will run podman ps --all using script_output and get the output parsed with a regexp
        # Let say the CY image is called MY_IMG, the output could be of of these two:
        #     Up 39 seconds,MY_IMG
        #     Exited (0) 38 seconds ago,MY_IMG
        #
        # The regexp only match for:
        #   - Start with "Exit"
        #   - There's a number in round bracket
        #   - End with ",MY_IMG"
        # The regexp has to match --format from the previous podman command
        # The regexp also extracts the number in round bracket (it is the $1)
        # that is assigned to $ret variable.
        # If the regexp does not match, undef is assigned to $ret
        # that result in the look to keep spinning.
        if (script_output($cmd, bmwqemu::scale_timeout(10), proceed_on_failure => 1)
            =~ qr/Exited \((\d+)\).*,$args{name}/) {
            $ret = $1;
            # the cypress container is done but podman process need some more time.
            # Notice that this `wait` is only executed if the internal container
            # has been detected as `Exited`
            # pwait is not available in the JumpHost
            script_run('wait $(pgrep -f "podman.*' . $args{name} . '")', timeout => bmwqemu::scale_timeout(10));
            record_info('CY DONE', "ret: $ret");
        }
        sleep bmwqemu::scale_timeout(30) if !defined $ret;
    }

    if (!defined $ret) {
        # The previous while loop exited for timeout.
        # Retrieve logs and gently terminate podman
        record_info('CY TIMEOUT', "");

        # In case of timeout, extract more debug information from
        # inside the running container
        podman_exec(name => $args{name}, cmd => 'ps aux');
        podman_exec(name => $args{name}, cmd => 'pgrep cypress');

        # Kill cypress within the container ...
        podman_exec(name => $args{name}, cmd => 'pkill -15 cypress');
        # ... give podman few more seconds to terminate ...
        sleep bmwqemu::scale_timeout(10);
        enter_cmd('pkill -9 podman');
        # Conventionally the reported error is 1 (just something not zero)
        $ret = 1;
    }

    # read more logs for debug purpose
    script_run("podman logs -t $args{name}") if $ret;

    return $ret;
}


=head3 podman_exec

Run a command within the running container

=over 2

=item B<NAME> - Name of the running container where to exec commands

=item B<CMD> - command to run within the container

=back
=cut

sub podman_exec {
    my (%args) = @_;
    croak 'Missing mandatory name argument' unless $args{name};
    croak 'Missing mandatory cmd argument' unless $args{cmd};

    return script_run("podman exec $args{name} $args{cmd}",
        timeout => bmwqemu::scale_timeout(10), die_on_timeout => -1);
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
      $machine_ip, get_trento_password(), qesap_get_nodes_number(), get_required_var('TRENTO_VERSION');
    if (get_var('TRENTO_AGENT_RPM')) {
        my $cypress_env_cmd .= ' -a ' . get_var('TRENTO_AGENT_RPM');
    }
    assert_script_run($cypress_env_cmd);
    assert_script_run('cat cypress.env.json');
    upload_logs('cypress.env.json');
}

=head3 cypress_install_container

Prepare whatever is needed to run cypress tests using container
=cut

sub cypress_install_container {
    podman_self_check();
    # List all the available cypress images
    script_run('podman search --list-tags ' . CYPRESS_IMAGE);

    my $cypress_ver_ref = get_var_array('TRENTO_CYPRESS_VERSION', CYPRESS_DEFAULT_VERSION);
    foreach my $cypress_ver (@{$cypress_ver_ref}) {
        # Pull in advance the cypress container
        my $podman_pull_cmd = join(' ', 'time', 'podman',
            '--log-level', 'trace',
            'pull',
            '--quiet',
            CYPRESS_IMAGE . ':' . $cypress_ver,
            '|', 'tee', '-a', PODMAN_PULL_LOG);
        assert_script_run($podman_pull_cmd, 1800);
    }
    script_run('df -h');
    script_run('podman images');
}

=head3 cypress_log_upload

Upload to openQA the relevant logs

=over 1

=item B<LOG_FILTER> - List of strings. List of file extensions (dot needed) 

=back
=cut

sub cypress_log_upload {
    my (@log_filter) = @_;
    my $find_cmd = 'find ' . CYPRESS_LOG_DIR . ' -type f \( -iname \*' . join(' -o -iname \*', @log_filter) . ' \)';

    for my $log (split(/\n/, script_output($find_cmd))) {
        upload_logs($log);
        enter_cmd("rm $log");
    }
}

=head3 cypress_exec

Execute a cypress command within the container

=over 4

=item B<CYPRESS_TEST_DIR> - String of the path where the cypress Trento code is available.
It is the I<test> folder within the path used by L<setup_jumphost>

=item B<CMD> - String of cmd to be used as main argument for the cypress
executable call.

=item B<LOG_PREFIX> - String of the command to be executed remotely

=item B<TIMEOUT> - Integer used as timeout for the cypress command execution

=back
=cut

sub cypress_exec {
    my (%args) = @_;
    croak 'Missing mandatory cypress_test_dir argument' unless $args{cypress_test_dir};
    croak 'Missing mandatory cmd argument' unless $args{cmd};
    croak 'Missing mandatory log_prefix argument' unless $args{log_prefix};
    $args{timeout} //= bmwqemu::scale_timeout(600);
    my $ret = 0;

    my $image_name = CYPRESS_IMAGE . ":" . get_var('TRENTO_CYPRESS_VERSION', CYPRESS_DEFAULT_VERSION);
    my $container_name = CYPRESS_IMAGE_TAG . random_string();

    # Container is executed with --name to simplify the log retrieve.
    # To avoid confusion, remove container from previous run
    podman_delete_all();

    my $cypress_log = CYPRESS_LOG_DIR . "/cypress_$args{log_prefix}_log.txt";
    my $cypress_cmd = join(' ',
        'podman', 'run',
        '--name', $container_name,    # define a tag to retrieve the running container later
        '-v', CYPRESS_LOG_DIR . ':/results',    # mount a folder to output results
        '-v', "$args{cypress_test_dir}:/e2e",    # mount a folder to input the test code
        '-w', '/e2e',
        '-e "DEBUG=cypress:*"',
        "--entrypoint cypress",    # doing so allow to specify more arguments for cypress later
        $image_name,    # select the cypress image and its version
        $args{cmd},    # the cypress operation to perform
        '&>' . $cypress_log,    # redirect everything to file
        '&'    # run podman in background
    );
    record_info('CY EXEC',
        join("\n",
            "container_name: $container_name",
            "cmd:  $args{cmd}",
            "cypress_cmd:  $cypress_cmd"));
    enter_cmd('rm -rf ' . CYPRESS_LOG_DIR . '/*.*');
    enter_cmd($cypress_cmd);
    wait_serial('# ');

    $ret = podman_wait(name => $container_name, timeout => $args{timeout});
    record_info('CY EXEC DONE', "ret: $ret");

    script_run("podman rm $container_name");
    return $ret;
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
    my (%args) = @_;
    croak 'Missing mandatory cypress_test_dir argument' unless $args{cypress_test_dir};
    croak 'Missing mandatory test_tag argument' unless $args{test_tag};
    $args{timeout} //= bmwqemu::scale_timeout(600);
    my $ret = 0;

    my $cy_test_struct = 'cypress/integration';
    # The latest version of cypress.io request a different folder structure for the test code
    $cy_test_struct = 'cypress/e2e'
      if ((get_var('TRENTO_CYPRESS_VERSION', CYPRESS_DEFAULT_VERSION) =~ /(\d+)\..*/g) &&
        (int($1) >= 10));

    my $find_cmd = join(' ',
        'find',
        "$args{cypress_test_dir}/$cy_test_struct/$args{test_tag}",
        '-type', 'f',
        '-iname', '"*.js"');
    my $test_file_list = script_output($find_cmd);

    for (split(/\n/, $test_file_list)) {
        # Compose the JUnit .xml file name, starting from the .js filename
        my $test_base_filename = basename($_) =~ s/\.js$//r;
        my $test_result = 'test_result_' . $args{test_tag} . '_' . $test_base_filename . '.xml';
        my $log_tag = join('_', $args{test_tag}, $test_base_filename);
        my $test_cmd = join(' ', 'run',
            '--spec', '"' . $cy_test_struct . '/' . $args{test_tag} . '/' . $test_base_filename . '.js"',
            '--reporter', 'junit',
            '--reporter-options', '"mochaFile=/results/' . $test_result . ',toConsole=true"');
        record_info('CY INFO', join("\n",
                "test_filename:$test_base_filename.js",
                "test_result:$test_result",
                "test_cmd:$test_cmd"));

        # Execute the test keeps going with the execution even if one test file produce an error.
        # Any cypress test failure will be reported during the XUnit parsing
        $ret += cypress_exec(
            cypress_test_dir => $args{cypress_test_dir},
            cmd => $test_cmd,
            log_prefix => $log_tag,
            timeout => $args{timeout});

        # Parse the results
        $find_cmd = join(' ',
            'find',
            CYPRESS_LOG_DIR,
            '-type', 'f',
            '-iname', "\"$test_result\"");
        for my $log (split(/\n/, script_output($find_cmd))) {
            parse_extra_log("XUnit", $log);
            enter_cmd("rm $log");
        }

        # Upload all logs at once
        cypress_log_upload(qw(.txt .mp4));
    }
    return $ret;
}

1;
