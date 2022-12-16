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
use YAML::PP;
use utils 'file_content_replace';
use testapi;
use Exporter 'import';
use utils 'zypper_call';


my @log_files = ();

# Terraform requirement
#  terraform/azure/infrastructure.tf  "azurerm_storage_account" "mytfstorageacc"
# stdiag<PREFID><JOB_ID> can only consist of lowercase letters and numbers,
# and must be between 3 and 24 characters long
use constant QESAPDEPLOY_PREFIX => 'qesapdep';

our @EXPORT = qw(
  qesap_create_folder_tree
  qesap_pip_install
  qesap_upload_logs
  qesap_get_deployment_code
  qesap_get_inventory
  qesap_get_nodes_number
  qesap_get_terraform_dir
  qesap_prepare_env
  qesap_execute
  qesap_yaml_replace
  qesap_ansible_cmd
  qesap_ansible_script_output
  qesap_create_ansible_section
);

=head1 DESCRIPTION

    Package with common methods and default or constant  values for qe-sap-deployment
=head2 Methods


=head3 qesap_get_file_paths

    Returns a hash containing file paths for config files
=cut

sub qesap_get_file_paths {
    my %paths;
    $paths{qesap_conf_filename} = get_required_var('QESAP_CONFIG_FILE');
    $paths{deployment_dir} = get_var('QESAP_DEPLOYMENT_DIR', get_var('DEPLOYMENT_DIR', '/root/qe-sap-deployment'));
    $paths{terraform_dir} = get_var('PUBLIC_CLOUD_TERRAFORM_DIR', $paths{deployment_dir} . '/terraform');
    $paths{qesap_conf_trgt} = $paths{deployment_dir} . '/scripts/qesap/' . $paths{qesap_conf_filename};
    $paths{qesap_conf_src} = data_url('sles4sap/qe_sap_deployment/' . $paths{qesap_conf_filename});
    return (%paths);
}

=head3 qesap_create_folder_tree

    Create all needed folders
=cut

sub qesap_create_folder_tree {
    my %paths = qesap_get_file_paths();
    assert_script_run("mkdir -p $paths{deployment_dir}", quiet => 1);
}

=head3 qesap_get_variables

    Scans yaml config for '%OPENQA_VARIABLE%' placeholders and searches for values in OpenQA defined variables.
    Returns hash with openqa variable key/value pairs.
=cut

sub qesap_get_variables {
    my %paths = qesap_get_file_paths();
    my $yaml_file = $paths{'qesap_conf_src'};
    my %variables;
    my $grep_cmd = "grep -v '#' | grep -oE %[A-Z0-9_]*% | sed s/%//g";
    my $cmd = join(' ', 'curl -s -fL', $yaml_file, '|', $grep_cmd);

    for my $variable (split(" ", script_output($cmd))) {
        $variables{$variable} = get_required_var($variable);
    }
    return \%variables;
}

=head3 qesap_create_ansible_section

    Writes "ansible" section into yaml config file.
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

=head3 qesap_pip_install

  Install all Python requirements of the qe-sap-deployment
=cut

sub qesap_pip_install {
    zypper_call('in python39');
    enter_cmd 'pip3.9 config --site set global.progress_bar off';
    my $pip_ints_cmd = 'pip3.9 install --no-color --no-cache-dir ';
    my $pip_install_log = '/tmp/pip_install.txt';
    my %paths = qesap_get_file_paths();

    push(@log_files, $pip_install_log);
    record_info("QESAP repo", "Installing pip requirements");
    assert_script_run(join(' ', $pip_ints_cmd, '-r', $paths{deployment_dir} . '/requirements.txt | tee -a', $pip_install_log), 360);
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
    my $failok = $args{failok};
    record_info("Uploading logfiles", join("\n", @log_files));
    while (my $file = pop @log_files) {
        upload_logs($file, failok => $failok);
    }
}

=head3 qesap_get_deployment_code

    Get the qe-sap-deployment code
=cut

sub qesap_get_deployment_code {
    my $official_repo = 'github.com/SUSE/qe-sap-deployment';
    my $qesap_git_clone_log = '/tmp/git_clone.txt';
    my %paths = qesap_get_file_paths();

    record_info("QESAP repo", "Preparing qe-sap-deployment repository");

    enter_cmd "cd " . $paths{deployment_dir};
    push(@log_files, $qesap_git_clone_log);

    # Script from a release
    if (get_var('QESAP_INSTALL_VERSION')) {
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

=head3 qesap_yaml_replace

    Replaces yaml config file variables with parameters defined by OpenQA testode, yaml template or yaml schedule.
    Openqa variables need to be added as a hash with key/value pair inside %run_args{openqa_variables}.
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
    cmd_options - allows to append additional qesap.py commans arguments like "qesap.py terraform -d"
        Example:
        qesap_execute(cmd => 'terraform', cmd_options => '-d') will result in:
        qesap.py terraform -d

    Execute qesap glue script commands. Check project documentation for available options:
    https://github.com/SUSE/qe-sap-deployment
    Test only returns execution result, failure has to be handled by calling method.
=cut

sub qesap_execute {
    my (%args) = @_;
    die 'QESAP command to execute undefined' unless $args{cmd};

    my $verbose = $args{verbose} ? "--verbose" : "";
    my %paths = qesap_get_file_paths();
    $args{cmd_options} ||= '';

    my $exec_log = "/tmp/qesap_exec_$args{cmd}";
    $exec_log .= "_$args{cmd_options}" if ($args{cmd_options});
    $exec_log .= '.log.txt';
    $exec_log =~ s/[-\s]+/_/g;

    my $qesap_cmd = join(' ', 'python3.9', $paths{deployment_dir} . '/scripts/qesap/qesap.py',
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
    my $exec_rc = script_run($qesap_cmd, timeout => $args{timeout});
    qesap_upload_logs();
    return $exec_rc;
}

=head3 qesap_get_inventory

    Return the path of the generated inventory
=cut

sub qesap_get_inventory {
    my ($provider) = @_;
    my %paths = qesap_get_file_paths();
    return "$paths{deployment_dir}/terraform/" . lc $provider . '/inventory.yaml';
}

=head3 qesap_get_nodes_number

Get the number of cluster nodes from the inventory.yaml
=cut

sub qesap_get_nodes_number {
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

=head3 qesap_get_terraform_dir

    Return the path used by the qesap script as -chdir argument for terraform
    It is useful if test would like to call terraform
=cut

sub qesap_get_terraform_dir {
    my ($provider) = @_;
    my %paths = qesap_get_file_paths();
    return "$paths{deployment_dir}/terraform/" . lc $provider;
}

=head3 qesap_prepare_env

    qesap_prepare_env(variables=>{dict with variables}, provider => 'aws');

    Prepare terraform environment.
    - creates file structures
    - pulls git repository
    - external config files
    - installs pip requirements and OS packages
    - generates config files with qesap script

    For variables example see 'qesap_yaml_replace'
    Returns only result, failure handling has to be done by calling method.
=cut

sub qesap_prepare_env {
    my (%args) = @_;
    my $variables = $args{openqa_variables} ? $args{openqa_variables} : qesap_get_variables();
    my $provider = $args{provider};
    my %paths = qesap_get_file_paths();

    # Option to skip straight to configuration
    unless ($args{only_configure}) {
        qesap_create_folder_tree();
        qesap_get_deployment_code();
        qesap_pip_install();

        record_info("QESAP yaml", "Preparing yaml config file");
        assert_script_run('curl -v -fL ' . $paths{qesap_conf_src} . ' -o ' . $paths{qesap_conf_trgt});
    }

    qesap_yaml_replace(openqa_variables => $variables);
    push(@log_files, $paths{qesap_conf_trgt});

    record_info("QESAP conf", "Generating all terraform and Ansible configuration files");
    push(@log_files, "$paths{terraform_dir}/$provider/terraform.tfvars");
    push(@log_files, "$paths{deployment_dir}/ansible/playbooks/vars/hana_media.yaml");
    my $hana_vars = "$paths{deployment_dir}/ansible/playbooks/vars/hana_vars.yaml";
    my $exec_rc = qesap_execute(cmd => 'configure', verbose => 1);
    push(@log_files, $hana_vars) if (script_run("test -e $hana_vars") == 0);
    qesap_upload_logs(failok => 1);
    die("Qesap deployment returned non zero value during 'configure' phase.") if $exec_rc;
    return;
}

=head3 qesap_ansible_cmd

    Use Ansible to run a command remotely on some or all
    the hosts from the inventory.yaml

    qesap_prepare_env(cmd=>{string}, provider => 'aws');

=over 4

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<FILTER> - filter hosts in the inventory

=back
=cut

sub qesap_ansible_cmd {
    my (%args) = @_;
    croak 'Missing mandatory cmd argument' unless $args{cmd};
    my $inventory = qesap_get_inventory($args{provider});
    $args{user} ||= 'cloudadmin';
    $args{filter} ||= 'all';

    my $ansible_cmd = join(' ',
        'ansible',
        $args{filter},
        '-i', $inventory,
        '-u', $args{user},
        '-b', '--become-user=root',
        '-a', "\"$args{cmd}\"");
    assert_script_run($ansible_cmd);
}


=head3 qesap_ansible_script_output

    Use Ansible to run a command remotely and get the stdout.
    Command could be executed with elevated privileges

    qesap_ansible_script_output(cmd => 'crm status', provider => 'aws', host => 'vmhana01', root => 1);

    It uses playbook data/sles4sap/script_output.yaml

    1. ansible-playbook run the playbook
    2. the playbook executes the command and redirects the output to file, both remotely
    3. the playbook download the file locally
    4. the file is read and stored to be returned to the caller

=over 5

=item B<PROVIDER> - Cloud provider name, used to find the inventory

=item B<CMD> - command to run remotely

=item B<HOST> - filter hosts in the inventory

=item B<USER> - user on remote host, default to 'cloudadmin'

=item B<ROOT> - 1 to enable remote execution with elevated user, default to 0

=back
=cut

sub qesap_ansible_script_output {
    my (%args) = @_;
    croak 'Missing mandatory cmd argument' unless $args{cmd};
    croak 'Missing mandatory host argument' unless $args{host};
    $args{user} ||= 'cloudadmin';
    $args{root} ||= 0;

    my $inventory = qesap_get_inventory($args{provider});

    my $pb = 'script_output.yaml';
    my $local_path = '/tmp/ansible_script_output/';
    my $local_file = 'testout.txt';
    my $local_tmp = $local_path . $local_file;

    if (script_run 'test -e script_output.yaml') {
        my $cmd = join(' ',
            'curl', '-v', '-fL',
            data_url("sles4sap/$pb"),
            '-o', $pb);
        assert_script_run($cmd);
    }

    my @ansible_cmd = ('ansible-playbook', '-vvvv', $pb);
    push @ansible_cmd, ('-l', $args{host}, '-i', $inventory);
    push @ansible_cmd, ('-u', $args{user});
    push @ansible_cmd, ('-b', '--become-user', 'root') if ($args{root});
    push @ansible_cmd, ('-e', qq("cmd='$args{cmd}'"),
        '-e', "out_path='$local_path'",
        '-e', "out_file='$local_file'");

    enter_cmd "rm $local_tmp";
    assert_script_run(join(' ', @ansible_cmd));
    my $output = script_output("cat $local_tmp");
    enter_cmd "rm $local_tmp";
    return $output;
}

1;
