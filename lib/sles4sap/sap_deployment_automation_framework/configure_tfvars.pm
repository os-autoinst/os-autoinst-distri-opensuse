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
  validate_components
);

=head2 prepare_tfvars_file

    prepare_tfvars_file(deployment_type=>$deployment_type);

Downloads tfvars template files from openQA data dir and places them into correct place within SDAF repo structure.
Returns full path of the tfvars file.

=over

=item * B<$deployment_type>: Type of the deployment (workload_zone, sap_system, library... etc)

=item * B<components>: B<ARRAYREF> of components that should be installed. Check function B<validate_components> for available options.

=item * B<os_image>: It support both Azure catalog image name (':' separated string) or
                     image uri (as provided by PC get_image_id() and PUBLIC_CLOUD_IMAGE_LOCATION).
                     it is only used and mandatory when deployment_type is sap_system.

=back
=cut

sub prepare_tfvars_file {
    my (%args) = @_;
    croak 'Deployment type not specified' unless $args{deployment_type};
    croak "'os_image' argument is mandatory when deployment_type is sap_system" if (($args{deployment_type} eq 'sap_system') && !$args{os_image});
    croak "'components' argument is mandatory when deployment_type is sap_system" if (($args{deployment_type} eq 'sap_system') && !$args{components});
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

    # fencing parameters are set up for both sap_system and workload_zone
    set_fencing_parameters();

    # Only SAP systems deployment need those parametrs to be defined
    if ($args{deployment_type} eq 'sap_system') {
        validate_components(components => $args{components});
        # Parameters required for defining DB VM image for SAP systems deployment
        set_image_parameters(os_image => $args{os_image});
        # Parameters required for Hana DB HA scenario
        set_hana_db_parameters(components => $args{components});
        # Netweaver related parameters
        set_netweaver_parameters(components => $args{components});
    }

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
    # Regex searches for placeholders in tfvars file templates in format `%OPENQA_VARIABLE%`
    # Those will be replaced by OpenQA parameter value with the same name
    my @variables = split("\n", script_output("grep -oP \'(\?<=%)[0-9A-Z_]+(?=%)\' $tfvars_file"));
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

=head2 set_image_parameters

    set_image_parameters(image_id => 'aaa:bbb:ccc:ddd');

Sets OpenQA parameters required for replacing tfvars template variables for database VM image.

=over

=item * B<os_image>: It support both Azure catalog image name (':' separated string) or
                     image uri (as provided by PC get_image_id() and PUBLIC_CLOUD_IMAGE_LOCATION).
                     it is only used and mandatory when deployment_type is sap_system.

=back
=cut

sub set_image_parameters {
    my (%args) = @_;

    my %params;

    # This regex targets the general Azure Gallery image naming patterns,
    # excluding part of the name that are related to PC library.
    if ($args{os_image} =~ /^\/subscriptions\/.*\/galleries\/.*/) {
        $params{SDAF_SOURCE_IMAGE_ID} = $args{os_image};
        $params{SDAF_IMAGE_TYPE} = 'custom';
    }
    else {
        # Parse image ID supplied by OpenQA parameter 'PUBLIC_CLOUD_IMAGE_ID'
        my @variable_names = qw(SDAF_IMAGE_PUBLISHER SDAF_IMAGE_OFFER SDAF_IMAGE_SKU SDAF_IMAGE_VERSION);

        # This maps a variable name from array @variable names to value from delimited 'PUBLIC_CLOUD_IMAGE_ID' parameter
        # Order is important here
        @params{@variable_names} = split(':', $args{os_image});
        $params{SDAF_IMAGE_TYPE} = 'marketplace';
    }

    # Add all remaining parameters with static values
    $params{SDAF_IMAGE_OS_TYPE} = 'LINUX';    # this can be modified in case of non linux images

    foreach (keys(%params)) {
        set_var($_, $params{$_});
    }
}

=head2 set_hana_db_parameters

    set_hana_db_parameters(components=>['db_install', 'db_ha']);

Sets tfvars Database HA parameters according to scenario defined by B<$args{components}>.

=over

=item * B<components>: B<ARRAYREF> of components that should be installed. Check function B<validate_components> for available options.

=back

=cut

sub set_hana_db_parameters {
    my (%args) = @_;
    # Enable HA cluster
    set_var('SDAF_HANA_HA_SETUP', grep(/ha/, @{$args{components}}) ? 'true' : 'false');
}

=head2 set_fencing_parameters

    set_fencing_parameters();

Sets tfvars HA fencing related parameters according to scenario defined OpenQA settings.

=cut

sub set_fencing_parameters {
    # Fencing mechanism AFA (Azure fencing agent - MSI), ASD (Azure shared disk - SBD), ISCSI (iSCSI based SBD fencing)
    # Default value: 'msi' - AFA - Azure fencing agent (MSI)
    my $fencing_type = get_var('SDAF_FENCING_MECHANISM', 'msi');

    # Ensures consistent OpenQA setting names across all types deployment solutions.
    # msi = MSI based fencing
    # sbd = iSCSI based SBD devices
    # asd = Azure shared disk as SBD device
    my %supported_fencing_values = (msi => 'AFA', sbd => 'ISCSI', asd => 'ASD');
    die "Fencing type '$fencing_type' is not supported" unless grep /^$fencing_type$/, keys(%supported_fencing_values);

    # This is dumb and will be improved in TEAM-10145
    set_var('SDAF_FENCING_TYPE', $supported_fencing_values{get_var('SDAF_FENCING_MECHANISM')});
    # Setup ISCSI deployment
    if (get_var('SDAF_FENCING_TYPE') =~ /ISCSI/) {
        # Set default value for iSCSI device count
        set_var('SDAF_ISCSI_DEVICE_COUNT', get_var('SDAF_ISCSI_DEVICE_COUNT', '1'));
    }
    else {
        # Disable iSCSI deployment if not needed
        set_var('SDAF_ISCSI_DEVICE_COUNT', '0');
    }
}

=head2 set_netweaver_parameters

    set_netweaver_parameters(components=>['db_install', 'db_ha']);

Sets tfvars parameters related to SAP Netweaver according to scenario defined by B<$args{components}>.

=over

=item * B<components>: B<ARRAYREF> of components that should be installed. Check function B<validate_components> for available options.

=back

=cut

sub set_netweaver_parameters {
    my (%args) = @_;
    # Default values - everything turned off
    my %parameters = (
        # All nw_* scenarios require ASCS deployment
        SDAF_ASCS_SERVER => grep(/nw/, @{$args{components}}) ? 1 : 0,
        # So far 1x PAS and 1x AAS should be enough for coverage
        SDAF_APP_SERVER_COUNT => grep(/pas/, @{$args{components}}) + grep(/aas/, @{$args{components}}),
        SDAF_ERS_SERVER => grep(/ensa/, @{$args{components}}) ? 'true' : 'false'
    );

    for my $parameter (keys(%parameters)) {
        set_var($parameter, $parameters{$parameter});
    }
}

=head2 validate_components

    validate_components(components=>['db_install', 'db_ha']);

Checks if components list is valid and supported by code. Croaks if not.
Currently supported components are:

=over

=item * B<components>: B<ARRAYREF> of components that should be installed.
    Supported values:
        db_install : Basic DB installation
        db_ha : Database HA setup
        nw_pas : Installs primary application server (PAS)
        nw_aas : Installs additional application server (AAS)
        nw_ensa : Installs enqueue replication server (ERS)

=back

=cut

sub validate_components {
    my (%args) = @_;
    croak '$args{components} must be an ARRAYREF' unless ref($args{components}) eq 'ARRAY';

    my %valid_components = ('db_install' => 'Basic DB installation.',
        db_ha => 'db_ha : Database HA setup',
        nw_pas => 'db_pas : Installs primary application server (PAS)',
        nw_aas => 'nw_aas : Installs additional application server (AAS)',
        nw_ensa => 'nw_ensa : Installs enqueue replication server (ERS)');

    for my $component (@{$args{components}}) {
        croak "Unsupported component: '$component'\nSupported values:\n" . join("\n", values(%valid_components))
          unless grep /^$component$/, keys(%valid_components);
    }
    # need to return positive value for unit test to work properly
    return 1;
}
