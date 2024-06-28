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

=head1 SYNOPSIS

Library contains functions that handle SDAF naming conventions used in various strings.
Mostly used for generating resource  names, file names or file paths.
Please try not to add here complex functions that do much beyond returning a string.

=cut

our @EXPORT = qw(
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

B<$sdaf_region_code>: Region name abbreviation containing 4 uppercase alphanumeric characters

Performs region name conversion from 4 letter SDAF abbreviation to full region name.
You can find definitions in the function B<get_region_code> located in sdaf shell script:

L<https://github.com/Azure/sap-automation/blob/3c5d0d882f5892ae2159e262062e29c2b3fe59d9/deploy/scripts/deploy_utils.sh#L403>

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

B<$region>: Full region name. Can contain only lowercase alphanumeric characters.

Performs region name conversion from full region name to 4 letter SDAF abbreviation.
You can find definitions in the function B<get_region_code> located in sdaf shell script:

L<https://github.com/Azure/sap-automation/blob/3c5d0d882f5892ae2159e262062e29c2b3fe59d9/deploy/scripts/deploy_utils.sh#L403>

=cut

sub convert_region_to_short {
    my ($region) = @_;
    croak 'Missing mandatory argument "$region"' unless $region;
    croak "Abbreviation must use lowercase alphanumeric characters. Got: '$region'" unless $region =~ /^[a-z0-9]+$/;

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

B<create>: Create directory if it does not exist.

Returns deployment directory path with job ID appended as unique identifier.
Optionally it can create directory if it does not exists.

=cut

sub deployment_dir {
    my (%args) = @_;
    my $deployment_dir = get_var('DEPLOYMENT_ROOT_DIR', '/tmp') . '/Azure_SAP_Automated_Deployment_' . get_current_job_id();
    assert_script_run("mkdir -p $deployment_dir") if $args{create};
    return $deployment_dir;
}

=head2 log_dir

    log_dir([create=>1]);

B<create>: Create directory if it does not exist.

Returns logging directory path with job ID appended as unique identifier.
Optionally creates the directory.

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

B<deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

B<env_code>:  SDAF parameter for environment code (for our purpose we can use 'LAB')

B<sdaf_region_code>: SDAF parameter to choose PC region. Note SDAF is using internal abbreviations (SECE = swedencentral)

B<vnet_code>: SDAF parameter for virtual network code. Library and deployer use different vnet than SUT env

B<sap_sid>: SDAF parameter for sap system ID

B<job_id>: Specify job id instead of using current one. Default: current job id

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

B<deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

B<env_code>:  SDAF parameter for environment code (for our purpose we can use 'LAB')

B<sdaf_region_code>: SDAF parameter to choose PC region. Note SDAF is using internal abbreviations (SECE = swedencentral)

B<vnet_code>: SDAF parameter for virtual network code. Library and deployer use different vnet than SUT env

B<sap_sid>: SDAF parameter for sap system ID. Required only for 'sap_system' deployment type

=cut

sub get_tfvars_path {
    my (%args) = @_;

    # Argument (%args) validation is done by 'get_sdaf_config_path()'
    my $config_root_path = get_sdaf_config_path(%args);

    my $job_id = get_current_job_id();

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

B<$deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

Returns name of the resource group for the deployment type specified by B<$deployment_type> .
Resource group pattern: I<SDAF-OpenQA-[deployment type]-[deployment id]-[OpenQA job id]>

=cut

sub generate_resource_group_name {
    my (%args) = @_;
    my @supported_types = ('workload_zone', 'sap_system', 'library', 'deployer');
    croak "Unsupported deployment type: $args{deployment_type}\nCurrently supported ones are: @supported_types" unless
      grep(/^$args{deployment_type}$/, @supported_types);
    my $job_id = get_current_job_id();

    return join('-', 'SDAF', 'OpenQA', $args{deployment_type}, $job_id);
}
