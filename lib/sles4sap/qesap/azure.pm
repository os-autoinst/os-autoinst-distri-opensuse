# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions relate to Azure to use qe-sap-deployment project
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

    qe-sap-deployment test lib for Azure

=head1 COPYRIGHT

    Copyright 2025 SUSE LLC
    SPDX-License-Identifier: FSFAP

=head1 AUTHORS

    QE SAP <qe-sap@suse.de>

=cut

package sles4sap::qesap::azure;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use Exporter 'import';
use File::Basename;
use sles4sap::azure_cli;
use sles4sap::qesap::utils;
use mmapi 'get_current_job_id';
use testapi;

our @EXPORT = qw(
  qesap_az_get_resource_group
  qesap_az_clean_old_peerings
  qesap_az_setup_native_fencing_permissions
  qesap_az_create_sas_token
  qesap_az_list_container_files
  qesap_az_diagnostic_log
);

=head1 DESCRIPTION

    Azure related functions for the qe-sap-deployment test lib

=head2 Methods


=head3 qesap_az_get_resource_group

Query and return the resource group used
by the qe-sap-deployment

=over

=item B<SUBSTRING> - optional substring to be used with additional grep at the end of the command

=back
=cut

sub qesap_az_get_resource_group {
    my (%args) = @_;
    my $job_id = get_var('QESAP_DEPLOYMENT_IMPORT', get_current_job_id());
    die "Could not determine job ID to find the resource group" unless defined $job_id;
    my $all_rg = az_group_name_get();
    my @selected_rg = grep(/$job_id/, @$all_rg);
    @selected_rg = grep(/$args{substring}/, @selected_rg) if ($args{substring});
    record_info('QESAP RG', $selected_rg[0] ? "result:$selected_rg[0]" : 'result:EMPTY');
    return $selected_rg[0];
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
    my $peerings = az_network_peering_list(resource_group => $args{rg}, vnet => $args{vnet});
    my %result;
    for my $line (@{$peerings}) {
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
        if (qesap_is_job_finished(job_id => $value)) {
            record_info('Leftover Peering', "$key is leftover from a finished job. Attempting to delete...");
            az_network_peering_delete(
                name => $key,
                resource_group => $args{rg},
                vnet => $args{vnet});
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
    my $vm_id = az_vm_identity_assign(name => $args{vm_name}, resource_group => $args{resource_group});

    # Assign role
    my $subscription_id = script_output('az account show --query "id" -o tsv');
    my $role_id = az_role_definition_list(name => "Linux Fence Agent Role");
    my $az_cmd = join(' ', 'az role assignment create',
        '--only-show-errors',
        '--assignee-object-id', $vm_id,
        '--assignee-principal-type ServicePrincipal',
        "--role '$role_id'",
        "--scope '/subscriptions/$subscription_id/resourceGroups/$args{resource_group}'");
    assert_script_run($az_cmd);
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
    # az storage container generate-sas  --account-name <STORAGE_NAME> \
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
    croak 'The list azure files command output is empty or undefined.';
}

=head2 qesap_az_diagnostic_log

Call `az vm boot-diagnostics json` for each running VM in the
resource group associated to this openQA job

Return a list of diagnostic file paths on the JumpHost
=cut

sub qesap_az_diagnostic_log {
    return az_vm_diagnostic_log_get(resource_group => qesap_az_get_resource_group());
}

1;
