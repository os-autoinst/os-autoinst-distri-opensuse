# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

package sles4sap::sap_deployment_automation_framework::configure_workload_tfvars;

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use Carp qw(croak);
use utils qw(write_sut_file);
use sles4sap::sap_deployment_automation_framework::deployment qw(get_os_variable get_fencing_mechanism);
use sles4sap::sap_deployment_automation_framework::naming_conventions
  qw(convert_region_to_short generate_resource_group_name);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);

=head1 SYNOPSIS

Library with common functions for Microsoft SDAF deployment automation that help with preparation of
'WORKLOAD-ZONE' tfvars file.
Generated file is following exmaple template:
https://github.com/Azure/SAP-automation-samples/blob/main/Terraform/WORKSPACES/SYSTEM/LAB-SECE-SAP04-L00/LAB-SECE-SAP04-L00.tfvars

=cut

our @EXPORT = qw(
  create_workload_tfvars
  compile_tfvars_section
  write_tfvars_file
);

=head2 write_tfvars_file

    write_tfvars_file(tfvars_file=>'/path/towards/happiness', tfvars_data=>$tfvars_data);

Data provided in B<$args{tfvars_data}> is compiled into tfvars file format and written into target B<$args{tfvars_file}>
file located on deployer VM.
B<$args{tfvars_data}> is a HASHREF containg individual sections that should be included in final tfvars content.
B<file_header> is placed as a comment as a first line of the defined section.

B<Example:>
{
file_header => "Comment placed on top of the tfvars file",
env_definitions => {header => 'Comment placed on top of a section',
    tfvars_variable = 'value', tfvars_variable_2 = 'value2'},
workload_networking => {header => 'Comment placed on top of a section',
    tfvars_variable_3 = 'value3', tfvars_variable_4 = 'value4'},
}

=over

=item * B<tfvars_file>: Target tfvars file location

=item * B<tfvars_data>: Target tfvars file data - Must be a HASHREF

=item * B<section_order>: Order in which the sections should be compiled into the file - must be an ARRAYREF

=back

=cut

sub write_tfvars_file {
    my (%args) = @_;
    for my $arg ('tfvars_data', 'tfvars_file') {
        croak "Missing mandatory argument \$args{$arg}" unless $args{$arg};
    }
    croak 'Argument \$args{tfvars_data} must be a HASHREF' unless ref($args{tfvars_data}) eq 'HASH';
    if ($args{section_order}) {
        croak 'Argument \$args{section_order} must be a ARRAYREF' unless ref($args{section_order}) eq 'ARRAY';
    }

    # If $args{section_order} is not defined, just use list of keys.
    my @section_order = $args{section_order} ? @{ $args{section_order} } : keys(%{ $args{tfvars_data} });
    my $file_contents = $args{tfvars_data}->{file_header};
    for my $section (@section_order) {
        next if $section eq 'file_header';
        $file_contents .= compile_tfvars_section($args{tfvars_data}->{$section});
    }

    write_sut_file($args{tfvars_file}, $file_contents);
}

=head2 compile_tfvars_section

    compile_tfvars_section($section_data);

Converts HASHREF based tfvars section into terraform format and returns it as a string.

=over

=item * B<$section_data>: HASHREF containing tfvars section header (comment) and variables

=back

=cut

sub compile_tfvars_section {
    my ($section_data) = @_;
    croak 'Argument \$section_data must be a HASHREF' unless ref($section_data) eq 'HASH';

    my $header = $section_data->{header};
    # Remove header from hash otherwise it will be turned into blank line by map
    delete $section_data->{header};
    return (join("\n", "\n\n$header", map { "$_ = $section_data->{$_}" } keys(%{$section_data})));
}

=head2 create_workload_tfvars

    create_workload_tfvars(network_data=>[subnet_a => '192.168.1.0/26', subnet_b => '192.168.1.65/26'],
    workload_vnet_code=>'FUN' [, environment=>'LAB', location=>'swedencentral', resource_group=>'Funky', job_id=>'1']);

Function that generates wokload zone tfvars conent according to arguments and OpenQA variables provided.
Content is generated in perl and transformed into tfvars format. File is uploaded into OpenQA format.

=over

=item * B<environment>: SDAF environment. Can be supplied using OpenQA setting 'SDAF_ENV_CODE'

=item * B<location>: Public cloud location. Can be supplied using OpenQA setting 'PUBLIC_CLOUD_REGION'

=item * B<resource_group>: Workload zone resource group name

=item * B<job_id>: Deployment job ID. Default: current job it.

=item * B<network_data>: Network data obtained from `lib/sap_deployment_automation_framework/networking::calculate_subnets`

=item * B<workload_vnet_code>: Workload zone VNET code

=back

=cut

sub create_workload_tfvars {
    my (%args) = @_;
    # Default values
    $args{environment} //= get_required_var('SDAF_ENV_CODE');
    $args{location} //= get_required_var('PUBLIC_CLOUD_REGION');
    $args{resource_group} //= generate_resource_group_name(deployment_type => 'workload_zone');
    $args{job_id} //= find_deployment_id();

    # Mandatory arguments
    for my $arg ('job_id', 'network_data', 'workload_vnet_code', 'resource_group') {
        croak("Missing mandatory argument \$args{$arg}") unless $args{$arg};
    }

    # Generate tfvars file data
    my $tfvars_file = get_os_variable('workload_zone_parameter_file');
    my %tfvars_data;
    $tfvars_data{file_header} = "### File was generated by OpenQA automation according to template:\n### https://github.com/Azure/SAP-automation-samples/blob/main/Terraform/WORKSPACES/SYSTEM/LAB-SECE-SAP04-L00/LAB-SECE-SAP04-L00.tfvars\n";
    $tfvars_data{env_definitions} = define_workload_environment(
        environment => $args{environment}, location => $args{location}, resource_group => $args{resource_group});
    $tfvars_data{workload_networking} = define_networking(
        environment => $args{environment},
        location => $args{location},
        job_id => $args{job_id},
        workload_vnet_code => $args{workload_vnet_code}
    );
    $tfvars_data{subnet_definition} = define_subnets(network_data => $args{network_data});
    $tfvars_data{nat_configuration} = define_nat_section(
        environment => $args{environment},
        sdaf_region => convert_region_to_short($args{location}),
        workload_vnet_code => $args{workload_vnet_code});
    $tfvars_data{iscsi_devices} = define_iscsi_devices();
    $tfvars_data{storage_account} = define_storage_account();

    # Write file and upload to OpenQA logs
    write_tfvars_file(tfvars_data => \%tfvars_data, tfvars_file => $tfvars_file);
    upload_logs($tfvars_file, log_name => 'workload_zone.tfvars.txt');
}

=head2 define_workload_environment

    define_workload_environment(environment=>'LAB', location=>'swedencentral', resource_group=>'OpenQA');

Returns tfvars environment definitions section in B<HASHREF> format.
This section includes various environmental parameters and parameters that do not belong to a specific section.
B<Example:> {environment : 'LAB', location : 'swedencentral'}

=over

=item * B<environment>: SDAF environment

=item * B<location>: Public cloud location

=item * B<resource_group>: Workload zone resource group

=back

=cut

sub define_workload_environment {
    my (%args) = @_;
    for my $arg ('environment', 'location', 'resource_group') {
        croak "Missing mandatory argument \$args{$arg}" unless $args{$arg};
    }
    my %result = (
        header => '### Environment definitions ###',
        environment => "\"$args{environment}\"",
        location => "\"$args{location}\"",
        # Workload zone resource group name
        resourcegroup_name => "\"$args{resource_group}\"",
        automation_username => '"' . get_var('PUBLIC_CLOUD_USER', 'azureadm') . '"',
        # enable_rbac_authorization_for_keyvault Controls the access policy model for the workload zone keyvault.
        enable_rbac_authorization_for_keyvault => 'false',
        # enable_purge_control_for_keyvaults is an optional parameter that can be used to disable the purge protection fro Azure keyvaults
        enable_purge_control_for_keyvaults => 'false',
        # use_spn defines if the deployments are performed using Service Principals or the deployer's managed identiry, true=SPN, false=MSI
        use_spn => 'true',
        # Defines the number of workload _vms to create
        utility_vm_count => '0',
        # These tags will be applied to all resources
        tags => '{"DeployedBy" = "OpenQA-SDAF-automation"}'
    );

    return (\%result);
}

=head2 define_networking

    define_networking(workload_vnet_code=>'OpenQA-42', job_id=>'42');

Returns tfvars networking parameter section in HASHREF format.

=over

=item * B<job_id>: OpenQA job ID which the deployment belongs to

=item * B<workload_vnet_code>: Workload zone VNET code

=back

=cut

sub define_networking {
    my (%args) = @_;
    for my $arg ('job_id', 'workload_vnet_code') {
        croak "Missing mandatory argument \$args{$arg}" unless $args{$arg};
    }
    my %result = (
        header => '### Networking ###',
        # The network logical name is mandatory - it is used in the naming convention and should map to the workload virtual network logical name
        network_logical_name => "$args{workload_vnet_code}",
        # Workload VNET name - keep as short as possible as resource naming has limitations
        network_name => "\"OpenQA-$args{job_id}\"",
        # disable private endpoints for key vaults and storage accounts
        use_private_endpoint => 'false',
        # disable service endpoints for key vaults and storage accounts
        use_service_endpoint => 'true',
        # Peering between control plane and workload zone (enable connection from deployer VM to SUT network)
        peer_with_control_plane_vnet => 'true',
        # Enables firewall for keyvaults and storage - only SUT subnets will be able to access it
        enable_firewall_for_keyvaults_and_storage => 'true',
        # Disable resource delete lock for cleanup to work properly
        place_delete_lock_on_resources => 'false',
        # Defines if a custom dns solution is used
        use_custom_dns_a_registration => 'false',
        # Defines if the Virtual network for the Virtual machines is registered with DNS
        # This also controls the creation of DNS entries for the load balancers
        register_virtual_network_to_dns => 'true',
        # Boolean value indicating if storage accounts and key vaults should be registered to the corresponding dns zones
        register_storage_accounts_keyvaults_with_dns => 'false',
        # If defined provides the DNS label for the Virtual Network
        dns_label => '"openqa.net"'
    );
    return \%result;
}

=head2 define_nat_section

    define_nat_section(environment=>'LAB', sdaf_region=>'swedencentral', workload_vnet_code=>'OpenQA-42');

Returns tfvars section related to NAT setup in B<HASHREF> format.

=over

=item * B<environment>: SDAF environment

=item * B<sdaf_region>: Public cloud location

=item * B<workload_vnet_code>: Public cloud location

=back

=cut

sub define_nat_section {
    my (%args) = @_;
    for my $arg ('environment', 'sdaf_region', 'workload_vnet_code') {
        croak "Missing mandatory argument \$args{$arg}" unless $args{$arg};
    }
    my %result = (
        header => '###  NAT Configuration ###',
        deploy_nat_gateway => 'true',
        nat_gateway_name => "\"$args{environment}-$args{sdaf_region}-$args{workload_vnet_code}-NG_0001\"",
        nat_gateway_public_ip_tags => '{"ipTagType": "OpenQA-SDAF-automation", "tag": "OpenQA-SDAF-automation"}'
    );

    return (\%result);
}

=head2 define_subnets

    define_subnets(network_data=>$network_data);

Returns tfvars section related to subnet setup in B<HASHREF> format.

=over

=item * B<network_data>: Network data obtained from `lib/sap_deployment_automation_framework/networking::calculate_subnets`

=back

=cut

sub define_subnets {
    my (%args) = @_;
    croak 'Missing mandatory argument $args{network_data}' unless $args{network_data};
    my %result = (
        header => '###  Subnet definitions ###',
        network_address_space => "\"$args{network_data}->{network_address_space}\"",
        iscsi_subnet_address_prefix => "\"$args{network_data}->{iscsi_subnet_address_prefix}\"",
        web_subnet_address_prefix => "\"$args{network_data}->{web_subnet_address_prefix}\"",
        admin_subnet_address_prefix => "\"$args{network_data}->{admin_subnet_address_prefix}\"",
        db_subnet_address_prefix => "\"$args{network_data}->{db_subnet_address_prefix}\"",
        app_subnet_address_prefix => "\"$args{network_data}->{app_subnet_address_prefix}\""
    );

    return (\%result);
}

=head2 define_iscsi_devices

    define_iscsi_devices();

Returns tfvars section related to setup of iSCSI server(s) in B<HASHREF> format.
iSCSI is used mostly for SBD based fencing.

=cut

sub define_iscsi_devices {
    # Convert OpenQA setting "SDAF_FENCING_MECHANISM" to value accepted by SDAF
    my $fencing_type = get_fencing_mechanism();
    my %result = (header => '###  ISCSI Devices ###');
    if ($fencing_type eq 'ISCSI') {
        # Number of iSCSI devices to be created
        $result{iscsi_count} = '"' . get_var('SDAF_ISCSI_DEVICE_COUNT', 3) . '"';
        # Size of iSCSI Virtual Machines to be created
        $result{iscsi_size} = '"Standard_D2s_v3"';
        # Defines if the iSCSI devices use DHCP
        $result{iscsi_useDHCP} = 'true';
        # Defines the Virtual Machine authentication type for the iSCSI device
        $result{iscsi_authentication_type} = '"key"';
        # Defines the username for the iSCSI devices
        $result{iscsi_authentication_username} = '"azureadm"';
        # Defines the Availability zones for the iSCSI devices
        $result{iscsi_vm_zones} = '["1", "2", "3"]';
    }
    else {
        # Do not deploy ISCSI if not needed
        $result{iscsi_count} = '"0"';
    }
    return (\%result);
}


=head2 define_storage_account

    define_storage_account();

Returns tfvars section related to storage account settings in B<HASHREF> format.
Storage accounts related to installation media and SAP transport shares.

=cut

sub define_storage_account {
    my %result = (
        header => '###  Storage account details ###',
        # Defines the size of the install volume in MB
        install_volume_size => '1024',
        # NFS will be provided using 'Azure filesystem' (AFS). NFS is used for serving installation media to SUT.
        NFS_provider => '"AFS"',
        # Create separate storage for transport. Not needed for our testing
        create_transport_storage => 'false'
    );

    return (\%result);
}
