# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Library used for Microsoft SDAF deployment related to ansible playbook execution

package sles4sap::sap_deployment_automation_framework::ansible;

use strict;
use warnings;
use testapi;
use Mojo::Base -signatures;
use Exporter qw(import);
use Carp qw(croak);
use Scalar::Util 'looks_like_number';
use sles4sap::sap_deployment_automation_framework::deployment qw($output_log_file log_command_output);
use sles4sap::sap_deployment_automation_framework::naming_conventions;

our @EXPORT = qw(
  sdaf_execute_playbook
  sdaf_register_byos
);


=head2 new

    my $playbook_setup = sles4sap::sap_deployment_automation_framework::ansible->new();

Class used for handling list of playbook settings for further execution by sdaf_execute_playbook().
Playbook description is here as well: L<https://learn.microsoft.com/en-us/azure/sap/automation/run-ansible?tabs=linux>

=cut

sub new {
    my ($class) = @_;
    # `state` initializes variables only once and keeps values across all class instances
    state $self = {
        playbooks_set => 0,
        playbook_list => []
    };
    return bless $self, $class;
}

=head3 set

    my $playbook_setup = sles4sap::sap_deployment_automation_framework::ansible->new();
    $playbook_setup->set(@components)

Method Creates list of playbook settings according to B<@components> that are to be installed.
Method can be called only once, otherwise it will die. This is to prevent resetting playbook order accidentally.
Returns full data structure of settings compiled in B<ARRAYREF> format.
Example:
[
  {playbook_filename => 'playbook_name_A.yaml', timeout => 120},
  {playbook_filename => 'playbook_name_B.yaml', timeout => 90}
]

=over

=item * B<components>: B<ARRAYREF> of components that should be installed

=back

=cut

sub set {
    my ($self, $components) = @_;
    croak('Missing mandatory argument <$components>') unless $components;
    croak('Argument <$components> is expected to be ARRAYREF') unless ref($components) eq 'ARRAY';
    # This is to prevent accidentally resetting playbook list, executing incorrect one
    croak('Method "must be executed only once per OpenQA test suite"') if ($self->{playbooks_set} == 1);
    # General playbooks that must be run in all scenarios
    my @playbook_list = (
        # Fetches SSH key from Workload zone keyvault for accesssing SUTs
        {playbook_filename => 'pb_get-sshkey.yaml', timeout => 90},
        # Validate parameters
        {playbook_filename => 'playbook_00_validate_parameters.yaml', timeout => 120},
        # Base operating system configuration
        {playbook_filename => 'playbook_01_os_base_config.yaml'}
    );
    # DB installation pulls in SAP specific configuration
    if (grep /db_install/, @$components) {
        # SAP-specific operating system configuration
        push @playbook_list, {playbook_filename => 'playbook_02_os_sap_specific_config.yaml'};
        # SAP Bill of Materials processing - this also mounts install media storage
        push @playbook_list, {playbook_filename => 'playbook_03_bom_processing.yaml', timeout => 7200};
        # SAP HANA database installation
        push @playbook_list, {playbook_filename => 'playbook_04_00_00_db_install.yaml', timeout => 3600};
    }
    # playbooks required for all nw* scenarios
    if (grep /nw/, @$components) {
        # SAP ASCS installation, including ENSA if specified in tfvars
        push @playbook_list, {playbook_filename => 'playbook_05_00_00_sap_scs_install.yaml', timeout => 7200};
        # Execute database import
        push @playbook_list, {playbook_filename => 'playbook_05_01_sap_dbload.yaml', timeout => 7200};
    }
    # Run HA related playbooks at the end as it can mix up node order ###
    if (grep /db_ha/, @$components) {
        # SAP HANA high-availability configuration
        push @playbook_list, {playbook_filename => 'playbook_04_00_01_db_ha.yaml', timeout => 3600};
    }
    # playbooks required for all nw* scenarios
    if (grep /nw/, @$components) {
        # SAP primary application server installation
        push @playbook_list, {playbook_filename => 'playbook_05_02_sap_pas_install.yaml', timeout => 7200};
        # SAP additional application server installation
        push @playbook_list, {playbook_filename => 'playbook_05_03_sap_app_install.yaml', timeout => 3600};
    }
    if (grep /nw_ensa/, @$components) {
        # Configure ENSA cluster
        push @playbook_list, {playbook_filename => 'playbook_06_00_acss_registration.yaml', timeout => 1800};
    }
    $self->{playbook_list} = \@playbook_list;
    $self->{playbooks_set} = 1;
    return $self->{playbook_list};
}

=head3 get

    my $playbook_setup = sles4sap::sap_deployment_automation_framework::ansible->new();
    $playbook_setup->set(@components);
    $playbook_setup->get();

Purpose of this method is to serve the caller playbook name and related settings which are to be executed next.
Method is supposed to be called in a loop until all playbooks are returned.
Once there are no playbooks left, structure with undefined values is returned.

=cut

sub get {
    my ($self) = @_;
    my $next = shift(@{$self->{playbook_list}});
    return $next if defined($next->{playbook_filename});
    return {playbook_filename => undef};
}

=head2 ansible_execute_command

    ansible_execute_command(
        command=>'rm -Rf /', host_group=>'QES_SCS', sdaf_config_root_dir=>'/some/path' , sap_sid=>'CAT');

Execute command on host group using ansible. Returns execution output.

=over

=item * B<sdaf_config_root_dir>: SDAF Config directory containing SUT ssh keys

=item * B<sap_sid>: SAP system ID. Default 'SAP_SID'

=item * B<host_group>: Host group name from inventory file

=item * B<command>: Command to be executed

=item * B<verbose>: verbose ansible output

=item * B<proceed_on_failure>: proceed on failure setting

=back
=cut

sub ansible_execute_command {
    my (%args) = @_;
    croak 'Missing mandatory argument "sdaf_config_root_dir".' unless $args{sdaf_config_root_dir};

    my @cmd = ('ansible', $args{host_group},
        "--private-key=$args{sdaf_config_root_dir}/sshkey",
        "--inventory=$args{sap_sid}_hosts.yaml",
        $args{verbose} ? '-vvv' : '',
        '--module-name=shell');

    return script_output(join(' ', @cmd, "--args=\"$args{command}\""), proceed_on_failure => $args{proceed_on_failure});
}

=head2 sdaf_ansible_verbosity_level

    sdaf_ansible_verbosity_level($verbosity_level);

Returns string that is to be used as verbosity parameter B<-v>  for 'ansible-playbook' command.
This is controlled by positional argument B<$verbosity_level>.
Values can specify verbosity level using integer up to 6 (max supported by ansible)
or just set to anything equal to B<'true'> which will default to B<-vvvv>. Value B<-vvvv> should be enough to debug network
connection problems according to ansible documentation:
L<https://docs.ansible.com/ansible/latest/cli/ansible-playbook.html#cmdoption-ansible-playbook-v>

=over

=item * B<$verbosity_level>: Change default verbosity value by either anything equal to 'true' or int between 1-6. Default: false

=back
=cut

sub sdaf_ansible_verbosity_level {
    my ($verbosity_level) = @_;
    return '' unless $verbosity_level;
    return '-' . 'v' x $verbosity_level if looks_like_number($verbosity_level) and $verbosity_level <= 6;
    return '-vvvv';    # Default set to "-vvvv"
}

=head2 sdaf_execute_playbook

    sdaf_execute_playbook(
        playbook_filename=>'playbook_04_00_01_db_ha.yaml',
        sdaf_config_root_dir=>'/path/to/joy/and/happiness/'
        sap_sid=>'ABC',
        timeout=>'42',
        verbosity_level=>'3'
        );

Execute playbook specified by B<playbook_filename> and record command output in separate log file.
Verbosity level of B<ansible-playbook> is controlled by openQA parameter B<SDAF_ANSIBLE_VERBOSITY_LEVEL>.
If undefined, it will use standard output without adding any B<-v> flag. See function B<sdaf_execute_playbook> for details.

=over

=item * B<playbook_filename>: Filename of the playbook to be executed.

=item * B<sdaf_config_root_dir>: SDAF Config directory containing SUT ssh keys

=item * B<sap_sid>: SAP system ID. Default 'SAP_SID'

=item * B<timeout>: Timeout for executing playbook. Passed into asset_script_run. Default: 1800s

=item * B<$verbosity_level>: Change default verbosity value by either anything equal to 'true' or int between 1-6. Default: false

=back
=cut

sub sdaf_execute_playbook {
    my (%args) = @_;
    # Flag in basetest to mark playbook RC
    $sles4sap::sap_deployment_automation_framework::basetest::serial_regexp_playbook = 1;
    $args{timeout} //= 1800;    # Most playbooks take more than default 90s
    $args{sap_sid} //= get_required_var('SAP_SID');
    $args{verbosity_level} //= get_var('SDAF_ANSIBLE_VERBOSITY_LEVEL');

    croak 'Missing mandatory argument "playbook_filename".' unless defined($args{playbook_filename});
    croak 'Missing mandatory argument "sdaf_config_root_dir".' unless $args{sdaf_config_root_dir};

    my $playbook_options = join(' ',
        sdaf_ansible_verbosity_level($args{verbosity_level}),    # verbosity controlled by OpenQA parameter
        "--inventory-file=\"$args{sap_sid}_hosts.yaml\"",
        "--private-key=$args{sdaf_config_root_dir}/sshkey",
        "--extra-vars='_workspace_directory=$args{sdaf_config_root_dir}'",
        '--extra-vars="@sap-parameters.yaml"',    # File is generated by SDAF, check official docs (SYNOPSIS) for more
        '--ssh-common-args="-o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=120"'
    );

    $output_log_file = log_dir() . "/$args{playbook_filename}" =~ s/.yaml|.yml/.txt/r;
    my $playbook_file = join('/', deployment_dir(), 'sap-automation', 'deploy', 'ansible', $args{playbook_filename});
    my $playbook_cmd = join(' ', 'ansible-playbook', $playbook_options, $playbook_file);

    record_info('Playbook run', "Executing playbook: $playbook_file\nExecuted command:\n$playbook_cmd");
    assert_script_run("cd $args{sdaf_config_root_dir}");
    my $rc = script_run(log_command_output(command => $playbook_cmd, log_file => $output_log_file),
        timeout => $args{timeout}, output => "Executing playbook: $args{playbook_filename}");
    upload_logs($output_log_file);
    die "Execution of playbook failed with RC: $rc" if $rc;
    record_info('Playbook OK', "Playbook execution finished: $playbook_file");
    # Update the reference and mark playbook as PASSED
    $sles4sap::sap_deployment_automation_framework::basetest::serial_regexp_playbook = 0;
}

=head2 sdaf_register_byos

    sdaf_register_byos(sdaf_config_root_dir=>'/stairway/to_heaven', scc_reg_code=>'CODE-XYZ', sap_sid='PRD');

Performs SCC registration on BYOS image using B<registercloudguest> method.

=over

=item * B<sdaf_config_root_dir>: SDAF root configuration directory

=item * B<scc_reg_code>: SCC registration code

=item * B<sap_sid>: SAP system ID

=back
=cut

sub sdaf_register_byos {
    my (%args) = @_;
    my @mandatory_args = qw(sdaf_config_root_dir scc_reg_code sap_sid);

    for my $arg (@mandatory_args) {
        croak "Missing mandatory argument \$args($arg)", unless $args{$arg};
    }

    record_info('Register SUTs');
    assert_script_run("cd $args{sdaf_config_root_dir}");
    ansible_execute_command(
        command => "sudo registercloudguest -r $args{scc_reg_code}",
        host_group => "$args{sap_sid}_DB",
        sdaf_config_root_dir => $args{sdaf_config_root_dir},
        sap_sid => $args{sap_sid},
        verbose => 1
    );
}

1;
