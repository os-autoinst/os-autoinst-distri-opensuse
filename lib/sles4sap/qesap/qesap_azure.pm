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

package sles4sap::qesap::qesap_azure;

use strict;
use warnings;
use Carp qw(croak);
use Mojo::JSON qw(decode_json);
use Exporter 'import';
use File::Basename;
use sles4sap::azure_cli;
use sles4sap::qesap::qesap_utils;
use mmapi 'get_current_job_id';
use testapi;

our @EXPORT = qw(
  qesap_az_get_resource_group
  qesap_az_clean_old_peerings
  qesap_az_setup_native_fencing_permissions
  qesap_az_get_tenant_id
  qesap_az_create_sas_token
  qesap_az_list_container_files
  qesap_az_diagnostic_log
  qesap_az_vnet_peering
  qesap_az_vnet_peering_delete
  qesap_az_get_active_peerings
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
    my $substring = $args{substring} ? " | grep $args{substring}" : "";
    my $job_id = get_var('QESAP_DEPLOYMENT_IMPORT', get_current_job_id());    # in case existing deployment is used
    my $cmd = "az group list --query \"[].name\" -o tsv | grep $job_id" . $substring;
    my $result = script_output($cmd, proceed_on_failure => 1);
    record_info('QESAP RG', "result:$result");
    return $result;
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
        if (qesap_is_job_finished(job_id => $value)) {
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
    die "Returned output '$vm_id' does not match ID pattern" if (!az_validate_uuid_pattern(uuid => $vm_id));

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
    die "Returned output '$tenant_id' does not match ID pattern" if (!az_validate_uuid_pattern(uuid => $tenant_id));
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

1;
