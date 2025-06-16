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

    Copyright 2025 SUSE LLC
    SPDX-License-Identifier: FSFAP

=head1 AUTHORS

    QE SAP <qe-sap@suse.de>

=cut

package sles4sap::qesap::qesapdeployment;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use YAML::PP;
use Exporter 'import';
use Scalar::Util 'looks_like_number';
use File::Basename;
use utils qw(file_content_replace);
use version_utils 'is_sle';
use publiccloud::utils qw(get_credentials);
use sles4sap::qesap::qesap_aws;
use sles4sap::azure_cli;
use mmapi 'get_current_job_id';
use testapi;


my @log_files = ();

# Terraform requirement that constrain QESAPDEPLOY_PREFIX value
#  terraform/azure/infrastructure.tf  "azurerm_storage_account" "mytfstorageacc"
# stdiag<PREFID><JOB_ID> can only consist of lowercase letters and numbers,
# and must be between 3 and 24 characters long
use constant QESAPDEPLOY_PREFIX => 'qesapdep';

use constant QESAPDEPLOY_VENV => '/tmp/exec_venv';
use constant QESAPDEPLOY_PY_DEFAULT_VER => '3.11';

our @EXPORT = qw(
  qesap_upload_logs
  qesap_get_deployment_code
  qesap_get_roles_code
  qesap_get_inventory
  qesap_get_nodes_number
  qesap_get_nodes_names
  qesap_get_terraform_dir
  qesap_get_ansible_roles_dir
  qesap_prepare_env
  qesap_execute
  qesap_terraform_conditional_retry
  qesap_ansible_cmd
  qesap_ansible_script_output_file
  qesap_ansible_script_output
  qesap_ansible_fetch_file
  qesap_ansible_reg_module
  qesap_create_ansible_section
  qesap_remote_hana_public_ips
  qesap_wait_for_ssh
  qesap_cluster_log_cmds
  qesap_cluster_logs
  qesap_upload_crm_report
  qesap_supportconfig_logs
  qesap_add_server_to_hosts
  qesap_calculate_deployment_name
  qesap_export_instances
  qesap_import_instances
  qesap_is_job_finished
  qesap_calculate_address_range
  qesap_az_get_resource_group
  qesap_az_vnet_peering
  qesap_az_simple_peering_delete
  qesap_az_vnet_peering_delete
  qesap_az_get_active_peerings
  qesap_az_clean_old_peerings
  qesap_az_setup_native_fencing_permissions
  qesap_az_get_tenant_id
  qesap_az_create_sas_token
  qesap_az_list_container_files
  qesap_az_diagnostic_log
  qesap_terrafom_ansible_deploy_retry
);

=head1 DESCRIPTION

    Package with common methods and default or constant values for qe-sap-deployment

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
    die 'Missing deployment_dir in paths' unless $paths{deployment_dir};
    assert_script_run("mkdir -p $paths{deployment_dir}", quiet => 1);
    die 'Missing roles_dir in paths' unless $paths{roles_dir};
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

    assert_script_run("test -e $yaml_config_path",
        fail_message => "Yaml config file '$yaml_config_path' does not exist.");

    my $raw_file = script_output("cat $yaml_config_path");
    my $yaml_data = $ypp->load_string($raw_file);

    $yaml_data->{ansible}{$section} = $content;

    # write into file
    my $yaml_dumped = $ypp->dump_string($yaml_data);
    save_tmp_file($paths{qesap_conf_filename}, $yaml_dumped);
    my $cmd = join(' ', 'curl', '-v',
        '-fL', autoinst_url . "/files/" . $paths{qesap_conf_filename},
        '-o', $paths{qesap_conf_trgt});
    assert_script_run($cmd);
    return;
}

=head3 qesap_venv_cmd_exec

    Run a command within the Python virtualenv
    created by qesap_pip_install.

    This function never dies: it always returns an error to the caller.
    Timeout error is 124 (the one reported by timeout command line utility).

=over

=item B<CMD> - command to run within the .venv, usually it is a qesap.py based command

=item B<TIMEOUT> - default 90 secs, has to be an integer greater than 0

=item B<LOG_FILE> - optional argument that results in changing the command to redirect the output to a log file

=back
=cut

sub qesap_venv_cmd_exec {
    my (%args) = @_;
    croak 'Missing mandatory cmd argument' unless $args{cmd};
    $args{timeout} //= bmwqemu::scale_timeout(90);
    croak "Invalid timeout value $args{timeout}" unless $args{timeout} > 0;

    my $cmd = '';
    # pipefail is needed as at the end of the command line there could be a pipe
    # to redirect all output to a log_file.
    # pipefail allow script_run always getting the exit code of the cmd command
    # and not only the one from tee
    $cmd .= 'set -o pipefail ; ' if $args{log_file};
    $cmd .= join(' ', 'timeout', $args{timeout}, $args{cmd});
    # always use tee in append mode
    $cmd .= " |& tee -a $args{log_file}" if $args{log_file};

    my $ret = script_run('source ' . QESAPDEPLOY_VENV . '/bin/activate');
    if ($ret) {
        record_info('qesap_venv_cmd_exec error', "source .venv ret:$ret");
        return $ret;
    }
    $ret = script_run($cmd, timeout => ($args{timeout} + 10));

    # deactivate python virtual environment
    script_run('deactivate');

    return $ret;
}

=head3 qesap_py

  Return string of the python to use
=cut

sub qesap_py {
    return 'python' . get_var('QESAP_PYTHON_VERSION', QESAPDEPLOY_PY_DEFAULT_VER);
}

=head3 qesap_pip

  Return string of the pip to use
=cut

sub qesap_pip {
    return 'pip' . get_var('QESAP_PIP_VERSION', QESAPDEPLOY_PY_DEFAULT_VER);
}

=head3 qesap_pip_install

  Install all Python requirements of the qe-sap-deployment
  in a dedicated virtual environment.
  This function has no return code but it is expected to die
  if something internally fails.
=cut

sub qesap_pip_install {
    my %paths = qesap_get_file_paths();
    my $pip_install_log = '/tmp/pip_install.txt';
    my $pip_ints_cmd = join(' ', qesap_pip(), 'install --no-color --no-cache-dir',
        '-r', "$paths{deployment_dir}/requirements.txt");

    # Create a Python virtualenv
    assert_script_run(join(' ', qesap_py(), '-m venv', QESAPDEPLOY_VENV));

    # Configure pip in it, ignore the return value
    # and does not provide any timeout as it should be
    # instantaneous
    qesap_venv_cmd_exec(cmd => qesap_pip() . ' config --site set global.progress_bar off');

    push(@log_files, $pip_install_log);
    record_info('QESAP repo', 'Installing all qe-sap-deployment python requirements');
    my $ret = qesap_venv_cmd_exec(
        cmd => $pip_ints_cmd,
        timeout => 720,
        log_file => $pip_install_log);

    # here it is possible to retry in case of exit code 124
    die "cmd:$pip_ints_cmd  --> ret:$ret" if $ret;
}


=head3 qesap_galaxy_install

  Install all Ansible requirements of the qe-sap-deployment.
  This function has no return code but it is expected to die
  if something internally fails.
=cut

sub qesap_galaxy_install {
    my %paths = qesap_get_file_paths();
    my $galaxy_install_log = '/tmp/galaxy_install.txt';

    my $ans_req = "$paths{deployment_dir}/requirements.yml";
    my $ans_galaxy_cmd = join(' ',
        'ansible-galaxy install',
        '-r', $ans_req);

    push(@log_files, $galaxy_install_log);
    my $ret = qesap_venv_cmd_exec(
        cmd => $ans_galaxy_cmd,
        timeout => 720,
        log_file => $galaxy_install_log);

    # here it is possible to retry in case of exit code 124
    die "cmd:$ans_galaxy_cmd  --> ret:$ret" if $ret;
}

=head3 qesap_upload_logs

    qesap_upload_logs([failok=1])

    Collect and upload logs present in @log_files.
    This is about logs generated locally on the jumphost.

=over

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

    enter_cmd("cd " . $paths{deployment_dir});
    push(@log_files, $qesap_git_clone_log);

    # Script from a release
    if (get_var('QESAP_INSTALL_VERSION')) {
        record_info('WARNING', 'QESAP_INSTALL_GITHUB_REPO will be ignored') if (get_var('QESAP_INSTALL_GITHUB_REPO'));
        record_info('WARNING', 'QESAP_INSTALL_GITHUB_BRANCH will be ignored') if (get_var('QESAP_INSTALL_GITHUB_BRANCH'));
        my $ver_artifact;
        if (check_var('QESAP_INSTALL_VERSION', 'latest')) {
            my $latest_release_url = "https://$official_repo/releases/latest";
            my $redirect_url = script_output("curl -s -L -o /dev/null -w %{url_effective} $latest_release_url");
            die "Failed to parse the latest version from $redirect_url" if ($redirect_url !~ /\/tag\/v([0-9.]+)$/);
            my $version = $1;
            $ver_artifact = "v$version.tar.gz";
            record_info("Vesion latest", "Latest QE-SAP-DEPLOYMENT release used: $version");
        }
        else {
            $ver_artifact = 'v' . get_var('QESAP_INSTALL_VERSION') . '.tar.gz';
        }

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
        assert_script_run("set -o pipefail ; $git_clone_cmd  |& tee $qesap_git_clone_log", quiet => 1);
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

    enter_cmd("cd " . $paths{roles_dir});
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
        my $git_clone_cmd = join(' ', 'git clone',
            '--depth 1',
            "--branch $git_branch",
            'https://' . $git_repo,
            $paths{roles_dir});
        assert_script_run("set -o pipefail ; $git_clone_cmd |& tee $roles_git_clone_log", quiet => 1);
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

    qesap_execute(
        cmd => '<configure|terraform,|ansible>',
        logname => '<SOMENAME>.log.txt'
        [, verbose => 1, cmd_options => <cmd_options>] );

    Example:
        qesap_execute(cmd => 'terraform', logname => 'terraform_destroy.log.txt', cmd_options => '-d')
    result in:
        qesap.py terraform -d

    Execute qesap glue script commands. Check project documentation for available options:
    https://github.com/SUSE/qe-sap-deployment
    Function returns a two element array:
      - first element is an integer representing the execution result
      - second element is the file path of the execution log
    This function is not expected to internally die, any failure has to be handled by the caller.

=over

=item B<CMD> - qesap.py subcommand to run

=item B<LOGNAME> - filename of the log file. This file will be saved in `/tmp` folder

=item B<CMD_OPTIONS> - set of arguments for the qesap.py subcommand

=item B<VERBOSE> - activate verbosity in qesap.py. 0 is no verbosity (default), 1 is to enable verbosity

=item B<TIMEOUT> - max expected execution time, default 90sec

=back
=cut

sub qesap_execute {
    my (%args) = @_;
    foreach (qw(cmd logname)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $verbose = $args{verbose} ? "--verbose" : "";
    $args{cmd_options} //= '';
    $args{timeout} //= bmwqemu::scale_timeout(90);

    my %paths = qesap_get_file_paths();
    my $exec_log = '/tmp/' . $args{logname};

    my $qesap_cmd = join(' ', qesap_py(), $paths{deployment_dir} . '/scripts/qesap/qesap.py',
        $verbose,
        '-c', $paths{qesap_conf_trgt},
        '-b', $paths{deployment_dir},
        $args{cmd},
        $args{cmd_options});

    push(@log_files, $exec_log);
    record_info("QESAP exec $args{cmd}", "Executing: \n$qesap_cmd \n\nlog to $exec_log");

    my $exec_rc = qesap_venv_cmd_exec(
        cmd => $qesap_cmd,
        timeout => $args{timeout},
        log_file => $exec_log);

    my @qesap_logs;

    # look for logs produced directly by the qesap.py
    my $qesap_log_find = 'find . -type f -name "*.log.txt"';
    foreach my $log (split(/\n/, script_output($qesap_log_find, proceed_on_failure => 1))) {
        push(@log_files, $log);
        # Also record them in a dedicated list
        # to be able to delete them as soon as they are uploaded.
        # It is needed to not create duplicated uploads
        # from different deployment stages (terraform, ansible, destroy, retry, ...)
        push(@qesap_logs, $log);
    }

    qesap_upload_logs();

    foreach (@qesap_logs) {
        enter_cmd("rm -f $_");
    }

    my @results = ($exec_rc, $exec_log);
    return @results;
}

=head3 qesap_terraform_conditional_retry

    qesap_terraform_conditional_retry(
        error_list => ['Fatal:'],
        logname => 'somefile.txt'
        [, verbose => 1, cmd_options => '--parallel 3', timeout => 1200, retries => 5, destroy => 1] );

    Execute 'qesap.py ... teraform' and eventually retry for some specific errors.
    Test returns execution result in same format of qesap_execute.

=over

=item B<ERROR_LIST> - list of error strings to search for in the log file. If any is found, it enables terraform retry

=item B<LOGNAME> - filename of the log file.

=item B<CMD_OPTIONS> - set of arguments for the qesap.py subcommand

=item B<TIMEOUT> - max expected execution time, default 90sec

=item B<RETRIES> - number of retries in case of expected error

=item B<VERBOSE> - activate verbosity in qesap.py. 0 is no verbosity (default), 1 is to enable verbosity

=item B<DESTROY> - destroy terraform before retrying terraform apply

=back
=cut

sub qesap_terraform_conditional_retry {
    my (%args) = @_;
    foreach (qw(error_list logname)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    $args{timeout} //= bmwqemu::scale_timeout(90);
    $args{retries} //= 1;
    my $retries_count = $args{retries};
    my %exec_args = (
        cmd => 'terraform',
        verbose => $args{verbose},
        timeout => $args{timeout},
        logname => $args{logname}
    );
    $exec_args{cmd_options} = $args{cmd_options} if $args{cmd_options};

    my @ret = qesap_execute(%exec_args);

    while ($retries_count > 0) {
        # Stop re-trying as soon as it PASS
        return @ret if ($ret[0] == 0);

        # Immediately fails if the output does not have one of the errors indicated by the caller
        return @ret if (!qesap_file_find_strings(file => $ret[1], search_strings => $args{error_list}));
        record_info('DETECTED ERROR');

        # Executing terraform destroy before retrying terraform apply
        if ($args{destroy}) {
            my @destroy_ret = qesap_execute(
                cmd => 'terraform',
                cmd_options => '-d',
                logname => "qesap_exec_terraform_destroy_before_retry$retries_count.log.txt",
                verbose => 1,
                timeout => 1200);
            return @destroy_ret if ($destroy_ret[0] != 0);
        }

        $exec_args{logname} = 'qesap_terraform_retry_' . ($args{retries} - $retries_count) . '.log.txt';
        @ret = qesap_execute(%exec_args);

        $retries_count--;
    }

    return @ret;
}

=head3 qesap_file_find_strings

    Search for a list of strings in the Ansible log file.
    Returns 1 if any of the strings are found in the log file, 0 otherwise.

=over

=item B<FILE> - Path to the Ansible log file. (Required)

=item B<SEARCH_STRINGS> - Array of strings to search for in the log file. (Required)

=back
=cut

sub qesap_file_find_strings {
    my (%args) = @_;
    foreach (qw(file search_strings)) {
        croak "Missing mandatory $_ argument" unless $args{$_};
    }

    for my $s (@{$args{search_strings}}) {
        my $ret = script_run("grep \"$s\" $args{file}");
        return 1 if $ret == 0;
    }
    return 0;
}

=head3 qesap_get_inventory

    Return the path of the generated inventory

=over

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

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_nodes_number {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $yp = YAML::PP->new();

    my $inventory_content = script_output("cat $inventory");
    my $parsed_inventory = $yp->load_string($inventory_content);
    my $num_hosts = 0;
    while ((my $key, my $value) = each(%{$parsed_inventory->{all}->{children}})) {
        $num_hosts += keys %{$value->{hosts}};
    }
    return $num_hosts;
}

=head3 qesap_get_nodes_names

Get the cluster nodes' names from the inventory.yaml

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_get_nodes_names {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $yp = YAML::PP->new();

    my $inventory_content = script_output("cat $inventory");
    my $parsed_inventory = $yp->load_string($inventory_content);
    my @hosts;
    while ((my $key, my $value) = each(%{$parsed_inventory->{all}->{children}})) {
        if (exists $value->{hosts}) {
            push @hosts, keys %{$value->{hosts}};
        }
    }
    return @hosts;
}

=head3 qesap_get_terraform_dir

    Return the path used by the qesap script as -chdir argument for terraform
    It is useful if test would like to call terraform

=over

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

=over

=item B<PROVIDER> - Cloud provider name, used to optionally activate AWS credential code

=back
=cut

sub qesap_prepare_env {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    croak "Missing mandatory argument 'region' when 'provider' is EC2" if (($args{provider} eq 'EC2') && !$args{region});

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
    my $terraform_tfvars = join('/',
        qesap_get_terraform_dir(provider => $args{provider}),
        'terraform.tfvars');
    push(@log_files, $terraform_tfvars);
    my $hana_media = "$paths{deployment_dir}/ansible/playbooks/vars/hana_media.yaml";
    my $hana_vars = "$paths{deployment_dir}/ansible/playbooks/vars/hana_vars.yaml";
    my @exec_rc = qesap_execute(cmd => 'configure', logname => 'qesap_configure.log.txt', verbose => 1);

    if ($args{provider} eq 'EC2') {
        my $data = get_credentials(url_suffix => 'aws.json');
        qesap_aws_create_config(region => $args{region});
        qesap_aws_create_credentials(
            conf_trgt => $paths{qesap_conf_trgt},
            key => $data->{access_key_id},
            secret => $data->{secret_access_key});
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

=over

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
    $args{user} //= 'cloudadmin';
    $args{filter} //= 'all';
    $args{timeout} //= bmwqemu::scale_timeout(90);
    $args{failok} //= 0;
    my $verbose = $args{verbose} ? ' -vvvv' : '';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    record_info('Ansible cmd:', "Run on '$args{filter}' node\ncmd: '$args{cmd}'");

    my $ansible_cmd = join(' ',
        'ansible' . $verbose,
        $args{filter},
        '-i', $inventory,
        '-u', $args{user},
        '-b', '--become-user=root',
        '-a', "\"$args{cmd}\"");

    $ansible_cmd = $args{host_keys_check} ?
      join(' ', $ansible_cmd,
        '-e',
        "'ansible_ssh_common_args=\"-o UpdateHostKeys=yes -o StrictHostKeyChecking=accept-new\"'") :
      $ansible_cmd;

    my $ret = qesap_venv_cmd_exec(cmd => $ansible_cmd, timeout => $args{timeout});

    die "cmd: $ansible_cmd ret: $ret" if ($ret && !$args{failok});
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

=over

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<HOST> - filter hosts in the inventory

=item B<FILE> - result file name

=item B<OUT_PATH> - path to save result file locally (without file name)

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<VERBOSE> - 1 result in ansible-playbook to be called with '-vvvv', default is 0.

=item B<TIMEOUT> - max expected execution time, default 180sec.
    Same timeout is used both for the execution of script_output.yaml and for the fetch_file.
    Timeout of the same amount is started two times.

=item B<REMOTE_PATH> - Path to save file in the remote (without file name)

=back
=cut

sub qesap_ansible_script_output_file {
    my (%args) = @_;
    foreach (qw(provider cmd host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} //= 'cloudadmin';
    $args{root} //= 0;
    $args{failok} //= 0;
    $args{timeout} //= bmwqemu::scale_timeout(180);
    $args{verbose} //= 0;
    my $verbose = $args{verbose} ? '-vvvv' : '';
    $args{remote_path} //= '/tmp/';
    $args{out_path} //= '/tmp/ansible_script_output/';
    $args{file} //= 'testout.txt';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $playbook = 'script_output.yaml';
    qesap_ansible_get_playbook(playbook => $playbook);

    my @ansible_cmd = ('ansible-playbook', $verbose, $playbook);
    push @ansible_cmd, ('-l', $args{host}, '-i', $inventory, '-u', $args{user});
    push @ansible_cmd, ('-b', '--become-user', 'root') if ($args{root});
    push @ansible_cmd, ('-e', qq("cmd='$args{cmd}'"),
        '-e', "out_file='$args{file}'", '-e', "remote_path='$args{remote_path}'");
    push @ansible_cmd, ('-e', "failok=yes") if ($args{failok});

    my $ret = qesap_venv_cmd_exec(cmd => join(' ', @ansible_cmd),
        timeout => $args{timeout});
    die "ret: $ret" if ($ret && !$args{failok});

    # Grab the file from the remote
    return qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        user => $args{user},
        root => $args{root},
        remote_path => $args{remote_path},
        out_path => $args{out_path},
        file => $args{file},
        timeout => $args{timeout},
        verbose => $args{verbose});
}

=head3 qesap_ansible_script_output

    Return the output of a command executed on the remote machine via Ansible.

=over

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
    $args{user} //= 'cloudadmin';
    $args{root} //= 0;
    $args{failok} //= 0;
    $args{remote_path} //= '/tmp/';
    $args{out_path} //= '/tmp/ansible_script_output/';
    $args{file} //= 'testout.txt';

    # Grab command output as file
    my $local_tmp = qesap_ansible_script_output_file(cmd => $args{cmd},
        provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        user => $args{user},
        root => $args{root},
        remote_path => $args{remote_path},
        out_path => $args{out_path},
        file => $args{file},
        timeout => $args{timeout});
    # Print output and delete output file
    my $output = script_output("cat $local_tmp");
    enter_cmd("rm $local_tmp || echo 'Nothing to delete'");
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

=over

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<HOST> - filter hosts in the inventory

=item B<REMOTE_PATH> - path to find file in the remote (without file name)

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=item B<FAILOK> - if not set, Ansible failure result in die

=item B<TIMEOUT> - max expected execution time, default 180sec

=item B<FILE> - file name of the local copy of the file

=item B<OUT_PATH> - path to save file locally (without file name)

=item B<VERBOSE> - 1 result in ansible-playbook to be called with '-vvvv', default is 0.

=back
=cut

sub qesap_ansible_fetch_file {
    my (%args) = @_;
    foreach (qw(provider host remote_path)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{user} //= 'cloudadmin';
    $args{root} //= 0;
    $args{failok} //= 0;
    $args{timeout} //= bmwqemu::scale_timeout(180);
    $args{out_path} //= '/tmp/ansible_script_output/';
    $args{file} //= 'testout.txt';
    $args{verbose} //= 0;
    my $verbose = $args{verbose} ? '-vvvv' : '';

    my $inventory = qesap_get_inventory(provider => $args{provider});
    my $fetch_playbook = 'fetch_file.yaml';

    qesap_ansible_get_playbook(playbook => $fetch_playbook);

    my @ansible_fetch_cmd = ('ansible-playbook', $verbose, $fetch_playbook);
    push @ansible_fetch_cmd, ('-l', $args{host}, '-i', $inventory);
    push @ansible_fetch_cmd, ('-u', $args{user});
    push @ansible_fetch_cmd, ('-b', '--become-user', 'root') if ($args{root});
    push @ansible_fetch_cmd, ('-e', "local_path='$args{out_path}'",
        '-e', "remote_path='$args{remote_path}'",
        '-e', "file='$args{file}'");
    push @ansible_fetch_cmd, ('-e', "failok=yes") if ($args{failok});

    my $ret = qesap_venv_cmd_exec(
        cmd => join(' ', @ansible_fetch_cmd),
        timeout => $args{timeout});
    die "ret: $ret" if ($ret && !$args{failok});

    # reflect the same logic implement in the playbook
    return $args{out_path} . $args{file};
}

=head3 qesap_ansible_reg_module

    Compose the ansible-playbook argument for the registration.yaml playbook,
    about an additional module registration

    -e sles_modules='[{"key":"SLES-LTSS-Extended-Security/12.5/x86_64","value":"*******"}]'

    Known limitation is that registration.yaml supports multiple modules to be registered,
    this code only supports one.

=over
=item B<reg> - name and reg_code for the additional extension to register.
                This argument is a two element comma separated list string.
                Like: 'SLES-LTSS-Extended-Security/12.5/x86_64,123456789'
                First string before the comma has to be a valid SCC extension name, later used by Ansible
                as argument for SUSEConnect or registercloudguest argument.
                Second string has to be valid registration code for the particular extension.

=back
=cut

sub qesap_ansible_reg_module {
    my (%args) = @_;
    croak 'Missing mandatory "reg" argument' unless $args{reg};
    my @reg_args = split(/,/, $args{reg});
    die "Missing reg_code for '$reg_args[0]'" if (@reg_args != 2);
    return "-e sles_modules='[{" .
      "\"key\":\"$reg_args[0]\"," .
      "\"value\":\"$reg_args[1]\"}]'";
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

=over

=item B<HOST> - IP of the host to probe

=item B<TIMEOUT> - time to wait before to give up, default is 10mins

=item B<PORT> - port to probe, default is 22

=back
=cut

sub qesap_wait_for_ssh {
    my (%args) = @_;
    croak 'Missing mandatory host argument' unless $args{host};
    $args{timeout} //= bmwqemu::scale_timeout(600);
    $args{port} //= 22;

    my $start_time = time();
    my $check_port = 1;

    # Looping until reaching timeout or passing two conditions :
    # - SSH port 22 is reachable
    # - journalctl got message about reaching one of certain targets
    my $cmd = join(' ', 'nc', '-vz', '-w', '1', $args{host}, $args{port});
    while ((my $duration = time() - $start_time) < $args{timeout}) {
        return $duration if (script_run($cmd, quiet => 1) == 0);
        sleep 5;
    }

    return -1;
}

=head3 qesap_upload_crm_report

    Run crm report on a host and upload the resulting tarball to openqa

=over

=item B<HOST> - host to get the report from

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<FAILOK> - if not set, Ansible failure result in die

=back
=cut

sub qesap_upload_crm_report {
    my (%args) = @_;
    foreach (qw(provider host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{failok} //= 0;

    my $log_filename = "$args{host}-crm_report";

    if ($log_filename =~ /hana\[(\d+)\]/) {
        my $number = $1 + 1;
        $log_filename = "vmhana0${number}-crm_report";
    }
    $log_filename =~ s/[\[\]"]//g;

    my $crm_log = "/var/log/$log_filename";
    my $crm_log_postfix = is_sle('15+') ? 'tar.gz' : 'tar.bz2';
    my $report_opt = !is_sle('12-sp4+') ? '-f0' : '';
    qesap_ansible_cmd(cmd => "crm report $report_opt -E /var/log/ha-cluster-bootstrap.log $crm_log",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(180),
        failok => $args{failok});
    my $local_path = qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        root => 1,
        remote_path => '/var/log/',
        out_path => '/tmp/ansible_script_output/',
        file => "$log_filename" . '.' . "$crm_log_postfix",
        verbose => 1);
    upload_logs($local_path, failok => 1);
}

=head3 qesap_upload_supportconfig_logs

    Genarate supportconfig log on a host and upload the resulting tarball to openqa

=over

=item B<HOST> - host to get the report from

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<FAILOK> - if not set, Ansible failure result in die

=back
=cut

sub qesap_upload_supportconfig_logs {
    my (%args) = @_;
    foreach (qw(provider host)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{failok} //= 0;

    my $log_filename = "$args{host}-supportconfig_log";

    if ($log_filename =~ /hana\[(\d+)\]/) {
        my $number = $1 + 1;
        $log_filename = "vmhana0${number}-supportconfig_log";
    }
    $log_filename =~ s/[\[\]"]//g;

    qesap_ansible_cmd(cmd => "sudo supportconfig -R /var/tmp -B $log_filename -x AUDIT",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(7200),
        failok => $args{failok});
    qesap_ansible_cmd(cmd => "sudo chmod 755 /var/tmp/scc_$log_filename.txz",
        provider => $args{provider},
        filter => "\"$args{host}\"",
        host_keys_check => 1,
        verbose => 1,
        timeout => bmwqemu::scale_timeout(7200),
        failok => $args{failok});
    my $local_path = qesap_ansible_fetch_file(provider => $args{provider},
        host => $args{host},
        failok => $args{failok},
        root => 1,
        remote_path => '/var/tmp/',
        out_path => '/tmp/ansible_script_output/',
        file => "scc_$log_filename.txz",
        verbose => 1);
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
        {
            Cmd => 'cat /var/log/zypper.log',
            Output => 'zypper.log.txt',
        },
        {
            Cmd => 'cat /var/log/zypp/history',
            Output => 'zypp.history.txt',
        },
        {
            Cmd => 'cat /var/log/cloudregister',
            Output => 'cloudregister.txt',
        },
        {
            Cmd => 'rpm -qa',
            Output => 'rpm-qa.txt',
        }
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

  Collect logs from a deployed cluster.
  This is about logs generated remotely on the two HANA nodes,
  `crm report` collection is part of this function.
=cut

sub qesap_cluster_logs {
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $inventory = qesap_get_inventory(provider => $provider);

    if (script_run("test -e $inventory", 60) == 0)
    {
        foreach my $host ('hana[0]', 'hana[1]') {
            foreach my $cmd (qesap_cluster_log_cmds()) {
                my $log_filename = "$host-$cmd->{Output}";
                # remove square brackets
                $log_filename =~ s/[\[\]"]//g;
                my $out = qesap_ansible_script_output_file(cmd => $cmd->{Cmd},
                    provider => $provider,
                    host => $host,
                    failok => 1,
                    root => 1,
                    path => '/tmp/',
                    out_path => '/tmp/ansible_script_output/',
                    file => $log_filename);
                upload_logs($out, failok => 1);
            }
            # Upload crm report
            qesap_upload_crm_report(host => $host, provider => $provider, failok => 1);
        }
    }

    if ($provider eq 'AZURE') {
        my @diagnostic_logs = qesap_az_diagnostic_log();
        foreach (@diagnostic_logs) {
            push(@log_files, $_);
        }
        qesap_upload_logs();
    }
}

=head3 qesap_supportconfig_logs

  Collect supportconfig logs from all HANA nodes of a deployed cluster

=over

=item B<PROVIDER> - Cloud provider name using same format of PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_supportconfig_logs {
    my (%args) = @_;
    croak "Missing mandatory argument 'provider'" unless $args{provider};
    my $inventory = qesap_get_inventory(provider => $args{provider});

    if (script_run("test -e $inventory", 60) == 0)
    {
        foreach my $host ('hana[0]', 'hana[1]') {
            qesap_upload_supportconfig_logs(host => $host, provider => $args{provider}, failok => 1);
        }
    }
}

=head3 qesap_calculate_deployment_name

Compose the deployment name. It always has the JobId

=over

=item B<PREFIX> - optional substring prepend in front of the job id

=back
=cut

sub qesap_calculate_deployment_name {
    my ($prefix) = @_;
    my $id = get_current_job_id();
    return $prefix ? $prefix . $id : $id;
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

=head3 qesap_add_server_to_hosts

    Adds a 'ip -> name' pair in the end of /etc/hosts in the hosts

=over

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

=over

=item B<$test_id> - OpenQA test ID from a test previously run with "QESAP_DEPLOYMENT_IMPORT=1" and
                    infrastructure still being up and running

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
    record_info('EXPORT',
        "SSH keys and instances data uploaded to test results:\n" . join("\n", @upload_files));
}

=head3 qesap_is_job_finished

    Get whether a specified job is still running or not. 
    In cases of ambiguous responses, they are considered to be in `running` state.

=over

=item B<JOB_ID> - id of job to check

=back
=cut

sub qesap_is_job_finished {
    my ($job_id) = @_;
    my $url = get_required_var('OPENQA_HOSTNAME') . "/api/v1/jobs/$job_id";
    my $json_data = script_output("curl -s '$url'");

    my $job_data = eval { decode_json($json_data) };
    if ($@) {
        if ($json_data =~ /<h1>Page not found<\/h1>/) {
            record_info(
                "JOB NOT FOUND",
                "Job $job_id was not found on the server " . get_required_var('OPENQA_HOSTNAME') .
                  ". It may be deleted, from a different openqa server or from a manual deployment."
            );
        }
        else {
            record_info("OPENQA QUERY FAILED", "Failed to decode JSON data for job $job_id: $@");
        }
        return 0;    # assume job is still running if we can't get its info
    }

    my $job_state = $job_data->{job}->{state} // 'running';    # assume job is running if unable to get status
    return ($job_state ne 'running');
}

=head3 qesap_az_get_resource_group

Query and return the resource group used
by the qe-sap-deployment

=over

=item B<SUBSTRING> - optional substring to be used with additional grep at the end of the command

=back
=cut

sub qesap_az_get_resource_group {
    my (%args) = @_;
    my $substring = $args{substring} ? " | grep $args{substring}" : "";
    my $job_id = get_var('QESAP_DEPLOYMENT_IMPORT', get_current_job_id());    # in case existing deployment is used
    my $cmd = "az group list --query \"[].name\" -o tsv | grep $job_id" . $substring;
    my $result = script_output($cmd, proceed_on_failure => 1);
    record_info('QESAP RG', "result:$result");
    return $result;
}

=head3 qesap_calculate_address_range

Calculate a main range that can be used in Azure for vnet or in AWS for vpc.
Also calculate a secondary range within the main one for Azure subnet address ranges.
The format is 10.ip2.ip3.0/21 and /24 respectively.
ip2 and ip3 are calculated using the slot number as seed.

=over

=item B<SLOT> - integer to be used as seed in calculating addresses

=back

=cut

sub qesap_calculate_address_range {
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
        main_address_range => sprintf("10.%d.%d.0/21", $ip2, $ip3),
        subnet_address_range => sprintf("10.%d.%d.0/24", $ip2, $ip3),
    );
}

=head3 qesap_az_vnet_peering

    Create a pair of network peering between
    the two provided deployments.

=over

=item B<SOURCE_GROUP> - resource group of source

=item B<TARGET_GROUP> - resource group of target

=item B<TIMEOUT> - default is 5 mins

=back
=cut

sub qesap_az_vnet_peering {
    my (%args) = @_;
    foreach (qw(source_group target_group)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $source_vnet = az_network_vnet_get(resource_group => $args{source_group}, query => "[0].name");
    my $target_vnet = az_network_vnet_get(resource_group => $args{target_group}, query => "[0].name");
    $args{timeout} //= bmwqemu::scale_timeout(300);

    my $vnet_show_cmd = 'az network vnet show --query id --output tsv';

    my $source_vnet_id = script_output(join(' ',
            $vnet_show_cmd,
            '--resource-group', $args{source_group},
            '--name', $source_vnet));
    record_info("source vnet ID: $source_vnet_id");

    my $target_vnet_id = script_output(join(' ',
            $vnet_show_cmd,
            '--resource-group', $args{target_group},
            '--name', $target_vnet));
    record_info("[M] target vnet ID: $target_vnet_id");

    my $peering_name = "$source_vnet-$target_vnet";
    my $peering_cmd = join(' ',
        'az network vnet peering create',
        '--name', $peering_name,
        '--allow-vnet-access',
        '--output table');

    assert_script_run(join(' ',
            $peering_cmd,
            '--resource-group', $args{source_group},
            '--vnet-name', $source_vnet,
            '--remote-vnet', $target_vnet_id), timeout => $args{timeout});
    record_info('PEERING SUCCESS (source)',
        "Peering from $args{source_group}.$source_vnet server was successful");

    assert_script_run(join(' ',
            $peering_cmd,
            '--resource-group', $args{target_group},
            '--vnet-name', $target_vnet,
            '--remote-vnet', $source_vnet_id), timeout => $args{timeout});
    record_info('PEERING SUCCESS (target)',
        "Peering from $args{target_group}.$target_vnet server was successful");

    record_info('Checking peering status');
    assert_script_run(join(' ',
            'az network vnet peering show',
            '--name', $peering_name,
            '--resource-group', $args{target_group},
            '--vnet-name', $target_vnet,
            '--output table'));
    record_info('AZURE PEERING SUCCESS');
}

=head3 qesap_az_simple_peering_delete

    Delete a single peering one way

=over

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
    my $peering_cmd = join(' ',
        'az network vnet peering delete',
        '-n', $args{peering_name},
        '--resource-group', $args{rg},
        '--vnet-name', $args{vnet_name});
    return script_run($peering_cmd, timeout => $args{timeout});
}

=head3 qesap_az_vnet_peering_delete

    Delete all the network peering between the two provided deployments.

=over

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

    my $target_vnet = az_network_vnet_get(resource_group => $args{target_group}, query => "[0].name");

    my $peering_name = qesap_az_get_peering_name(resource_group => $args{target_group});
    if (!$peering_name) {
        record_info('NO PEERING',
            "No peering between $args{target_group} and resources belonging to the current job to be destroyed!");
        return;
    }

    record_info('Attempting peering destruction');
    my $source_ret = 0;
    record_info('Destroying job_resources->IBSM peering');
    if ($args{source_group}) {
        my $source_vnet = az_network_vnet_get(resource_group => $args{source_group}, query => "[0].name");
        $source_ret = qesap_az_simple_peering_delete(
            rg => $args{source_group},
            vnet_name => $source_vnet,
            peering_name => $peering_name,
            timeout => $args{timeout});
    }
    else {
        record_info('NO PEERING',
            "No peering between job VMs and IBSM - maybe it wasn't created, or the resources have been destroyed.");
    }
    record_info('Destroying IBSM -> job_resources peering');
    my $target_ret = qesap_az_simple_peering_delete(
        rg => $args{target_group},
        vnet_name => $target_vnet,
        peering_name => $peering_name,
        timeout => $args{timeout});

    if ($source_ret == 0 && $target_ret == 0) {
        record_info('Peering deletion SUCCESS', 'The peering was successfully destroyed');
        return;
    }
    record_soft_failure("Peering destruction FAIL: There may be leftover peering connections, please check - jsc#7487");
}

=head3 qesap_az_peering_list_cmd

    Compose the azure peering list command, using the provided:
    - resource group, and
    - vnet
    Returns the command string to be run.

=over

=item B<RESOURCE_GROUP> - resource group connected to the peering

=item B<VNET> - vnet connected to the peering

=back
=cut

sub qesap_az_peering_list_cmd {
    my (%args) = @_;
    foreach (qw(resource_group vnet)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    return join(' ', 'az network vnet peering list',
        '-g', $args{resource_group},
        '--vnet-name', $args{vnet},
        '--query "[].name"',
        '-o tsv');
}

=head3 qesap_az_get_peering_name

    Search for all network peering related to both:
     - resource group related to the current job
     - the provided resource group.
    Returns the peering name or
    empty string if a peering doesn't exist

=over

=item B<RESOURCE_GROUP> - resource group connected to the peering

=back
=cut

sub qesap_az_get_peering_name {
    my (%args) = @_;
    croak 'Missing mandatory target_group argument' unless $args{resource_group};

    my $job_id = get_current_job_id();
    my $cmd = qesap_az_peering_list_cmd(resource_group => $args{resource_group}, vnet => az_network_vnet_get(resource_group => $args{resource_group}, query => "[0].name"));
    $cmd .= ' | grep ' . $job_id;
    return script_output($cmd, proceed_on_failure => 1);
}

=head3 qesap_az_get_active_peerings

    Get active peering for Azure jobs

=over

=item B<RG> - Resource group in question

=item B<VNET> - vnet name of rg

=back
=cut

sub qesap_az_get_active_peerings {
    my (%args) = @_;
    foreach (qw(rg vnet)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $cmd = qesap_az_peering_list_cmd(resource_group => $args{rg}, vnet => $args{vnet});
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

    Delete leftover peering for Azure jobs that finished without cleaning up

=over

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
        resource_group=>$resource_group);

    Sets up managed identity (MSI) by enabling system assigned identity and
    role 'Virtual Machine Contributor'

=over

=item B<VM_NAME> - VM name

=item B<RESOURCE_GROUP> - resource group resource belongs to

=back
=cut

sub qesap_az_setup_native_fencing_permissions {
    my (%args) = @_;
    foreach ('vm_name', 'resource_group') {
        croak "Missing argument: '$_'" unless defined($args{$_});
    }

    # Enable system assigned identity
    my $vm_id = script_output(join(' ',
            'az vm identity assign',
            '--only-show-errors',
            "-g '$args{resource_group}'",
            "-n '$args{vm_name}'",
            "--query 'systemAssignedIdentity'",
            '-o tsv'));
    die 'Returned output does not match ID pattern' if az_validate_uuid_pattern(uuid => $vm_id) eq 0;

    # Assign role
    my $subscription_id = script_output('az account show --query "id" -o tsv');
    my $role_id = script_output('az role definition list --name "Linux Fence Agent Role" --query "[].id" --output tsv');
    my $az_cmd = join(' ', 'az role assignment',
        'create --only-show-errors',
        "--assignee-object-id $vm_id",
        '--assignee-principal-type ServicePrincipal',
        "--role '$role_id'",
        "--scope '/subscriptions/$subscription_id/resourceGroups/$args{resource_group}'");
    assert_script_run($az_cmd);
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
    croak 'Returned output does not match ID pattern' if az_validate_uuid_pattern(uuid => $tenant_id) eq 0;
    return $tenant_id;
}

=head2 qesap_az_create_sas_token

Generate a SAS URI token for a storage container of choice

Return the token string

=over

=item B<STORAGE> - Storage account name used fur the --account-name argument in az commands

=item B<CONTAINER> - container name within the storage account

=item B<KEYNAME> - name of the access key within the storage account

=item B<PERMISSION> - access permissions. Syntax is what documented in
                      'az storage container generate-sas --help'.
                      Some of them of interest: (a)dd (c)reate (d)elete (e)xecute (l)ist (m)ove (r)ead (w)rite.
                      Default is 'r'

=item B<LIFETIME> - life time of the token in minutes, default is 10min

=back
=cut

sub qesap_az_create_sas_token {
    my (%args) = @_;
    foreach (qw(storage container keyname)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    $args{lifetime} //= 10;
    $args{permission} //= 'r';
    croak "$args{permission} : not supported permission in openQA" unless ($args{permission} =~ /^(?:r|l|rl|lr)$/);

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

=head2 qesap_az_list_container_files

Returns a list of the files that exist inside a given path in a given container
in Azure storage.

Generated command looks like this:

az storage blob list 
--account-name <account_name> 
--container-name <container_name> 
--sas-token "<my_token>" 
--prefix <path_inside_container> 
--query "[].{name:name}" --output tsv

=over

=item B<STORAGE> - Storage account name used fur the --account-name argument in az commands

=item B<CONTAINER> - container name within the storage account

=item B<TOKEN> - name of the SAS token to access the account (needs to have l permission)

=item B<PREFIX> - the local path inside the container (to list file inside a folder named 'dir', this would be 'dir')

=back
=cut

sub qesap_az_list_container_files {
    my (%args) = @_;
    foreach (qw(storage container token prefix)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $cmd = join(' ',
        'az storage blob list',
        '--account-name', $args{storage},
        '--container-name', $args{container},
        '--sas-token', "'$args{token}'",
        '--prefix', $args{prefix},
        '--query "[].{name:name}" --output tsv');
    my $ret = script_output($cmd);
    if ($ret && $ret ne ' ') {
        my @files = split(/\n/, $ret);
        return join(',', @files);
    }
    croak "The list azure files command output is empty or undefined.";
}

=head2 qesap_az_diagnostic_log

Call `az vm boot-diagnostics json` for each running VM in the
resource group associated to this openQA job

Return a list of diagnostic file paths on the JumpHost
=cut

sub qesap_az_diagnostic_log {
    my @diagnostic_log_files;
    my $rg = qesap_az_get_resource_group();
    my $az_list_vm_cmd = "az vm list --resource-group $rg --query '[].{id:id,name:name}' -o json";
    my $vm_data = decode_json(script_output($az_list_vm_cmd));
    my $az_get_logs_cmd = 'az vm boot-diagnostics get-boot-log --ids';
    foreach (@{$vm_data}) {
        record_info('az vm boot-diagnostics json', "id: $_->{id} name: $_->{name}");
        my $boot_diagnostics_log = '/tmp/boot-diagnostics_' . $_->{name} . '.txt';
        # Ignore the return code, so also miss the pipefail setting
        script_run(join(' ', $az_get_logs_cmd, $_->{id}, '|&', 'tee', $boot_diagnostics_log));
        push(@diagnostic_log_files, $boot_diagnostics_log);

    }
    return @diagnostic_log_files;
}

=head2 qesap_terrafom_ansible_deploy_retry

    qesap_terrafom_ansible_deploy_retry( error_log=>$error_log )
        error_log - ansible error log file name

    Retry to deploy terraform + ansible. This function is only expected to be called if a previous `qesap.py`
    execution returns a non zero exit code. If this function is called after a successful execution,
    the qesap_ansible_error_detection will not find anything wrong in the log, wrongly concluding that
    an unknown error is in the log and skipping the retry and this function will return 1.
.
    Return 0: this function manage the failure properly, perform a retry and retry was a successful deployment
    Return 1: something went wrong or this function does not know what to do with the failure

=over

=item B<ERROR_LOG> - error log filename

=item B<PROVIDER> - cloud provider name as from PUBLIC_CLOUD_PROVIDER setting

=back
=cut

sub qesap_terrafom_ansible_deploy_retry {
    my (%args) = @_;
    foreach (qw(error_log provider)) { croak "Missing mandatory $_ argument" unless $args{$_}; }

    my $detected_error = qesap_ansible_error_detection(error_log => $args{error_log});
    record_info('qesap_terrafom_ansible_deploy_retry', "detected error:$detected_error");
    my @ret;
    # 3: no sudo password
    if ($detected_error eq 3) {
        @ret = qesap_execute(cmd => 'ansible',
            logname => 'qesap_ansible_retry.log.txt',
            timeout => 3600);
        die "'qesap.py ansible' return: $ret[0]" if ($ret[0]);
        record_info('ANSIBLE RETRY PASS');
        $detected_error = 0;
    }
    # 2: reboot timeout
    elsif ($detected_error eq 2) {
        if ($args{provider} eq 'AZURE') {
            my @diagnostic_logs = qesap_az_diagnostic_log();
            foreach (@diagnostic_logs) {
                push(@log_files, $_);
                qesap_upload_logs();
            }
        }

        # Do cleanup before redeploy: perform terraform destroy, catch and ignore any error.
        # This is useful when doing cleanup before retry in case of
        # Ansible failed on 'Timed out waiting for last boot time check'
        # Do not attempt a 'ansible' cleanup after a 'Timed out waiting for last boot time check':
        # the SSH will be disconnected. E.g., ansible SSH reports '"msg": "Timeout (12s) waiting for privilege escalation prompt: "'.
        # Terraform destroy can be executed in any case
        @ret = qesap_execute(
            cmd => 'terraform',
            cmd_options => '-d',
            timeout => 1200,
            logname => 'qesap_terraform_destroy_retry.log.txt');
        if ($ret[0] == 0) {
            diag("Terraform cleanup attempt #  PASSED.");
            record_info("Clean Terraform", 'Terraform cleanup PASSED.');
        }
        else {
            diag("Terraform cleanup attempt #  FAILED.");
            record_info('Cleanup FAILED', "Cleanup terraform FAILED", result => 'fail');
        }

        # Re-deploy from scratch
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
            die "'qesap.py ansible' return: $ret[0]";
        }
        record_info('ANSIBLE RETRY PASS');
        $detected_error = 0;
    }
    else {
        # qesap_ansible_error_detection return:
        # - 0 (unknown error),
        # - 1 (generic fatal, not something we can solve by retry) or something else...
        # Mark both as a failure in the retry, allowing error to be propagated.
        $detected_error = 1;
    }
    return $detected_error;
}

=head2 qesap_ansible_error_detection

    qesap_ansible_error_detection( error_log=>$error_log )

    Inspect the provided Ansible log and search for known issue in the log
    Also provide a nice record_info to summarize the error
    Return:
     - 0: unable to detect errors
     - 1: generic fatal error
     - 2: reboot timeout
     - 3: no sudo password

=over

=item B<ERROR_LOG> - error log filename

=back
=cut

sub qesap_ansible_error_detection {
    my (%args) = @_;
    croak 'Missing mandatory error_log argument' unless $args{error_log};
    my $error_message = '';
    my $ret_code = 0;

    if (qesap_file_find_strings(file => $args{error_log},
            search_strings => ['Missing sudo password'])) {
        $error_message = 'MISSING SUDO PASSWORD';
        $ret_code = 3;
    }
    elsif (qesap_file_find_strings(file => $args{error_log},
            search_strings => ['Timed out waiting for last boot time check'])) {
        $error_message = 'REBOOT TIMEOUT';
        $ret_code = 2;
    }
    else {
        my $ansible_fatal = script_output("grep -A30 'fatal:' $args{error_log} | cut -c-200",
            proceed_on_failure => 1);
        my $ansible_failed = script_output("grep -A30 'failed: \\[' $args{error_log} | cut -c-200",
            proceed_on_failure => 1);
        $error_message .= "Ansible fatal: $ansible_fatal\n" unless ($ansible_fatal eq "");
        $error_message .= "Ansible failed: $ansible_failed\n" unless ($ansible_failed eq "");
        $ret_code = 1 unless ($error_message eq "");
    }
    record_info('ANSIBLE ISSUE', $error_message) unless $ret_code eq 0;
    return $ret_code;
}

1;
