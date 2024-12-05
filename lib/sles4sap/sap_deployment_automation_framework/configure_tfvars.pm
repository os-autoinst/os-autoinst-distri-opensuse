# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::sap_deployment_automation_framework::configure_tfvars;

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use utils qw(file_content_replace);
use sles4sap::sap_deployment_automation_framework::deployment qw(get_os_variable);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);

=head1 SYNOPSIS

Library with common functions for Microsoft SDAF deployment automation that help with preparation of tfvars file.

=cut

our @EXPORT = qw(
  prepare_tfvars_file
);

=head2 prepare_tfvars_file

    prepare_tfvars_file(deployment_type=>$deployment_type);

Downloads tfvars template files from openQA data dir and places them into correct place within SDAF repo structure.
Returns full path of the tfvars file.

=over

=item * B<$deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

=back
=cut

sub prepare_tfvars_file {
    my (%args) = @_;
    croak 'Deployment type not specified' unless $args{deployment_type};
    my %tfvars_os_variable = (
        deployer => 'deployer_parameter_file',
        sap_system => 'sap_system_parameter_file',
        workload_zone => 'workload_zone_parameter_file',
        library => 'library_parameter_file'
    );
    croak "Unknown deployment type: $args{deployment_type}" unless $tfvars_os_variable{$args{deployment_type}};

    my %tfvars_template_url = (
        deployer => data_url('sles4sap/sap_deployment_automation_framework/DEPLOYER.tfvars'),
        sap_system => data_url('sles4sap/sap_deployment_automation_framework/SAP_SYSTEM.tfvars'),
        workload_zone => data_url('sles4sap/sap_deployment_automation_framework/WORKLOAD_ZONE.tfvars'),
        library => data_url('sles4sap/sap_deployment_automation_framework/LIBRARY.tfvars')
    );
    # Parameters required for defining DB VM image for SAP systems deployment
    set_db_image_parameters() if $args{deployment_type} eq 'sap_system';
    # replace default vnet name with shorter one to avoid naming restrictions
    set_workload_vnet_name();

    my $tfvars_file = get_os_variable($tfvars_os_variable{$args{deployment_type}});

    assert_script_run join(' ', 'curl', '-v', '-fL', $tfvars_template_url{$args{deployment_type}}, '-o', $tfvars_file);
    assert_script_run("test -f $tfvars_file");
    replace_tfvars_variables($tfvars_file);
    upload_logs($tfvars_file, log_name => "$args{deployment_type}.tfvars.txt");
    return $tfvars_file;
}

=head2 replace_tfvars_variables

    replace_tfvars_variables('/path/to/file.tfvars');

Replaces placeholder pattern B<%OPENQA_VARIABLE%> with corresponding OpenQA variable value.
If OpenQA variable is not set, placeholder is replaced with empty value.

=over

=item * B<$tfvars_file>: Full path to the tfvars file

=back
=cut

sub replace_tfvars_variables {
    my ($tfvars_file) = @_;
    croak 'Variable "$tfvars_file" undefined' unless defined($tfvars_file);
    my @variables = split("\n", script_output("grep -oP \'(\?<=%)[A-Z_]+(?=%)\' $tfvars_file"));
    my %to_replace = map { '%' . $_ . '%' => get_var($_, '') } @variables;
    file_content_replace($tfvars_file, %to_replace);
}

=head2 set_workload_vnet_name

    set_workload_vnet_name([job_id=>'123456']);

Returns VNET name used for workload zone and sap systems resources. VNET name must be unique for each landscape,
therefore it contains test ID as an identifier.

=over

=item * B<$job_id>: Specify job id to be used. Default: current deployment job ID

=back
=cut

sub set_workload_vnet_name {
    my (%args) = @_;
    $args{job_id} //= find_deployment_id();
    die('no deployment ID found') unless $args{job_id};
    # Try to keep vnet name as short as possible. Later this is used in the name for the peering in a format:
    # deployer-vnet_to_workload-vnet
    # if it is too long you might hit name length limit and test ID gets clipped.
    set_var('SDAF_SUT_VNET_NAME', 'OpenQA-' . $args{job_id});
}

=head2 set_vm_image_parameters

    set_vm_db_image_parameters([job_id=>'123456']);

=over

=item * B<$job_id>: Specify job id to be used. Default: current deployment job ID

=back

Sets OpenQA parameters required for replacing tfvars template variables for database VM image.

=cut

sub set_db_image_parameters {
    my %params;
    # Parse image ID supplied by OpenQA parameter 'PUBLIC_CLOUD_IMAGE_ID'
    my @variable_names = qw(SDAF_DB_IMAGE_PUBLISHER SDAF_DB_IMAGE_OFFER SDAF_DB_IMAGE_SKU SDAF_DB_IMAGE_VERSION);
    # This maps a variable name from array @variable names to value from delimited 'PUBLIC_CLOUD_IMAGE_ID' parameter
    # Order is important here
    @params{@variable_names} = split(':', get_required_var('PUBLIC_CLOUD_IMAGE_ID'));

    # Add all remaining parameters with static values
    $params{SDAF_DB_IMAGE_OS_TYPE} = 'LINUX';    # this can be modified in case of non linux images
    $params{SDAF_DB_SOURCE_IMAGE_ID} = '';    # for supplying uploaded image - not implemented yet
    $params{SDAF_DB_IMAGE_TYPE} = 'marketplace';

    foreach (keys(%params)) {
        set_var($_, $params{$_});
    }
}
