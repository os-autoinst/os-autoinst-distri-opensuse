# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions to use qe-sap-deployment project
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

    qe-sap-deployment test lib

=head1 COPYRIGHT

    Copyright 2022 SUSE LLC
    SPDX-License-Identifier: FSFAP

=head1 AUTHORS

    QE SAP <qe-sap@suse.de>

=cut

package qesapdeployment;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use YAML::PP;
use utils qw(file_content_replace);
use version_utils 'is_sle';
use publiccloud::utils qw(get_credentials);
use mmapi 'get_current_job_id';
use testapi;
use Exporter 'import';
use Scalar::Util 'looks_like_number';
use File::Basename;

my @log_files = ();

# Terraform requirement
#  terraform/azure/infrastructure.tf  "azurerm_storage_account" "mytfstorageacc"
# stdiag<PREFID><JOB_ID> can only consist of lowercase letters and numbers,
# and must be between 3 and 24 characters long
use constant QESAPDEPLOY_PREFIX => 'qesapdep';
use constant QESAPDEPLOY_VENV => '/tmp/exec_venv';
use constant QESAPDEPLOY_PY => 'python3.10';
use constant QESAPDEPLOY_PIP => 'pip3.10';

our @EXPORT = qw(
  qesap_upload_logs
  qesap_get_deployment_code
  qesap_get_roles_code
  qesap_get_inventory
  qesap_get_nodes_number
  qesap_get_terraform_dir
  qesap_get_ansible_roles_dir
  qesap_prepare_env
  qesap_execute
  qesap_ansible_cmd
  qesap_ansible_script_output_file
  qesap_ansible_script_output
  qesap_ansible_fetch_file
  qesap_create_ansible_section
  qesap_remote_hana_public_ips
  qesap_wait_for_ssh
  qesap_cluster_log_cmds
  qesap_cluster_logs
  qesap_upload_crm_report
  qesap_az_get_vnet
  qesap_az_get_resource_group
  qesap_az_calculate_address_range
  qesap_az_vnet_peering
  qesap_az_simple_peering_delete
  qesap_az_vnet_peering_delete
  qesap_aws_get_region_subnets
  qesap_aws_get_vpc_id
  qesap_aws_create_transit_gateway_vpc_attachment
  qesap_aws_delete_transit_gateway_vpc_attachment
  qesap_aws_get_transit_gateway_vpc_attachment
  qesap_aws_add_route_to_tgw
  qesap_aws_get_mirror_tg
  qesap_aws_get_vpc_workspace
  qesap_aws_get_routing
  qesap_aws_vnet_peering
  qesap_add_server_to_hosts
  qesap_calculate_deployment_name
  qesap_export_instances
  qesap_import_instances
  qesap_file_find_string
  qesap_is_job_finished
  qesap_az_get_active_peerings
  qesap_az_clean_old_peerings
  qesap_az_setup_native_fencing_permissions
  qesap_az_enable_system_assigned_identity
  qesap_az_assign_role
  qesap_az_get_tenant_id
  qesap_az_validate_uuid_pattern
  qesap_az_create_sas_token
  qesap_terraform_clean_up_retry
  qesap_terrafom_ansible_deploy_retry
);

=head1 DESCRIPTION

    Package with common methods and default or constant  values for qe-sap-deployment

=head2 Methods


=head3 qesap_get_file_paths

    Returns a hash containing file paths for configuration files
=cut

sub qesap_get_file_paths {
    my %paths;
    $paths{qesap_conf_filename} = get_required_var('QESAP_CONFIG_FILE');
    $paths{deployment_dir} = get_var('QESAP_DEPLOYMENT_DIR', '/root/qe-sap-deployment');
    $paths{terraform_dir} = get_var('PUBLIC_CLOUD_TERRAFORM_DIR', $paths{deployment_dir} . '/terraform');
    $paths{qesap_conf_trgt} = $paths{deployment_dir} . '/scripts/qesap/' . $paths{qesap_conf_filename};
    $paths{qesap_conf_src} = data_url('sles4sap/qe_sap_deployment/' . $paths{qesap_conf_filename});
    $paths{roles_dir} = get_var('QESAP_ROLES_DIR', '/root/community.sles-for-sap');
    $paths{roles_dir_path} = $paths{roles_dir} . '/roles';
    return (%paths);
}

=head3 qesap_create_folder_tree

    Create all needed folders
=cut

sub qesap_create_folder_tree {
    my %paths = qesap_get_file_paths();
    assert_script_run("mkdir -p $paths{deployment_dir}", quiet => 1);
    assert_script_run("mkdir -p $paths{roles_dir}", quiet => 1);
}

=head3 qesap_get_variables

    Scans yaml configuration for '%OPENQA_VARIABLE%' placeholders and
    searches for values in OpenQA defined variables.
    Returns hash with openqa variable key/value pairs.
=cut

sub qesap_get_variables {
    my %paths = qesap_get_file_paths();
    die "Missing mandatory qesap_conf_src from qesap_get_file_paths()" unless $paths{'qesap_conf_src'};
    my $yaml_file = $paths{'qesap_conf_src'};
    my %variables;
    my $cmd = join(' ',
        'curl -s -fL', $yaml_file, '|',
        'grep -v', "'#'", '|',
        'grep -oE %[A-Z0-9_]*%', '|',
        'sed s/%//g');

    for my $variable (split(" ", script_output($cmd))) {
        $variables{$variable} = get_required_var($variable);
    }
    return \%variables;
}

=head3 qesap_create_ansible_section

    Writes "ansible" section into yaml configuration file.
    $args{ansible_section} defines section(key) name.
    $args{section_content} defines content of names section.
        Example:
            @playbook_list = ("pre-cluster.yaml", "cluster_sbd_prep.yaml");
            qesap_create_ansible_section(ansible_section=>'create', section_content=>\@playbook_list);

=cut

sub qesap_create_ansible_section {
    my (%args) = @_;
    my $ypp = YAML::PP->new;
    my $section = $args{ansible_section} // 'no_section_provided';
    my $content = $args{section_content} // {};
    my %paths = qesap_get_file_paths();
    my $yaml_config_path = $paths{qesap_conf_trgt};

    assert_script_run("test -e $yaml_config_path", fail_message => "Yaml config file '$yaml_config_path' does not exist.");

    my $raw_file = script_output("cat $yaml_config_path");
    my $yaml_data = $ypp->load_string($raw_file);

    $yaml_data->{ansible}{$section} = $content;

    # write into file
    my $yaml_dumped = $ypp->dump_string($yaml_data);
    save_tmp_file($paths{qesap_conf_filename}, $yaml_dumped);
    assert_script_run('curl -v -fL ' . autoinst_url . "/files/" . $paths{qesap_conf_filename} . ' -o ' . $paths{qesap_conf_trgt});
    return;
}

=head3 qesap_venv_cmd_exec

    Run a command within the Python virtualenv
    created by qesap_pip_install

    Return is only valid if failok = 1

=over 3

=item B<CMD> - command to run remotely

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<TIMEOUT> - default 90 secs

=back
=cut

sub qesap_venv_cmd_exec {
    my (%args) = @_;
    croak 'Missing mandatory cmd argument' unless $args{cmd};
    $args{timeout} //= bmwqemu::scale_timeout(90);
    $args{failok} //= 0;
    my $ret;

    assert_script_run('source ' . QESAPDEPLOY_VENV . '/bin/activate');
    $args{failok} ? $ret = script_run($args{cmd}, timeout => $args{timeout}) :
      assert_script_run($args{cmd}, timeout => $args{timeout});
    # deactivate python virtual environment
    script_run('deactivate');
    return $ret;
}

=head3 qesap_pip_install

  Install all Python requirements of the qe-sap-deployment
  in a dedicated virtual environment
=cut

sub qesap_pip_install {
    my %paths = qesap_get_file_paths();
    my $pip_install_log = '/tmp/pip_install.txt';
    my $pip_ints_cmd = join(' ', QESAPDEPLOY_PIP, 'install --no-color --no-cache-dir',
        '-r', "$paths{deployment_dir}/requirements.txt",
        '|& tee -a', $pip_install_log);

    # Create a Python virtualenv
    assert_script_run(join(' ', QESAPDEPLOY_PY, '-m venv', QESAPDEPLOY_VENV));

    # Configure pip in it
    qesap_venv_cmd_exec(cmd => QESAPDEPLOY_PIP . ' config --site set global.progress_bar off', failok => 1);

    push(@log_files, $pip_install_log);
    record_info('QESAP repo', 'Installing all qe-sap-deployment python requirements');
    qesap_venv_cmd_exec(cmd => $pip_ints_cmd, timeout => 720);
}


=head3 qesap_galaxy_install

  Install all Ansible requirements of the qe-sap-deployment
=cut

sub qesap_galaxy_install {
    my %paths = qesap_get_file_paths();
    my $galaxy_install_log = '/tmp/galaxy_install.txt';

    my $ans_req = "$paths{deployment_dir}/requirements.yml";
    my $ans_galaxy_cmd = join(' ', 'ansible-galaxy install',
        '-r', $ans_req,
        '|& tee -a', $galaxy_install_log);
    qesap_venv_cmd_exec(cmd => $ans_galaxy_cmd, timeout => 720);
    push(@log_files, $galaxy_install_log);
}

=head3 qesap_upload_logs

    qesap_upload_logs([failok=1])

    Collect and upload logs present in @log_files.

=over 1

=item B<FAILOK> - used as failok for the upload_logs. continue even in case upload fails

=back
=cut

sub qesap_upload_logs {
    my (%args) = @_;
    $args{failok} //= 0;
    record_info("Uploading logfiles failok:$args{failok}", join("\n", @log_files));
    while (my $file = pop @log_files) {
        upload_logs($file, failok => $args{failok});
    }
}

=head3 qesap_get_deployment_code

    Get the qe-sap-deployment code
=cut

sub qesap_get_deployment_code {
    my $official_repo = 'github.com/SUSE/qe-sap-deployment';
    my $qesap_git_clone_log = '/tmp/git_clone.txt';
    my %paths = qesap_get_file_paths();
    die "Missing mandatory terraform_dir from qesap_get_file_paths()" unless $paths{'terraform_dir'};

    record_info('QESAP repo', 'Preparing qe-sap-deployment repository');

    enter_cmd "cd " . $paths{deployment_dir};
    push(@log_files, $qesap_git_clone_log);

    # Script from a release
    if (get_var('QESAP_INSTALL_VERSION')) {
        record_info('WARNING', 'QESAP_INSTALL_GITHUB_REPO will be ignored') if (get_var('QESAP_INSTALL_GITHUB_REPO'));
        record_info('WARNING', 'QESAP_INSTALL_GITHUB_BRANCH will be ignored') if (get_var('QESAP_INSTALL_GITHUB_BRANCH'));
        my $ver_artifact = 'v' . get_var('QESAP_INSTALL_VERSION') . '.tar.gz';

        my $curl_cmd = "curl -v -fL https://$official_repo/archive/refs/tags/$ver_artifact -o$ver_artifact";
        assert_script_run("set -o pipefail ; $curl_cmd | tee " . $qesap_git_clone_log, quiet => 1);

        my $tar_cmd = "tar xvf $ver_artifact --strip-components=1";
        assert_script_run($tar_cmd);
    }
    else {
        # Get the code for the qe-sap-deployment by cloning its repository
        assert_script_run('git config --global http.sslVerify false', quiet => 1) if get_var('QESAP_INSTALL_GITHUB_NO_VERIFY');
        my $git_branch = get_var('QESAP_INSTALL_GITHUB_BRANCH', 'main');

        my $git_repo = get_var('QESAP_INSTALL_GITHUB_REPO', $official_repo);
        my $git_clone_cmd = 'git clone --depth 1 --branch ' . $git_branch . ' https://' . $git_repo . ' ' . $paths{deployment_dir};
        assert_script_run("set -o pipefail ; $git_clone_cmd  2>&1 | tee $qesap_git_clone_log", quiet => 1);
    }
    # Add symlinks for different provider directory naming between OpenQA and qesap-deployment
    assert_script_run("ln -s " . $paths{terraform_dir} . "/aws " . $paths{terraform_dir} . "/ec2");
    assert_script_run("ln -s " . $paths{terraform_dir} . "/gcp " . $paths{terraform_dir} . "/gce");
}


=head3 qesap_get_roles_code
    Get the Ansible roles code from github.com/sap-linuxlab/community.sles-for-sap

    Keep in mind that to allow qe-sap-deployment to use roles from this repo,
    your config.yaml has to have a specific setting ansible::roles_path.
=cut

sub qesap_get_roles_code {
    my $official_repo = 'github.com/sap-linuxlab/community.sles-for-sap';
    my $roles_git_clone_log = '/tmp/git_clone_roles.txt';
    my %paths = qesap_get_file_paths();

    record_info('SLES4SAP Roles repo', 'Preparing community.sles-for-sap repository');

    enter_cmd "cd " . $paths{roles_dir};
    push(@log_files, $roles_git_clone_log);

    # Script from a release
    if (get_var('QESAP_ROLES_INSTALL_VERSION')) {
        die('community.sles-for-sap does not implement releases yet.');
    }
    else {
        # Get the code for the community.sles-for-sap by cloning its repository
        assert_script_run('git config --global http.sslVerify false', quiet => 1) if get_var('QESAP_INSTALL_GITHUB_NO_VERIFY');
        my $git_branch = get_var('QESAP_ROLES_INSTALL_GITHUB_BRANCH', 'main');

        my $git_repo = get_var('QESAP_ROLES_INSTALL_GITHUB_REPO', $official_repo);
        my $git_clone_cmd = 'git clone --depth 1 --branch ' . $git_branch . ' https://' . $git_repo . ' ' . $paths{roles_dir};
        assert_script_run("set -o pipefail ; $git_clone_cmd  2>&1 | tee $roles_git_clone_log", quiet => 1);
    }
}

=head3 qesap_yaml_replace

    Replaces yaml configuration file variables with parameters
    defined by OpenQA test code, yaml template or yaml schedule.
    Openqa variables need to be added as a hash
    with key/value pair inside %run_args{openqa_variables}.
    Example:
        my %variables;
        $variables{HANA_SAR} = get_required_var("HANA_SAR");
        $variables{HANA_CLIENT_SAR} = get_required_var("HANA_CLIENT_SAR");
        qesap_yaml_replace(openqa_variables=>\%variables);
=cut

sub qesap_yaml_replace {
    my (%args) = @_;
    my $variables = $args{openqa_variables};
    my %replaced_variables = ();
    my %paths = qesap_get_file_paths();
    push(@log_files, $paths{qesap_conf_trgt});

    for my $variable (keys %{$variables}) {
        $replaced_variables{"%" . $variable . "%"} = $variables->{$variable};
    }
    file_content_replace($paths{qesap_conf_trgt}, %replaced_variables);
    qesap_upload_logs();
}

=head3 qesap_execute

    qesap_execute(cmd => $qesap_script_cmd [, verbose => 1, cmd_options => $cmd_options] );
    cmd_options - allows to append additional qesap.py commands arguments
    like "qesap.py terraform -d"
        Example:
        qesap_execute(cmd => 'terraform', cmd_options => '-d') will result in:
        qesap.py terraform -d

    Execute qesap glue script commands. Check project documentation for available options:
    https://github.com/SUSE/qe-sap-deployment
    Test only returns execution result, failure has to be handled by calling method.

=over 5

=item B<CMD> - qesap.py subcommand to run

=item B<CMD_OPTIONS> - set of arguments for the qesap.py subcommand

=item B<VERBOSE> - activate verbosity in qesap.py

=item B<TIMEOUT> - max expected execution time

=item B<LOGNAME> - filename of the log file. This argument is optional,
                   if not specified the log filename is internally calculated
                   using content from CMD and CMD_OPTIONS.

=back
=cut

sub qesap_execute {
    my (%args) = @_;
    croak 'Missing mandatory cmd argument' unless $args{cmd};
    my $verbose = $args{verbose} ? "--verbose" : "";
    $args{cmd_options} ||= '';

    my %paths = qesap_get_file_paths();
    my $exec_log = '/tmp/';
    if ($args{logname})
    {
        $exec_log .= $args{logname};
    } else {
        $exec_log .= "qesap_exec_$args{cmd}";
        $exec_log .= "_$args{cmd_options}" if ($args{cmd_options});
        $exec_log .= '.log.txt';
        $exec_log =~ s/[-\s]+/_/g;
    }

    my $qesap_cmd = join(' ', QESAPDEPLOY_PY, $paths{deployment_dir} . '/scripts/qesap/qesap.py',
        $verbose,
        '-c', $paths{qesap_conf_trgt},
        '-b', $paths{deployment_dir},
        $args{cmd},
        $args{cmd_options},
        '|& tee -a',
        $exec_log
    );

    push(@log_files, $exec_log);
    record_info('QESAP exec', "Executing: \n$qesap_cmd");

    my $exec_rc = qesap_venv_cmd_exec(cmd => $qesap_cmd, timeout => $args{timeout}, failok => 1);

    qesap_upload_logs();
    my @results = ($exec_rc, $exec_log);
    return @results;
}

=head3 qesap_file_find_string

    Search for a string in the Ansible log file.
    Returns 1 if the string is found in the log file, 0 otherwise.

=over 2

=item B<FILE> - Path to the Ansible log file. (Required)

=item B<SEARCH_STRING> - String to search for in the log file. (Required)

=back
=cut

sub qesap_file_find_string {
    my (%args) = @_;
    foreach (qw(file search_string)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $ret = script_run("grep \"$args{search_string}\" $args{file}");
    return $ret == 0 ? 1 : 0;
}

=head3 qesap_get_inventory

    Return the path of the generated inventory

=over 1

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_inventory {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my %paths = qesap_get_file_paths();
    return join('/', qesap_get_terraform_dir(provider => $args{provider}), 'inventory.yaml');
}

=head3 qesap_get_nodes_number

Get the number of cluster nodes from the inventory.yaml
=cut

sub qesap_get_nodes_number {
    my $inventory = qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $yp = YAML::PP->new();

    my $inventory_content = script_output("cat $inventory");
    my $parsed_inventory = $yp->load_string($inventory_content);
    my $num_hosts = 0;
    while ((my $key, my $value) = each(%{$parsed_inventory->{all}->{children}})) {
        $num_hosts += keys %{$value->{hosts}};
    }
    return $num_hosts;
}

=head3 qesap_get_terraform_dir

    Return the path used by the qesap script as -chdir argument for terraform
    It is useful if test would like to call terraform

=over 1

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_terraform_dir {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my %paths = qesap_get_file_paths();
    return join('/', $paths{terraform_dir}, lc $args{provider});
}

=head3 qesap_get_ansible_roles_dir

    Return the path where sap-linuxlab/community.sles-for-sap
    has been installed
=cut

sub qesap_get_ansible_roles_dir {
    my %paths = qesap_get_file_paths();
    return $paths{roles_dir_path};
}

=head3 qesap_prepare_env

    qesap_prepare_env(variables=>{dict with variables}, provider => 'aws');

    Prepare terraform environment.
    - creates file structures
    - pulls git repository
    - external configuration files
    - installs pip requirements and OS packages
    - generates configuration files with qesap script

    For variables example see 'qesap_yaml_replace'
    Returns only result, failure handling has to be done by calling method.

=over 1

=item B<PROVIDER> - Cloud provider name, used to optionally activate AWS credential code

=back
=cut

sub qesap_prepare_env {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};

    my $variables = $args{openqa_variables} ? $args{openqa_variables} : qesap_get_variables();
    my $provider_folder = lc $args{provider};
    my %paths = qesap_get_file_paths();
    die "Missing mandatory deployment_dir from qesap_get_file_paths()" unless $paths{'deployment_dir'};
    die "Missing mandatory qesap_conf_trgt from qesap_get_file_paths()" unless $paths{'qesap_conf_trgt'};

    # Option to skip straight to configuration
    unless ($args{only_configure}) {
        die "Missing mandatory qesap_conf_src from qesap_get_file_paths()" unless $paths{'qesap_conf_src'};
        qesap_create_folder_tree();
        qesap_get_deployment_code();
        qesap_get_roles_code();
        qesap_pip_install();
        # for the moment run it only conditionally
        # to allow this test code also to work with older
        # qe-sap-deployment versions
        qesap_galaxy_install() if (script_run("test -e $paths{deployment_dir}/requirements.yml") == 0);

        record_info('QESAP yaml', 'Preparing yaml config file');
        assert_script_run('curl -v -fL ' . $paths{qesap_conf_src} . ' -o ' . $paths{qesap_conf_trgt});
    }

    qesap_yaml_replace(openqa_variables => $variables);
    push(@log_files, $paths{qesap_conf_trgt});

    record_info('QESAP conf', 'Generating all terraform and Ansible configuration files');
    my $terraform_tfvars = join('/', qesap_get_terraform_dir(provider => $args{provider}), 'terraform.tfvars');
    push(@log_files, $terraform_tfvars);
    my $hana_media = "$paths{deployment_dir}/ansible/playbooks/vars/hana_media.yaml";
    my $hana_vars = "$paths{deployment_dir}/ansible/playbooks/vars/hana_vars.yaml";
    my @exec_rc = qesap_execute(cmd => 'configure', verbose => 1);

    if ($args{provider} eq 'EC2') {
        my $data = get_credentials('aws.json');
        qesap_create_aws_config();
        qesap_create_aws_credentials($data->{access_key_id}, $data->{secret_access_key});
    }

    push(@log_files, $hana_media) if (script_run("test -e $hana_media") == 0);
    push(@log_files, $hana_vars) if (script_run("test -e $hana_vars") == 0);
    qesap_upload_logs(failok => 1);
    die("Qesap deployment returned non zero value during 'configure' phase.") if $exec_rc[0];
    return;
}

=head3 qesap_ansible_get_playbook

    Download the playbook from the test code repo
    that is on the worker within the running JompHost.

=cut

sub qesap_ansible_get_playbook {
    my (%args) = @_;
    croak 'Missing mandatory playbook argument' unless $args{playbook};
    if (script_run("test -e $args{playbook}")) {
        my $cmd = join(' ',
            'curl', '-v', '-fL',
            data_url("sles4sap/$args{playbook}"),
            '-o', $args{playbook});
        assert_script_run($cmd);
    }
}

=head3 qesap_ansible_cmd

    Use Ansible to run a command remotely on some or all
    the hosts from the inventory.yaml

=over 8

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<FILTER> - filter hosts in the inventory

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<HOST_KEYS_CHECK> - if set, add some extra argument to the Ansible call
                           to allow contacting hosts not in the  KnownHost list yet.
                           This enables the use of this api before the call to qesap.py ansible

=item B<TIMEOUT> - default 90 secs

=item B<VERBOSE> - enable verbosity, default is OFF

=back
=cut

sub qesap_ansible_cmd {
    my (%args) = @_;
    foreach (qw(provider cmd)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} ||= 'cloudadmin';
    $args{filter} ||= 'all';
    $args{failok} //= 0;
    my $verbose = $args{verbose} ? ' -vvvv' : '';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    record_info('Ansible cmd:', "Remote run on '$args{filter}' node\ncmd: '$args{cmd}'");

    my $ansible_cmd = join(' ',
        'ansible' . $verbose,
        $args{filter},
        '-i', $inventory,
        '-u', $args{user},
        '-b', '--become-user=root',
        '-a', "\"$args{cmd}\"");

    $ansible_cmd = $args{host_keys_check} ?
      join(' ', $ansible_cmd, "-e 'ansible_ssh_common_args=\"-o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new\"'") :
      $ansible_cmd;

    qesap_venv_cmd_exec(cmd => $ansible_cmd, timeout => $args{timeout}, failok => $args{failok});
}

=head3 qesap_ansible_script_output_file

    Use Ansible to run a command remotely and get the stdout.
    Command could be executed with elevated privileges

    qesap_ansible_script_output_file(cmd => 'crm status', provider => 'aws', host => 'vmhana01', root => 1);

    It uses playbook data/sles4sap/script_output.yaml

    1. ansible-playbook runs the playbook
    2. the playbook executes the command remotely and redirects the output to file, both remotely
    3. qesap_ansible_fetch_file downloads the file locally
    4. the file is read and stored to be returned to the caller

    Return is the local full path of the file containing the output of the
    remotely executed command.

=over 10

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<HOST> - filter hosts in the inventory

=item B<FILE> - result file name

=item B<OUT_PATH> - path to save result file locally (without file name)

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<TIMEOUT> - max expected execution time, default 180sec.
    Same timeout is used both for the execution of script_output.yaml and for the fetch_file.
    Timeout of the same amount is started two times.

=item B<REMOTE_PATH> - Path to save file in the remote (without file name)

=back
=cut

sub qesap_ansible_script_output_file {
    my (%args) = @_;
    foreach (qw(provider cmd host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} ||= 'cloudadmin';
    $args{root} ||= 0;
    $args{failok} //= 0;
    $args{timeout} //= bmwqemu::scale_timeout(180);
    my $remote_path = $args{remote_path} // '/tmp/';
    my $out_path = $args{out_path} // '/tmp/ansible_script_output/';
    my $file = $args{file} // 'testout.txt';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $playbook = 'script_output.yaml';
    qesap_ansible_get_playbook(playbook => $playbook);

    my @ansible_cmd = ('ansible-playbook', '-vvvv', $playbook);
    push @ansible_cmd, ('-l', $args{host}, '-i', $inventory, '-u', $args{user});
    push @ansible_cmd, ('-b', '--become-user', 'root') if ($args{root});
    push @ansible_cmd, ('-e', qq("cmd='$args{cmd}'"),
        '-e', "out_file='$file'", '-e', "remote_path='$remote_path'");
    push @ansible_cmd, ('-e', "failok=yes") if ($args{failok});

    # ignore the return value for the moment
    qesap_venv_cmd_exec(cmd => join(' ', @ansible_cmd), failok => $args{failok}, timeout => $args{timeout});

    # Grab the file from the remote
    return qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        user => $args{user},
        root => $args{root},
        remote_path => $remote_path,
        out_path => $out_path,
        file => $file,
        timeout => $args{timeout});
}

=head3 qesap_ansible_script_output

    Return the output of a command executed on the remote machine via Ansible.

=over 9

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<HOST> - filter hosts in the inventory

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<TIMEOUT> - max expected execution time

=item B<FILE> - result file name

=item B<OUT_PATH> - path to save result file locally (without file name)

=item B<REMOTE_PATH> - Path to save file in the remote (without file name)

=back
=cut

sub qesap_ansible_script_output {
    my (%args) = @_;
    foreach (qw(provider cmd host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} ||= 'cloudadmin';
    $args{root} ||= 0;
    $args{failok} //= 0;
    my $path = $args{remote_path} // '/tmp/';
    my $out_path = $args{out_path} // '/tmp/ansible_script_output/';
    my $file = $args{file} // 'testout.txt';

    # Grab command output as file
    my $local_tmp = qesap_ansible_script_output_file(cmd => $args{cmd},
        provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        user => $args{user},
        root => $args{root},
        remote_path => $path,
        out_path => $out_path,
        file => $file,
        timeout => $args{timeout});
    # Print output and delete output file
    my $output = script_output("cat $local_tmp");
    enter_cmd "rm $local_tmp || echo 'Nothing to delete'";
    return $output;
}

=head3 qesap_ansible_fetch_file

    Use Ansible to fetch a file from remote.
    Command could be executed with elevated privileges

    qesap_ansible_fetch_file(provider => 'aws', host => 'vmhana01', root => 1);

    It uses playbook data/sles4sap/fetch_file.yaml

    1. ansible-playbook run the playbook
    3. the playbook download the file locally
    4. the file is read and stored to be returned to the caller

    Return the local path of the downloaded file.

=over 8

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<HOST> - filter hosts in the inventory

=item B<REMOTE_PATH> - path to find file in the remote (without file name)

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<TIMEOUT> - max expected execution time, default 180sec

=item B<FILE> - file name of the local copy of the file

=item B<OUT_PATH> - path to save file locally (without file name)

=back
=cut

sub qesap_ansible_fetch_file {
    my (%args) = @_;
    foreach (qw(provider host remote_path)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} ||= 'cloudadmin';
    $args{root} ||= 0;
    $args{failok} //= 0;
    $args{timeout} //= bmwqemu::scale_timeout(180);
    my $local_path = $args{out_path} // '/tmp/ansible_script_output/';
    my $local_file = $args{file} // 'testout.txt';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $fetch_playbook = 'fetch_file.yaml';

    # reflect the same logic implement in the playbook
    my $local_tmp = $local_path . $local_file;

    qesap_ansible_get_playbook(playbook => $fetch_playbook);

    my @ansible_fetch_cmd = ('ansible-playbook', '-vvvv', $fetch_playbook);
    push @ansible_fetch_cmd, ('-l', $args{host}, '-i', $inventory);
    push @ansible_fetch_cmd, ('-u', $args{user});
    push @ansible_fetch_cmd, ('-b', '--become-user', 'root') if ($args{root});
    push @ansible_fetch_cmd, ('-e', "local_path='$local_path'",
        '-e', "remote_path='$args{remote_path}'",
        '-e', "file='$local_file'");
    push @ansible_fetch_cmd, ('-e', "failok=yes") if ($args{failok});

    qesap_venv_cmd_exec(cmd => join(' ', @ansible_fetch_cmd),
        failok => $args{failok},
        timeout => $args{timeout});
    return $local_tmp;
}

=head3 qesap_create_aws_credentials

    Creates a AWS credentials file as required by QE-SAP Terraform deployment code.
=cut

sub qesap_create_aws_credentials {
    my ($key, $secret) = @_;
    my %paths = qesap_get_file_paths();
    my $credfile = script_output q|awk -F ' ' '/aws_credentials/ {print $2}' | . $paths{qesap_conf_trgt};
    save_tmp_file('credentials', "[default]\naws_access_key_id = $key\naws_secret_access_key = $secret\n");
    assert_script_run 'mkdir -p ~/.aws';
    assert_script_run 'curl ' . autoinst_url . "/files/credentials -o $credfile";
    assert_script_run "cp $credfile ~/.aws/credentials";
}

=head3 qesap_create_aws_config

    Creates a AWS configuration file in ~/.aws
    as required by the QE-SAP Terraform & Ansible deployment code.
=cut

sub qesap_create_aws_config {
    my %paths = qesap_get_file_paths();
    my $region = script_output q|awk -F ' ' '/aws_region/ {print $2}' | . $paths{qesap_conf_trgt};
    $region = get_required_var('PUBLIC_CLOUD_REGION') if ($region =~ /^["']?%.+%["']?$/);
    $region =~ s/[\"\']//g;
    save_tmp_file('config', "[default]\nregion = $region\n");
    assert_script_run 'mkdir -p ~/.aws';
    assert_script_run 'curl ' . autoinst_url . "/files/config -o ~/.aws/config";
}

=head3 qesap_remote_hana_public_ips

    Return a list of the public IP addresses of the systems
    deployed by qe-sap-deployment, as reported by C<terraform output>.
    Needs to run after C<qesap_execute(cmd => 'terraform');> call.

=cut

sub qesap_remote_hana_public_ips {
    my $tfdir = qesap_get_terraform_dir(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $data = decode_json(script_output "terraform -chdir=$tfdir output -json");
    return @{$data->{hana_public_ip}->{value}};
}

=head3 qesap_wait_for_ssh

  Probe specified port on the remote host each 5sec till response.
  Return -1 in case of timeout
  Return total time of retry loop in case of pass.

=over 3

=item B<HOST> - IP of the host to probe

=item B<TIMEOUT> - time to wait before to give up, default is 10mins

=item B<PORT> - port to probe, default is 22

=back
=cut

sub qesap_wait_for_ssh {
    my (%args) = @_;
    croak 'Missing mandatory host argument' unless $args{host};
    $args{timeout} //= bmwqemu::scale_timeout(600);
    $args{port} ||= 22;

    my $start_time = time();
    my $check_port = 1;

    # Looping until reaching timeout or passing two conditions :
    # - SSH port 22 is reachable
    # - journalctl got message about reaching one of certain targets
    while ((my $duration = time() - $start_time) < $args{timeout}) {
        return $duration if (script_run(join(' ', 'nc', '-vz', '-w', '1', $args{host}, $args{port}), quiet => 1) == 0);
        sleep 5;
    }

    return -1;
}

=head3 qesap_upload_crm_report

    Run crm report on a host and upload the resulting tarball to openqa

=over 3

=item B<HOST> - host to get the report from

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<FAILOK> - if not set, Ansible failure result in die

=back
=cut

sub qesap_upload_crm_report {
    my (%args) = @_;
    foreach (qw(provider host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{failok} //= 0;

    my $crm_log = "/var/log/$args{host}-crm_report";
    my $report_opt = !is_sle('12-sp4+') ? '-f0' : '';
    qesap_ansible_cmd(cmd => "crm report $report_opt -E /var/log/ha-cluster-bootstrap.log $crm_log",
        provider => $args{provider},
        filter => $args{host},
        host_keys_check => 1,
        verbose => 1,
        failok => $args{failok});
    my $local_path = qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        root => 1,
        remote_path => '/var/log/',
        out_path => '/tmp/ansible_script_output/',
        file => "$args{host}-crm_report.tar.gz");
    upload_logs($local_path, failok => 1);
}

=head3 qesap_cluster_log_cmds

  List of commands to collect logs from a deployed cluster

=cut

sub qesap_cluster_log_cmds {
    # many logs does not need to be in this list as collected with `crm report`.
    # Some of them that are there are: `crm status`, `crm configure show`,
    # `journalctl -b`, `systemctl status sbd`, `corosync.conf` and `csync2`
    my @log_list = (
        {
            Cmd => 'lsblk -i -a',
            Output => 'lsblk.txt',
        },
        {
            Cmd => 'lsscsi -i',
            Output => 'lsscsi.txt',
        },
        {
            Cmd => 'cat /var/tmp/hdbinst.log',
            Output => 'hdbinst.log.txt',
        },
        {
            Cmd => 'cat /var/tmp/hdblcm.log',
            Output => 'hdblcm.log.txt',
        },
    );
    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        push @log_list, {
            Cmd => 'cat ~/.aws/config > aws_config.txt',
            Output => 'aws_config.txt',
        };
    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        push @log_list, {
            Cmd => 'cat /var/log/cloud-init.log > azure_cloud_init_log.txt',
            Output => 'azure_cloud_init_log.txt',
        };
    }
    return @log_list;
}

=head3 qesap_cluster_logs

  Collect logs from a deployed cluster

=cut

sub qesap_cluster_logs {
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $inventory = qesap_get_inventory(provider => $provider);
    if (script_run("test -e $inventory") == 0)
    {
        foreach my $host ('vmhana01', 'vmhana02') {
            foreach my $cmd (qesap_cluster_log_cmds()) {
                my $out = qesap_ansible_script_output_file(cmd => $cmd->{Cmd},
                    provider => $provider,
                    host => $host,
                    failok => 1,
                    root => 1,
                    path => '/tmp/',
                    out_path => '/tmp/ansible_script_output/',
                    file => "$host-$cmd->{Output}");
                upload_logs($out, failok => 1);
            }
            # Upload crm report
            qesap_upload_crm_report(host => $host, provider => $provider, failok => 1);
        }
    }
}

=head3 qesap_az_get_vnet

Return the output of az network vnet list

=over 1

=item B<RESOURCE_GROUP> - resource group name to query

=back
=cut

sub qesap_az_get_vnet {
    my ($resource_group) = @_;
    croak 'Missing mandatory resource_group argument' unless $resource_group;

    my $cmd = join(' ', 'az network',
        'vnet list',
        '-g', $resource_group,
        '--query "[0].name"',
        '-o tsv');
    return script_output($cmd, 180);
}

=head3 qesap_calculate_deployment_name

Compose the deployment name. It always has the JobId

=over 1

=item B<PREFIX> - optional substring prepend in front of the job id

=back
=cut

sub qesap_calculate_deployment_name {
    my ($prefix) = @_;
    my $id = get_current_job_id();
    return $prefix ? $prefix . $id : $id;
}

=head3 qesap_az_get_resource_group

Query and return the resource group used
by the qe-sap-deployment

=over 1

=item B<SUBSTRING> - optional substring to be used with additional grep at the end of the command

=back
=cut

sub qesap_az_get_resource_group {
    my (%args) = @_;
    my $substring = $args{substring} ? " | grep $args{substring}" : "";
    my $job_id = get_var('QESAP_DEPLOYMENT_IMPORT', get_current_job_id());    # in case existing deployment is used
    my $result = script_output("az group list --query \"[].name\" -o tsv | grep $job_id" . $substring, proceed_on_failure => 1);
    record_info('QESAP RG', "result:$result");
    return $result;
}

=head3 qesap_az_calculate_address_range

Calculate the vnet and subnet address
ranges. The format is 10.ip2.ip3.0/21 and
 /24 respectively. ip2 and ip3 are calculated
 using the slot number as seed.

=over 1

=item B<SLOT> - integer to be used as seed in calculating addresses

=back

=cut

sub qesap_az_calculate_address_range {
    my %args = @_;
    croak 'Missing mandatory slot argument' unless $args{slot};
    die "Invalid 'slot' argument - valid values are 1-8192" if ($args{slot} > 8192 || $args{slot} < 1);
    my $offset = ($args{slot} - 1) * 8;

    # addresses are of the form 10.ip2.ip3.0/21 and /24 respectively
    #ip2 gets incremented when it is >=256
    my $ip2 = int($offset / 256);
    #ip3 gets incremented by 8 until it's >=256, then it resets
    my $ip3 = $offset % 256;

    return (
        vnet_address_range => sprintf("10.%d.%d.0/21", $ip2, $ip3),
        subnet_address_range => sprintf("10.%d.%d.0/24", $ip2, $ip3),
    );
}

=head3 qesap_az_vnet_peering

    Create a pair of network peering between
    the two provided deployments.

=over 3

=item B<SOURCE_GROUP> - resource group of source

=item B<TARGET_GROUP> - resource group of target

=item B<TIMEOUT> - default is 5 mins

=back
=cut

sub qesap_az_vnet_peering {
    my (%args) = @_;
    foreach (qw(source_group target_group)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $source_vnet = qesap_az_get_vnet($args{source_group});
    my $target_vnet = qesap_az_get_vnet($args{target_group});
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my $vnet_show_cmd = 'az network vnet show --query id --output tsv';

    my $source_vnet_id = script_output("$vnet_show_cmd --resource-group $args{source_group} --name $source_vnet");
    record_info("[M] source vnet ID: $source_vnet_id\n");

    my $target_vnet_id = script_output("$vnet_show_cmd --resource-group $args{target_group} --name $target_vnet");
    record_info("[M] target vnet ID: $target_vnet_id\n");

    my $peering_name = "$source_vnet-$target_vnet";
    my $peering_cmd = "az network vnet peering create --name $peering_name --allow-vnet-access --output table";

    assert_script_run("$peering_cmd --resource-group $args{source_group} --vnet-name $source_vnet --remote-vnet $target_vnet_id", timeout => $args{timeout});
    record_info('PEERING SUCCESS (source)', "[M] Peering from $args{source_group}.$source_vnet server was successful\n");

    assert_script_run("$peering_cmd --resource-group $args{target_group} --vnet-name $target_vnet --remote-vnet $source_vnet_id", timeout => $args{timeout});
    record_info('PEERING SUCCESS (target)', "[M] Peering from $args{target_group}.$target_vnet server was successful\n");

    record_info('Checking peering status');
    assert_script_run("az network vnet peering show --name $peering_name --resource-group $args{target_group} --vnet-name $target_vnet --output table");
    record_info('AZURE PEERING SUCCESS');
}

=head3 qesap_az_simple_peering_delete

    Delete a single peering one way

=over 3

=item B<RG> - Name of the resource group

=item B<VNET_NAME> - Name of the vnet

=item B<PEERING_NAME> - Name of the peering

=item B<TIMEOUT> - (Optional) Timeout for the script_run command

=back
=cut

sub qesap_az_simple_peering_delete {
    my (%args) = @_;
    foreach (qw(rg vnet_name peering_name)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{timeout} //= bmwqemu::scale_timeout(300);
    my $peering_cmd = "az network vnet peering delete -n $args{peering_name} --resource-group $args{rg} --vnet-name $args{vnet_name}";
    return script_run($peering_cmd, timeout => $args{timeout});
}

=head3 qesap_az_vnet_peering_delete

    Delete all the network peering between the two provided deployments.

=over 3

=item B<SOURCE_GROUP> - resource group of source.
                        This parameter is optional, if not provided
                        the related peering will be ignored.

=item B<TARGET_GROUP> - resource group of target.
                        This parameter is mandatory and
                        the associated resource group is supposed to still exist.

=item B<TIMEOUT> - default is 5 mins

=back
=cut

sub qesap_az_vnet_peering_delete {
    my (%args) = @_;
    croak 'Missing mandatory target_group argument' unless $args{target_group};
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my $target_vnet = qesap_az_get_vnet($args{target_group});

    my $peering_name = qesap_az_get_peering_name(resource_group => $args{target_group});
    if (!$peering_name) {
        record_info('NO PEERING', "No peering between $args{target_group} and resources belonging to the current job to be destroyed!");
        return;
    }

    record_info('Attempting peering destruction');
    my $source_ret = 0;
    record_info('Destroying job_resources->IBSM peering');
    if ($args{source_group}) {
        my $source_vnet = qesap_az_get_vnet($args{source_group});
        $source_ret = qesap_az_simple_peering_delete(rg => $args{source_group}, vnet_name => $source_vnet, peering_name => $peering_name, timeout => $args{timeout});
    }
    else {
        record_info('NO PEERING', "No peering between job VMs and IBSM - maybe it wasn't created, or the resources have been destroyed.");
    }
    record_info('Destroying IBSM -> job_resources peering');
    my $target_ret = qesap_az_simple_peering_delete(rg => $args{target_group}, vnet_name => $target_vnet, peering_name => $peering_name, timeout => $args{timeout});

    if ($source_ret == 0 && $target_ret == 0) {
        record_info('Peering deletion SUCCESS', 'The peering was successfully destroyed');
        return;
    }
    record_soft_failure("Peering destruction FAIL: There may be leftover peering connections, please check - jsc#7487");
}

=head3 qesap_az_get_peering_name

    Search for all network peering related to both:
     - resource group related to the current job
     - the provided resource group.
    Returns the peering name or
    empty string if a peering doesn't exist

=over 1

=item B<RESOURCE_GROUP> - resource group connected to the peering

=back
=cut

sub qesap_az_get_peering_name {
    my (%args) = @_;
    croak 'Missing mandatory target_group argument' unless $args{resource_group};

    my $job_id = get_current_job_id();
    my $cmd = join(' ', 'az network vnet peering list',
        '-g', $args{resource_group},
        '--vnet-name', qesap_az_get_vnet($args{resource_group}),
        '--query "[].name"',
        '-o tsv',
        '| grep', $job_id);
    return script_output($cmd, proceed_on_failure => 1);
}

=head3 qesap_aws_get_region_subnets

Return a list of subnets. Return a single subnet for each region.

=over 1

=item B<VPC_ID> - VPC ID of resource to filter list of subnets

=back
=cut

sub qesap_aws_get_region_subnets {
    my (%args) = @_;
    croak 'Missing mandatory vpc_id argument' unless $args{vpc_id};

    # Get the VPC tag Workspace
    my $cmd = join(' ', 'aws ec2 describe-subnets',
        '--filters', "\"Name=vpc-id,Values=$args{vpc_id}\"",
        '--query "Subnets[].{AZ:AvailabilityZone,SI:SubnetId}"',
        '--output json');

    my $describe_vpcs = decode_json(script_output($cmd));
    my %seen = ();
    my @uniq = ();
    foreach (@{$describe_vpcs}) {
        push(@uniq, $_->{SI}) unless $seen{$_->{AZ}}++;
    }
    return @uniq;
}

=head3 qesap_aws_get_vpc_id

    Get the vpc_id of a given instance in the cluster.
    This function looks for the cluster using the aws describe-instances
    and filtering by terraform deployment_name value, that qe-sap-deployment
    is kind to use as tag for each resource.

=cut

=over 1

=item B<RESOURCE_GROUP> - resource group name to query

=back
=cut

sub qesap_aws_get_vpc_id {
    my (%args) = @_;
    croak 'Missing mandatory resource_group argument' unless $args{resource_group};

    my $cmd = join(' ', 'aws ec2 describe-instances',
        '--region', get_required_var('PUBLIC_CLOUD_REGION'),
        '--filters',
        '"Name=tag-key,Values=Workspace"',
        "\"Name=tag-value,Values=$args{resource_group}\"",
        '--query',
        "'Reservations[0].Instances[0].VpcId'",    # the two 0 index result in select only the vpc of vmhana01 that is always equal to the one used by vmhana02
        '--output text');
    return script_output($cmd);
}

=head3 qesap_aws_get_transit_gateway_vpc_attachment
    Ged a description of one or more transit-gateway-attachments
    Function support optional arguments that are translated to filters:
     - transit_gateway_attach_id
     - name

    Example:
      qesap_aws_get_transit_gateway_vpc_attachment(name => 'SOMETHING')

      Result internally in aws cli to be called like

      aws ec2 describe-transit-gateway-attachments --filter='Name=tag:Name,Values=SOMETHING

    Only one filter mode is supported at any time.

    Returns a HASH reference to the decoded JSON returned by the AWS command or undef on failure.
=cut

sub qesap_aws_get_transit_gateway_vpc_attachment {
    my (%args) = @_;
    my $filter = '';
    if ($args{transit_gateway_attach_id}) {
        $filter = "--filter='Name=transit-gateway-attachment-id,Values=$args{transit_gateway_attach_id}'";
    }
    elsif ($args{name}) {
        $filter = "--filter='Name=tag:Name,Values=$args{name}'";
    }
    my $cmd = join(' ', 'aws ec2 describe-transit-gateway-attachments',
        $filter,
        '--query "TransitGatewayAttachments[]"');
    return decode_json(script_output($cmd));
}

=head3 qesap_aws_create_transit_gateway_vpc_attachment

    Call create-transit-gateway-vpc-attachment and
    wait until Transit Gateway Attachment is available.

    Return 1 (true) if properly managed to create the transit-gateway-vpc-attachment
    Return 0 (false) if create-transit-gateway-vpc-attachment fails or the gateway does not become active before the timeout

=over 5

=item B<TRANSIT_GATEWAY_ID> - ID of the target Transit gateway (IBS Mirror)

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=item B<SUBNET_ID_LIST> - List of subnet to connect (SUT HANA cluster)

=item B<NAME> - Prefix for the Tag Name of transit-gateway-vpc-attachment

=item B<TIMEOUT> - default is 5 mins

=back
=cut

sub qesap_aws_create_transit_gateway_vpc_attachment {
    my (%args) = @_;
    foreach (qw(transit_gateway_id vpc_id subnet_id_list name)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my $cmd = join(' ', 'aws ec2 create-transit-gateway-vpc-attachment',
        '--transit-gateway-id', $args{transit_gateway_id},
        '--vpc-id', $args{vpc_id},
        '--subnet-ids', join(' ', @{$args{subnet_id_list}}),
        '--tag-specifications',
        '"ResourceType=transit-gateway-attachment,Tags=[{Key=Name,Value=' . $args{name} . '-tga}]"',
        '--output json');
    my $describe_tgva = decode_json(script_output($cmd));
    return 0 unless $describe_tgva;

    my $transit_gateway_attachment_id = $describe_tgva->{TransitGatewayVpcAttachment}->{TransitGatewayAttachmentId};
    my $res;
    my $state = 'none';
    my $duration;
    my $start_time = time();
    while ((($duration = time() - $start_time) < $args{timeout}) && ($state !~ m/available/)) {
        sleep 5;
        $res = qesap_aws_get_transit_gateway_vpc_attachment(
            transit_gateway_attach_id => $transit_gateway_attachment_id);
        $state = $res->[0]->{State};
    }
    return $duration < $args{timeout};
}

=head3 qesap_aws_delete_transit_gateway_vpc_attachment

    Call delete-transit-gateway-vpc-attachment and
    wait until Transit Gateway Attachment is deleted.

    Return 1 (true) if properly managed to delete the transit-gateway-vpc-attachment
    Return 0 (false) if delete-transit-gateway-vpc-attachment fails or the gateway does not become inactive before the timeout

=over 2

=item B<NAME> - Prefix for the Tag Name of transit-gateway-vpc-attachment

=item B<TIMEOUT> - default is 5 mins

=back
=cut

sub qesap_aws_delete_transit_gateway_vpc_attachment {
    my (%args) = @_;
    croak 'Missing mandatory name argument' unless $args{name};
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my $res = qesap_aws_get_transit_gateway_vpc_attachment(
        name => $args{name});
    # Here [0] suppose that only one of them match 'name'
    my $transit_gateway_attachment_id = $res->[0]->{TransitGatewayAttachmentId};
    return 0 unless $transit_gateway_attachment_id;

    my $cmd = join(' ', 'aws ec2 delete-transit-gateway-vpc-attachment',
        '--transit-gateway-attachment-id', $transit_gateway_attachment_id);
    script_run($cmd);

    my $state = 'none';
    my $duration;
    my $start_time = time();
    while ((($duration = time() - $start_time) < $args{timeout}) && ($state !~ m/deleted/)) {
        sleep 5;
        $res = qesap_aws_get_transit_gateway_vpc_attachment(
            transit_gateway_attach_id => $transit_gateway_attachment_id);
        $state = $res->[0]->{State};
    }
    return $duration < $args{timeout};
}

=head3 qesap_aws_add_route_to_tgw
    Adding the route to the transit gateway to the routing table in refhost VPC

=over 3

=item B<RTABLE_ID> - Routing table ID

=item B<TARGET_IP_NET> - Target IP network to be added to the Routing table eg. 192.168.11.0/16

=item B<TRANSIT_GATEWAY_ID> - ID of the target Transit gateway (IBS Mirror)

=back
=cut

sub qesap_aws_add_route_to_tgw {
    my (%args) = @_;
    foreach (qw(rtable_id target_ip_net trans_gw_id)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $cmd = join(' ',
        'aws ec2 create-route',
        '--route-table-id', $args{rtable_id},
        '--destination-cidr-block', $args{target_ip_net},
        '--transit-gateway-id', $args{trans_gw_id},
        '--output text');
    script_run($cmd);
}

=head3 qesap_aws_filter_query

    Generic function to compose a aws cli command with:
      - `aws ec2` something
      - use both `filter` and `query`
      - has text output

=cut

sub qesap_aws_filter_query {
    my (%args) = @_;
    foreach (qw(cmd filter query)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $cmd = join(' ', 'aws ec2', $args{cmd},
        '--filters', $args{filter},
        '--query', $args{query},
        '--output text');
    return script_output($cmd);
}

=head3 qesap_aws_get_mirror_tg

    Return the Transient Gateway ID of the IBS Mirror

=cut

sub qesap_aws_get_mirror_tg {
    return qesap_aws_filter_query(
        cmd => 'describe-transit-gateways',
        filter => '"Name=tag-key,Values=Project" "Name=tag-value,Values=IBS Mirror"',
        query => '"TransitGateways[].TransitGatewayId"'
    );
}

=head3 qesap_aws_get_vpc_workspace

    Get the VPC tag Workspace

=over 1

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=back
=cut

sub qesap_aws_get_vpc_workspace {
    my (%args) = @_;
    croak 'Missing mandatory vpc_id argument' unless $args{vpc_id};

    return qesap_aws_filter_query(
        cmd => 'describe-vpcs',
        filter => "\"Name=vpc-id,Values=$args{vpc_id}\"",
        query => '"Vpcs[*].Tags[?Key==\`Workspace\`].Value"'
    );
}

=head3 qesap_aws_get_routing

    Get the Routing table: searching Routing Table with external connection
    and get the Workspace tag

=over 1

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=back
=cut

sub qesap_aws_get_routing {
    my (%args) = @_;
    croak 'Missing mandatory vpc_id argument' unless $args{vpc_id};

    return qesap_aws_filter_query(
        cmd => 'describe-route-tables',
        filter => "\"Name=vpc-id,Values=$args{vpc_id}\"",
        query => '"RouteTables[?Routes[?GatewayId!=\`local\`]].RouteTableId"'
    );
}

=head3 qesap_aws_vnet_peering

    Create a pair of network peering between
    the two provided deployments.

    Return 1 (true) if the overall peering procedure completes successfully

=over 2

=item B<TARGET_IP> - Target IP network to be added to the Routing table eg. 192.168.11.0/16

=item B<VPC_ID> - VPC ID of resource to be attached (SUT HANA cluster)

=back
=cut

sub qesap_aws_vnet_peering {
    my (%args) = @_;
    foreach (qw(target_ip vpc_id)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $trans_gw_id = qesap_aws_get_mirror_tg();
    unless ($trans_gw_id) {
        record_info('AWS PEERING', 'Empty trans_gw_id');
        return 0;
    }

    # For qe-sap-deployment this one match or contain the Terraform deloyment_name
    my $vpc_tag_name = qesap_aws_get_vpc_workspace(vpc_id => $args{vpc_id});
    unless ($vpc_tag_name) {
        record_info('AWS PEERING', 'Empty vpc_tag_name');
        return 0;
    }

    my @vpc_subnets_list = qesap_aws_get_region_subnets(vpc_id => $args{vpc_id});
    unless (@vpc_subnets_list) {
        record_info('AWS PEERING', 'Empty vpc_subnets_list');
        return 0;
    }

    my $rtable_id = qesap_aws_get_routing(vpc_id => $args{vpc_id});
    unless ($rtable_id) {
        record_info('AWS PEERING', 'Empty rtable_id');
        return 0;
    }

    # Setting up the peering
    # Attaching the VPC to the Transit Gateway
    my $attach = qesap_aws_create_transit_gateway_vpc_attachment(
        transit_gateway_id => $trans_gw_id,
        vpc_id => $args{vpc_id},
        subnet_id_list => \@vpc_subnets_list,
        name => $vpc_tag_name);
    unless ($attach) {
        record_info('AWS PEERING', 'VPC attach failure');
        return 0;
    }

    qesap_aws_add_route_to_tgw(
        rtable_id => $rtable_id,
        target_ip_net => $args{target_ip},
        trans_gw_id => $trans_gw_id);

    record_info('AWS PEERING SUCCESS');
    return 1;
}

=head3 qesap_add_server_to_hosts

    Adds a 'ip -> name' pair in the end of /etc/hosts in the hosts

=over 2

=item B<IP> - ip of server to add to hosts

=item B<NAME> - name of server to add to hosts

=back
=cut

sub qesap_add_server_to_hosts {
    my (%args) = @_;
    foreach (qw(ip name)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(cmd => "sed -i '\\\$a $args{ip} $args{name}' /etc/hosts",
        provider => $provider,
        host_keys_check => 1,
        verbose => 1);
    qesap_ansible_cmd(cmd => "cat /etc/hosts",
        provider => $provider,
        verbose => 1);
}

=head3 qesap_import_instances

    Downloads assets required for re-using infrastructure from previously exported test.
    qesap_import_instances(<$test_id>)

=over 1

=item B<$test_id> - OpenQA test ID from a test previously run with "QESAP_DEPLOYMENT_IMPORT=1" and infrastructure still being up and running

=back
=cut

sub qesap_import_instances {
    my ($test_id) = @_;
    die("OpenQA test ID must be a number. Parameter 'QESAP_DEPLOYMENT_IMPORT' must contain ID of previously exported test")
      unless looks_like_number($test_id);

    my $inventory_file = qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my %files = ('id_rsa' => '/root/.ssh/',
        'id_rsa.pub' => '/root/.ssh/',
        basename($inventory_file) => dirname($inventory_file) . '/');
    my $test_url = join('', 'http://', get_required_var('OPENQA_URL'), '/tests/', $test_id);

    assert_script_run('mkdir -m700 /root/.ssh');
    assert_script_run('mkdir -p ' . dirname($inventory_file));

    foreach my $key (keys %files) {
        assert_script_run(join(' ', 'curl -v -fL', $test_url . '/file/' . $key, '-o', $files{$key} . $key),
            fail_message => "Failed to download file log data '$key' from test '$test_url'");
        record_info('IMPORT', "File '$key' imported from test '$test_url'");
    }
    assert_script_run('chmod -R 600 /root/.ssh/');
}

=head3 qesap_export_instances

    Downloads assets required for re-using infrastructure from previously exported test.
    qesap_export_instances()

=cut

sub qesap_export_instances {
    my @upload_files = (
        qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER')),
        '/root/.ssh/id_rsa',
        '/root/.ssh/id_rsa.pub');

    upload_logs($_, log_name => basename($_)) for @upload_files;
    record_info('EXPORT', "SSH keys and instances data uploaded to test results:\n" . join("\n", @upload_files));
}

=head3 qesap_is_job_finished

    Get whether a specified job is still running or not. 
    In cases of ambiguous responses, they are considered to be in `running` state.

=over 1

=item B<JOB_ID> - id of job to check

=back
=cut

sub qesap_is_job_finished {
    my ($job_id) = @_;
    my $url = get_required_var('OPENQA_HOSTNAME') . "/api/v1/jobs/$job_id";
    my $json_data = script_output("curl -s '$url'");

    my $job_data = eval { decode_json($json_data) };
    if ($@) {
        record_info("JSON error", "Failed to decode JSON data for job $job_id: $@");
        return 0;    # Assume job is still running if we can't get its state
    }

    my $job_state = $job_data->{job}->{state} // 'running';    # assume job is running if unable to get status

    return ($job_state ne 'running');
}


=head3 qesap_az_get_active_peerings

    Get active peerings for Azure jobs

=over 2

=item B<RG> - Resource group in question

=item B<VNET> - vnet name of rg

=back
=cut

sub qesap_az_get_active_peerings {
    my (%args) = @_;
    foreach (qw(rg vnet)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $cmd = "az network vnet peering list -g $args{rg} --vnet-name $args{vnet} --output tsv --query \"[].name\"";
    my $output_str = script_output($cmd);
    my @output = split(/\n/, $output_str);
    my %result;

    foreach my $line (@output) {
        # find integers in the vnet name that are 6 digits or longer - this would be the job id
        my @matches = $line =~ /(\d{6,})/g;
        $result{$line} = $matches[-1] if @matches;
    }
    return %result;
}

=head2 qesap_az_clean_old_peerings

    Delete leftover peerings for Azure jobs that finished without cleaning up

=over 2

=item B<RG> - Resource group in question

=item B<VNET> - vnet name of rg

=back
=cut

sub qesap_az_clean_old_peerings {
    my (%args) = @_;
    foreach (qw(rg vnet)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my %peerings = qesap_az_get_active_peerings(rg => $args{rg}, vnet => $args{vnet});

    while (my ($key, $value) = each %peerings) {
        if (qesap_is_job_finished($value)) {
            record_info("Leftover Peering", "$key is leftover from a finished job. Attempting to delete...");
            qesap_az_simple_peering_delete(rg => $args{rg}, vnet_name => $args{vnet}, peering_name => $key);
        }
    }
}

=head2 qesap_az_setup_native_fencing_permissions

    qesap_az_setup_native_fencing_permissions(vmname=>$vm_name,
        subscription_id=>$subscription_id,
        resource_group=>$resource_group,
        role=>$role);

    Sets up managed identity (MSI) by enabling system assigned identity and
        role - role to be assigned
        resource_group - resource group resource belongs to
        subscription_id - valid azure subscription
=cut

sub qesap_az_setup_native_fencing_permissions {
    my (%args) = @_;
    foreach ('vm_name', 'subscription_id', 'resource_group') {
        croak "Missing argument: '$_'" unless defined($args{$_});
    }

    my $vm_name = $args{vm_name};
    my $subscription_id = $args{subscription_id};
    my $resource_group = $args{resource_group};
    my $role = 'Virtual Machine Contributor';

    my $vm_id = qesap_az_enable_system_assigned_identity($vm_name, $resource_group);
    qesap_az_assign_role(assignee => $vm_id, role => $role, subscription_id => $subscription_id, resource_group => $resource_group);
}

=head2 qesap_az_enable_system_assigned_identity

    qesap_az_enable_system_assigned_identity($vm_name, $resource_group);

    Enables 'System assigned identity' for specified VM.
    Returns 'systemAssignedIdentity' ID.

=cut

sub qesap_az_enable_system_assigned_identity {
    my ($vm_name, $resource_group) = @_;
    croak "Missing 'vm_name' or 'resource_group argument'" unless ($vm_name and $resource_group);

    my $az_cmd = "az vm identity assign";
    my $az_args = "--only-show-errors -g '$resource_group' -n '$vm_name' --query 'systemAssignedIdentity' -o tsv";
    my $identity_id = script_output(join(' ', $az_cmd, $az_args));
    croak 'Returned output does not match ID pattern' if qesap_az_validate_uuid_pattern($identity_id) eq 0;
    return $identity_id;
}

=head2 qesap_az_assign_role

    qesap_az_assign_role( assignee=>$assignee, role=>$role, subscription_id=>$subscription_id, resource_group=>$resource_group )

    Assigns defined role to 'assignee' (user, vm, etc...) using subscription id.
     assignee - UUID for the resource (VM in this case)
     role - role to be assigned
     resource_group - resource group resource belongs to
     subscription_id - valid azure subscription

=cut

sub qesap_az_assign_role {
    my (%args) = @_;
    foreach ('assignee', 'role', 'subscription_id', 'resource_group') {
        croak "Missing argument: '$_'" unless defined($args{$_});
    }

    my $assignee = $args{assignee};
    my $role = $args{role};
    my $subscription_id = $args{subscription_id};
    my $resource_group = $args{resource_group};
    my $az_cmd = "az role assignment create --only-show-errors";
    my $az_cm_args = "--assignee '$assignee' --role '$role' --scope '/subscriptions/$subscription_id/resourceGroups/$resource_group'";

    assert_script_run(join(" ", $az_cmd, $az_cm_args));
}

=head2 qesap_az_get_tenant_id

    qesap_az_get_tenant_id( subscription_id=>$subscription_id )

    Returns tenant ID related to the specified subscription ID.
    subscription_id - valid azure subscription

=cut

sub qesap_az_get_tenant_id {
    my ($subscription_id) = @_;
    croak 'Missing subscription ID argument' unless $subscription_id;
    my $az_cmd = "az account show --only-show-errors";
    my $az_cmd_args = "--subscription $subscription_id --query 'tenantId' -o tsv";
    my $tenant_id = script_output(join(' ', $az_cmd, $az_cmd_args));
    croak 'Returned output does not match ID pattern' if qesap_az_validate_uuid_pattern($tenant_id) eq 0;
    return $tenant_id;
}

=head2 qesap_az_validate_uuid_pattern

    qesap_az_validate_uuid_pattern( uuid_string=>$uuid_string )

    Function checks input string against uuid pattern which is commonly used as an identifier for azure resources.
    returns uuid (true) on match, 0 (false) on mismatch.

=cut

sub qesap_az_validate_uuid_pattern {
    my ($uuid_string) = @_;
    my $pattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
    return $uuid_string if ($uuid_string =~ /$pattern/);
    diag("String did not match UUID pattern:\nString: '$uuid_string'\nPattern: '$pattern'");
    return 0;
}

=head2 qesap_az_create_sas_token

Generate a SAS URI token for a storage container of choice

Return the token string

=over 5

=item B<STORAGE> - Storage account name used fur the --account-name argument in az commands

=item B<CONTAINER> - container name within the storage account

=item B<KEYNAME> - name of the access key within the storage account

=item B<PERMISSION> - access permissions. Syntax is what documented in 'az storage container generate-sas --help'.
                      Some of them of interest: (a)dd (c)reate (d)elete (e)xecute (l)ist (m)ove (r)ead (w)rite.
                      Default is 'r'

=item B<LIFETIME> - life time of the token in minutes, default is 10minute

=back
=cut

sub qesap_az_create_sas_token {
    my (%args) = @_;
    foreach (qw(storage container keyname)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{permission} //= 'r';
    $args{lifetime} //= 10;

    # Generated command is:
    #
    # az storage container generate-sas  --account-name <STOREGE_NAME> \
    #     --account-key $(az storage account keys list --account-name <STORAGE_NAME> --query "[?contains(keyName,'<KEY_NAME>')].value" -o tsv) \
    #     --name <CONTAINER_NAME> \
    #     --permissions r \
    #     --expiry $(date -u -d "10 minutes" '+%Y-%m-%dT%H:%MZ')
    my $account_name = "--account-name $args{storage}";
    my $cmd_keys = join(' ',
        'az storage account keys list',
        $account_name,
        '--query', "\"[?contains(keyName,'" . $args{keyname} . "')].value\"",
        '-o tsv'
    );
    my $cmd_expiry = join(' ', 'date', '-u', '-d', "\"$args{lifetime} minutes\"", "'+%Y-%m-%dT%H:%MZ'");
    my $cmd = join(' ',
        'az storage container generate-sas',
        $account_name,
        '--account-key', '$(', $cmd_keys, ')',
        '--name', $args{container},
        '--permission', $args{permission},
        '--expiry', '$(', $cmd_expiry, ')',
        '-o', 'tsv');
    record_info('GENERATE-SAS', $cmd);
    return script_output($cmd);
}

=head2 qesap_terraform_clean_up_retry

    qesap_terraform_clean_up_retry()

    Perform terraform destroy and catch and ignore any error.
    This method is mostly useful when doing cleanup before retry in case of
    Ansible failed on 'Timed out waiting for last boot time check'

=cut

sub qesap_terraform_clean_up_retry {
    my $command = 'terraform';

    # Do not do 'ansible' cleanup as if 'Timed out waiting for last boot time check' happened the SSH will be disconnected
    # E.g., ansible SSH reports '"msg": "Timeout (12s) waiting for privilege escalation prompt: "'
    # Terraform destroy can be executed in any case
    record_info('Cleanup', "Executing $command cleanup");
    my @clean_up_cmd_rc = qesap_execute(verbose => 1, cmd => $command, cmd_options => '-d', timeout => 1200);
    if ($clean_up_cmd_rc[0] == 0) {
        diag(ucfirst($command) . " cleanup attempt #  PASSED.");
        record_info("Clean $command", ucfirst($command) . ' cleanup PASSED.');
    }
    else {
        diag(ucfirst($command) . " cleanup attempt #  FAILED.");
        record_info('Cleanup FAILED', "Cleanup $command FAILED", result => 'fail');
    }
}

=head2 qesap_terrafom_ansible_deploy_retry

    qesap_terrafom_ansible_deploy_retry( error_log=>$error_log )
        error_log - ansible error log file name

    Retry to deploy terraform + ansible
    Return 0: we manage the failure properly
    Return 1: something went wrong or we do not know what to do with the failure

=cut

sub qesap_terrafom_ansible_deploy_retry {
    my (%args) = @_;
    croak 'Missing mandatory error_log argument' unless $args{error_log};
    my @ret;

    if (qesap_file_find_string(file => $args{error_log}, search_string => 'Missing sudo password')) {
        record_info('DETECTED ANSIBLE MISSING SUDO PASSWORD ERROR');
        @ret = qesap_execute(cmd => 'ansible',
            logname => 'qesap_ansible_retry.log.txt',
            timeout => 3600);
        if ($ret[0])
        {
            qesap_cluster_logs();
            die "'qesap.py ansible' return: $ret[0]";
        }
        record_info('ANSIBLE RETRY PASS');
    }
    elsif (qesap_file_find_string(file => $args{error_log}, search_string => 'Timed out waiting for last boot time check')) {
        record_info('DETECTED ANSIBLE TIMEOUT ERROR');
        # Do cleanup before redeploy
        qesap_terraform_clean_up_retry();
        @ret = qesap_execute(
            cmd => 'terraform',
            verbose => 1,
            logname => 'qesap_terraform_retry.log.txt',
            timeout => 1800
        );
        die "'qesap.py terraform' return: $ret[0]" if ($ret[0]);
        @ret = qesap_execute(
            cmd => 'ansible',
            verbose => 1,
            logname => 'qesap_ansible_retry.log.txt',
            timeout => 3600
        );
        if ($ret[0]) {
            qesap_cluster_logs();
            die "'qesap.py ansible' return: $ret[0]";
        }
        record_info('ANSIBLE RETRY PASS');
    }
    else {
        qesap_cluster_logs();
        return 1;
    }
    return 0;
}

1;
