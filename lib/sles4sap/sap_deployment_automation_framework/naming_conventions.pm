# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
#
# Library used to generate simple strings according to SDAF naming conventions

package sles4sap::sap_deployment_automation_framework::naming_conventions;

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use mmapi qw(get_current_job_id);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);

=head1 SYNOPSIS

Library contains functions that handle SDAF naming conventions used in various strings.
Mostly used for generating resource  names, file names or file paths.
Please try not to add here complex functions that do much beyond returning a string.

=cut

our $deployer_private_key_path = '~/.ssh/id_rsa';
our $sut_private_key_path = '~/.ssh/sut_id_rsa';

our @EXPORT = qw(
  $deployer_private_key_path
  $sut_private_key_path
  homedir
  deployment_dir
  log_dir
  sdaf_scripts_dir
  env_variable_file
  get_sdaf_config_path
  get_tfvars_path
  generate_resource_group_name
  convert_region_to_long
  convert_region_to_short
  generate_deployer_name
  get_workload_vnet_code
  get_sdaf_inventory_path
  get_sut_sshkey_path
  get_sizing_filename
  get_ibsm_peering_name
);

=head2 %sdaf_region_matrix

B<SDAF> uses own internal 4 character abbreviations for Public Cloud region names.

This is an internal matrix used for translation.  It contains only commonly used regions,
if you need to extend the list you can find definitions in the function B<get_region_code>
located in sdaf shell script at:
L<https://github.com/Azure/sap-automation/blob/3c5d0d882f5892ae2159e262062e29c2b3fe59d9/deploy/scripts/deploy_utils.sh#L403>

=cut

my %sdaf_region_matrix = (
    CEUS => 'centralus',
    EAAS => 'eastasia',
    EAUS => 'eastus',
    EUS2 => 'eastus2',
    EUSG => 'eastusstg',
    GENO => 'germanynorth',
    GEWC => 'germanywestcentral',
    NCUS => 'northcentralus',
    NOEU => 'northeurope',
    NOEA => 'norwayeast',
    NOWE => 'norwaywest',
    SECE => 'swedencentral',
    WCUS => 'westcentralus',
    WEEU => 'westeurope',
    WEUS => 'westus',
    WUS2 => 'westus2',
    WUS3 => 'westus3'
);

=head2 convert_region_to_long

    convert_region_to_long($sdaf_region_code);

Performs region name conversion from 4 letter SDAF abbreviation to full region name.
You can find definitions in the function B<get_region_code> located in sdaf shell script:

L<https://github.com/Azure/sap-automation/blob/3c5d0d882f5892ae2159e262062e29c2b3fe59d9/deploy/scripts/deploy_utils.sh#L403>

=over

=item * B<$sdaf_region_code>: Region name abbreviation containing 4 uppercase alphanumeric characters

=back
=cut

sub convert_region_to_long {
    my ($sdaf_region_code) = @_;
    croak 'Missing mandatory argument "$region"' unless $sdaf_region_code;
    croak "Abbreviation must use 4 uppercase alphanumeric characters. Got: '$sdaf_region_code'" unless $sdaf_region_code =~ /^[A-Z0-9]{4}$/;
    croak "Requested region abbreviation not found: '$sdaf_region_code'" unless $sdaf_region_matrix{$sdaf_region_code};
    return ($sdaf_region_matrix{$sdaf_region_code});
}

=head2 convert_region_to_short

    convert_region_to_short($region);

Performs region name conversion from full region name to 4 letter SDAF abbreviation.
You can find definitions in the function B<get_region_code> located in sdaf shell script:

L<https://github.com/Azure/sap-automation/blob/3c5d0d882f5892ae2159e262062e29c2b3fe59d9/deploy/scripts/deploy_utils.sh#L403>

=over

=item * B<$region>: Full region name. Can contain only lowercase alphanumeric characters.

=back
=cut

sub convert_region_to_short {
    my ($region) = @_;
    croak 'Missing mandatory argument "$region"' unless $region;
    croak "Region name must use lowercase alphanumeric characters. Got: '$region'" unless $region =~ /^[a-z0-9]+$/;

    my @found_results = grep { $_ if $sdaf_region_matrix{$_} eq $region } keys(%sdaf_region_matrix);

    croak "Value for region '$region' not found" unless @found_results;
    croak "Found multiple values belonging to region '$region': (" . join(', ', @found_results) . ')'
      unless @found_results == 1;

    return ($found_results[0]);
}

=head2 homedir

    homedir();

Returns home directory path for current user from env variable $HOME.

=cut

sub homedir {
    return (script_output('echo $HOME'));
}

=head2 deployment_dir

    deployment_dir([create=>1]);

Returns deployment directory path with job ID appended as unique identifier.
Optionally it can create directory if it does not exists.

=over

=item * B<create>: Create directory if it does not exist.

=back
=cut

sub deployment_dir {
    my (%args) = @_;
    my $deployment_dir =
      get_var('DEPLOYMENT_ROOT_DIR', '/tmp') . '/Azure_SAP_Automated_Deployment_' . find_deployment_id();
    assert_script_run("mkdir -p $deployment_dir") if $args{create};
    return $deployment_dir;
}

=head2 log_dir

    log_dir([create=>1]);

Returns logging directory path with job ID appended as unique identifier.
Optionally creates the directory.

=over

=item * B<create>: Create directory if it does not exist.

=back
=cut

sub log_dir {
    my (%args) = @_;
    my $log_dir = deployment_dir() . '/openqa_logs';
    assert_script_run("mkdir -p $log_dir") if $args{create};
    return $log_dir;
}

=head2 sdaf_scripts_dir

    sdaf_scripts_dir();

Returns directory containing SDAF scripts.

=cut

sub sdaf_scripts_dir {
    return deployment_dir() . '/sap-automation/deploy/scripts';
}

=head2 env_variable_file

    env_variable_file();

Returns full path to a file containing all required SDAF OS env variables.
Sourcing this file is essential for running SDAF.

=cut

sub env_variable_file {
    return deployment_dir() . '/sdaf_variables';
}

=head2 get_sdaf_config_path

    get_sdaf_config_path(
        deployment_type=>$deployment_type,
        env_code=>$env_code,
        sdaf_region_code=>$sdaf_region_code,
        [vnet_code=>$vnet_code,
        sap_sid=>$sap_sid,
        job_id=>$job_id]);

Returns path to config root directory for deployment type specified.
Root config directory is deployment type specific and usually contains tfvar file, inventory file, SUT ssh keys, etc...

=over

=item * B<deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

=item * B<env_code>:  SDAF parameter for environment code (for our purpose we can use 'LAB')

=item * B<sdaf_region_code>: SDAF parameter to choose PC region. Note SDAF is using internal abbreviations (SECE = swedencentral)

=item * B<vnet_code>: SDAF parameter for virtual network code. Library and deployer use different vnet than SUT env

=item * B<sap_sid>: SDAF parameter for sap system ID

=item * B<job_id>: Specify job id instead of using current one. Default: current job id

=back
=cut

sub get_sdaf_config_path {
    my (%args) = @_;
    my @supported_types = ('workload_zone', 'sap_system', 'library', 'deployer');
    croak "Invalid deployment type: $args{deployment_type}\nCurrently supported ones are: " . join(', ', @supported_types)
      unless grep(/^$args{deployment_type}$/, @supported_types);

    my @mandatory_args = qw(deployment_type env_code sdaf_region_code);
    # library does not require 'vnet_code'
    push @mandatory_args, 'vnet_code' unless $args{deployment_type} eq 'library';
    # only sap_system requires 'sap_sid'
    push @mandatory_args, 'sap_sid' if $args{deployment_type} eq 'sap_system';

    foreach (@mandatory_args) { croak "Missing mandatory argument: '$_'" unless defined($args{$_}); }

    my %config_paths = (
        workload_zone => "LANDSCAPE/$args{env_code}-$args{sdaf_region_code}-$args{vnet_code}-INFRASTRUCTURE",
        deployer => "DEPLOYER/$args{env_code}-$args{sdaf_region_code}-$args{vnet_code}-INFRASTRUCTURE",
        library => "LIBRARY/$args{env_code}-$args{sdaf_region_code}-SAP_LIBRARY",
        sap_system => "SYSTEM/$args{env_code}-$args{sdaf_region_code}-$args{vnet_code}-$args{sap_sid}"
    );

    return (join('/', deployment_dir(), 'WORKSPACES', $config_paths{$args{deployment_type}}));
}

=head2 get_tfvars_path

    get_tfvars_path(
        deployment_type=>$deployment_type,
        env_code=>$env_code,
        sdaf_region_code=>$sdaf_region_code,
        [vnet_code=>$vnet_code,
        sap_sid=>$sap_sid]);

Returns full tfvars filepath respective to deployment type.

=over

=item * B<deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

=item * B<env_code>:  SDAF parameter for environment code (for our purpose we can use 'LAB')

=item * B<sdaf_region_code>: SDAF parameter to choose PC region. Note SDAF is using internal abbreviations (SECE = swedencentral)

=item * B<vnet_code>: SDAF parameter for virtual network code. Library and deployer use different vnet than SUT env

=item * B<sap_sid>: SDAF parameter for sap system ID. Required only for 'sap_system' deployment type

=back
=cut

sub get_tfvars_path {
    my (%args) = @_;

    # Argument (%args) validation is done by 'get_sdaf_config_path()'
    my $config_root_path = get_sdaf_config_path(%args);

    my $job_id = find_deployment_id();

    my %file_names = (
        workload_zone => "$args{env_code}-$args{sdaf_region_code}-$args{vnet_code}-INFRASTRUCTURE-$job_id.tfvars",
        deployer => "$args{env_code}-$args{sdaf_region_code}-$args{vnet_code}-INFRASTRUCTURE-$job_id.tfvars",
        library => "$args{env_code}-$args{sdaf_region_code}-SAP_LIBRARY-$job_id.tfvars",
        sap_system => "$args{env_code}-$args{sdaf_region_code}-$args{vnet_code}-$args{sap_sid}-$job_id.tfvars"
    );


    return "$config_root_path/$file_names{$args{deployment_type}}";
}

=head2 generate_resource_group_name

    generate_resource_group_name(deployment_type=>$deployment_type);

Returns name of the resource group for the deployment type specified by B<$deployment_type> .
Resource group pattern: I<SDAF-OpenQA-[deployment type]-[deployment id]-[OpenQA job id]>

=over

=item * B<$deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

=back
=cut

sub generate_resource_group_name {
    my (%args) = @_;
    my @supported_types = ('workload_zone', 'sap_system', 'library', 'deployer');
    croak "Unsupported deployment type: $args{deployment_type}\nCurrently supported ones are: @supported_types" unless
      grep(/^$args{deployment_type}$/, @supported_types);
    my $job_id = find_deployment_id();

    return join('-', 'SDAF', 'OpenQA', $args{deployment_type}, $job_id);
}

=head2 generate_deployer_name

    generate_deployer_name([job_id=>$job_id]);

Generates resource name for deployer VM in format B<test_id-OpenQA_Deployer_VM>.

=over 1

=item * B<$job_id>: Specify job id to be used. Default: current job ID

=back
=cut

sub generate_deployer_name {
    my (%args) = @_;
    $args{job_id} //= get_current_job_id();
    return "$args{job_id}-OpenQA_Deployer_VM";
}

=head2 get_workload_vnet_code

    get_workload_vnet_code([job_id=>$job_id]);

Returns VNET code used for workload zone and sap systems resources. VNET code must be unique for each landscape,
therefore it contains test ID as an identifier.

=over

=item * B<$job_id>: Specify job id to be used. Default: current job ID

=back
=cut

sub get_workload_vnet_code {
    my (%args) = @_;
    $args{job_id} //= find_deployment_id();
    die('no deployment ID found') unless $args{job_id};
    # Try to keep vnet code as short as possible. Later this is used in the name for the peering in a format:
    # deployer-vnet_to_workload-vnet
    # if it is too long you might hit name length limit and test ID gets clipped.
    return ($args{job_id});
}

=head2 get_sdaf_inventory_path

    get_sdaf_inventory_path(config_root_path=>'/config/path', sap_sid=>'QAS');

Returns full Ansible inventory filepath respective to deployment type.
B<config_root_path> can be obtained from function B<get_sdaf_config_path>.

=over

=item * B<config_root_path>: SDAF config root path

=item * B<sap_sid>: SDAF parameter for sap system ID.

=back
=cut

sub get_sdaf_inventory_path {
    my (%args) = @_;
    for my $argument (qw(sap_sid config_root_path)) {
        croak "Missing mandatory argument '$argument'" unless $args{$argument};
    }

    # file name is hard coded in SDAF
    return "$args{config_root_path}/$args{sap_sid}_hosts.yaml";
}

=head2 get_sut_sshkey_path

    get_sut_sshkey_path(config_root_path=>'/config/path');

Returns full SUT private sshkey filepath located on deployer VM after deployment.
B<config_root_path> can be obtained from function B<get_sdaf_config_path>.

=over

=item * B<config_root_path>: SDAF config root path

=back
=cut

sub get_sut_sshkey_path {
    my (%args) = @_;
    croak 'Missing mandatory argument $args{config_root_path}' unless $args{config_root_path};

    # file name is hard coded in SDAF
    return "$args{config_root_path}/sshkey";
}

=head2 get_sizing_filename

    get_sizing_filename();

Returns custom sizing file name located in B<data/sles4sap/sap_deployment_automation_framework> according to deployment
type specified in OpenQA setting B<SDAF_DEPLOYMENT_SCENARIO>.

=cut

sub get_sizing_filename {
    get_var('SDAF_DEPLOYMENT_SCENARIO') =~ 'ensa' ?
      return 'custom_sizes_S4HANA.json' :    # Customized for S4Hana deployment - required for ENSA2
      return 'custom_sizes_default.json';    # Minimal Hana sizing - good for sindgle DB, HanaSR or standard NW 7.5 setup
}

=head2 get_ibsm_peering_name

    get_ibsm_peering_name();

Returns ibsm peering name in format 'SDAF-<source_VNET>-<target_VNET>'

=cut

sub get_ibsm_peering_name {
    my (%args) = @_;
    return "SDAF-$args{source_vnet}-$args{target_vnet}";
}
