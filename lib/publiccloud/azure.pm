# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: helper class for azure
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::azure;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON qw(decode_json encode_json);
use Term::ANSIColor 2.01 'colorstrip';
use Data::Dumper;
use testapi qw(is_serial_terminal :DEFAULT);
use utils qw(script_output_retry);
use publiccloud::azure_client;

has resource_group => 'openqa-upload';
has container => 'sle-images';
has lease_id => undef;
has vault => undef;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->provider_client(publiccloud::azure_client->new());
    $self->provider_client->init();
}

=head2 decode_azure_json

    my $json_obj = decode_azure_json($str);

Helper function to decode json string, retrieved from C<az>, into a json
object.
Due to https://github.com/Azure/azure-cli/issues/9903 we need to strip all
color codes from that string first.
=cut

sub decode_azure_json {
    return decode_json(colorstrip(shift));
}

sub resource_exist {
    my ($self) = @_;
    my $group = $self->resource_group;
    my $output = script_output_retry("az group show --name '$group' --output json", retry => 3, timeout => 30, delay => 10);
    return ($output ne '[]');
}

sub get_image_id {
    my ($self, $img_url) = @_;
    $img_url //= get_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    # Very special case for Azure. Ignore the image id and only use OFFER and SKU
    return "" if ((!$img_url) && get_var('PUBLIC_CLOUD_AZURE_OFFER') && get_var('PUBLIC_CLOUD_AZURE_SKU'));
    return $self->SUPER::get_image_id($img_url);
}

sub find_img {
    my ($self, $name) = @_;

    return if (!$self->resource_exist());

    ($name) = $name =~ m/([^\/]+)$/;
    $name =~ s/\.xz$//;
    $name =~ s/\.vhdfixed$/.vhd/;
    my $json = script_output("az image show --resource-group " . $self->resource_group . " --name $name", 60, proceed_on_failure => 1);
    record_info('INFO', $json);
    my $image;
    eval {
        $image = decode_azure_json($json)->{name};
    };
    record_info('INFO', "Cannot find image $name. Need to upload it.\n$@") if ($@);
    return $image;
}

sub get_storage_account_keys {
    my ($self, $storage_account) = @_;
    my $output = script_output("az storage account keys list --resource-group "
          . $self->resource_group . " --account-name " . $storage_account);
    my $json = decode_azure_json($output);
    my $key = undef;
    if (@{$json} > 0) {
        $key = $json->[0]->{value};
    }
    die("Storage account key not found!") unless $key;
    return $key;
}

sub create_resources {
    my ($self, $storage_account) = @_;
    my $timeout = 60 * 5;
    record_info('INFO', 'Create resource group ' . $self->resource_group);
    assert_script_run('az group create --name ' . $self->resource_group . ' -l ' . $self->provider_client->region, $timeout);
    record_info('INFO', 'Create storage account ' . $storage_account);
    assert_script_run('az storage account create --resource-group ' . $self->resource_group . ' -l '
          . $self->provider_client->region . ' --name ' . $storage_account . ' --kind Storage --sku Standard_LRS', $timeout);
    record_info('INFO', 'Create storage container ' . $self->container);
    assert_script_run('az storage container create --account-name ' . $storage_account
          . ' --name ' . $self->container, $timeout);
}

sub upload_img {
    my ($self, $file) = @_;

    if ($file =~ m/vhdfixed\.xz$/) {
        assert_script_run("xz -d $file", timeout => 60 * 5);
        $file =~ s/\.xz$//;
    }

    my ($img_name) = $file =~ /([^\/]+)$/;
    $img_name =~ s/\.vhdfixed/.vhd/;
    my $disk_name = $img_name;
    my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'eisleqaopenqa');

    my $rg_exist = $self->resource_exist();

    $self->create_resources($storage_account) if (!$rg_exist);

    my $key = $self->get_storage_account_keys($storage_account);

    assert_script_run('az storage blob upload --max-connections 4 --account-name '
          . $storage_account . ' --account-key ' . $key . ' --container-name ' . $self->container
          . ' --type page --file ' . $file . ' --name ' . $img_name, timeout => 60 * 60 * 2);

    my $cmd = 'az disk create --resource-group ' . $self->resource_group . ' --name ' . $disk_name
      . ' --source https://' . $storage_account . '.blob.core.windows.net/' . $self->container . '/' . $img_name;
    $cmd .= " --location " . get_var('PUBLIC_CLOUD_REGION') if (get_var('PUBLIC_CLOUD_REGION'));
    assert_script_run($cmd);

    $cmd = 'az image create --resource-group ' . $self->resource_group . ' --name ' . $img_name
      . ' --os-type Linux --source=' . $disk_name;
    $cmd .= " --location " . get_var('PUBLIC_CLOUD_REGION') if (get_var('PUBLIC_CLOUD_REGION'));
    assert_script_run($cmd);

    return $img_name;
}

sub img_proof {
    my ($self, %args) = @_;

    my $credentials_file = 'azure_credentials.txt';
    my $credentials = "{" . $/
      . '"clientId": "' . $self->provider_client->key_id . '", ' . $/
      . '"clientSecret": "' . $self->provider_client->key_secret . '", ' . $/
      . '"subscriptionId": "' . $self->provider_client->subscription . '", ' . $/
      . '"tenantId": "' . $self->provider_client->tenantid . '", ' . $/
      . '"activeDirectoryEndpointUrl": "https://login.microsoftonline.com", ' . $/
      . '"resourceManagerEndpointUrl": "https://management.azure.com/", ' . $/
      . '"activeDirectoryGraphResourceId": "https://graph.windows.net/", ' . $/
      . '"sqlManagementEndpointUrl": "https://management.core.windows.net:8443/", ' . $/
      . '"galleryEndpointUrl": "https://gallery.azure.com/", ' . $/
      . '"managementEndpointUrl": "https://management.core.windows.net/" ' . $/
      . '}';

    save_tmp_file($credentials_file, $credentials);
    assert_script_run('curl -O ' . autoinst_url . "/files/" . $credentials_file);

    $args{credentials_file} = $credentials_file;
    $args{instance_type} //= 'Standard_A2';
    $args{user} //= 'azureuser';
    $args{provider} //= 'azure';

    if (my $parsed_id = $self->parse_instance_id($args{instance})) {
        $args{running_instance_id} = $parsed_id->{vm_name};
    }

    return $self->run_img_proof(%args);
}

sub terraform_apply {
    my ($self, %args) = @_;
    $args{vars} //= {};
    my $offer = get_var("PUBLIC_CLOUD_AZURE_OFFER");
    my $sku = get_var("PUBLIC_CLOUD_AZURE_SKU");
    $args{vars}->{offer} = $offer if ($offer);
    $args{vars}->{sku} = $sku if ($sku);

    my @instances = $self->SUPER::terraform_apply(%args);
    $self->upload_boot_diagnostics('resource_group' => $self->get_resource_group_from_terraform_show());
    return @instances;
}

sub on_terraform_apply_timeout {
    my ($self) = @_;

    my $resgroup = $self->get_resource_group_from_terraform_show();
    return if (!defined($resgroup));

    eval { $self->upload_boot_diagnostics('resource_group' => $resgroup) }
      or record_info('Bootlog upl error', 'Failed to upload bootlog');
    assert_script_run("az group delete --yes --no-wait --name $resgroup") unless get_var('PUBLIC_CLOUD_NO_CLEANUP_ON_FAILURE');
}

sub get_resource_group_from_terraform_show {
    my $resgroup;
    my $out = script_output('terraform show -json');
    eval {
        my $json = decode_azure_json($out);
        for my $resource (@{$json->{values}->{root_module}->{resources}}) {
            next unless ($resource->{type} eq 'azurerm_resource_group');
            $resgroup = $resource->{values}->{name};
            last;
        }
    };
    if ($@ || !defined($resgroup)) {
        record_info('ERROR', "Unable to get resource-group:\n$out", result => 'fail');
    }
    return $resgroup;
}

sub upload_boot_diagnostics {
    my ($self, %args) = @_;
    return if !defined($args{resource_group});

    my $bootlog_name = '/tmp/azure-bootlog.txt';
    my $cmd_enable = 'az vm boot-diagnostics enable --ids $(az vm list -g ' . $args{resource_group} . ' --query \'[].id\' -o tsv)';
    my $out = script_output($cmd_enable, 60 * 5, proceed_on_failure => 1);
    record_info('INFO', $cmd_enable . $/ . $out);
    assert_script_run('az vm boot-diagnostics get-boot-log --ids $(az vm list -g ' . $args{resource_group} . ' --query \'[].id\' -o tsv) | jq -r "." > ' . $bootlog_name);
    upload_logs($bootlog_name, failok => 1);
}

sub on_terraform_destroy_timeout {
    my ($self) = @_;
    my $out = script_output('terraform state show azurerm_resource_group.openqa-group');
    if ($out !~ /name\s+=\s+(openqa-[a-z0-9]+)/m) {
        record_info('ERROR', 'Unable to get resource-group:' . $/ . $out, result => 'fail');
        return;
    }
    my $resgroup = $1;
    assert_script_run("az group delete --yes --no-wait --name $resgroup");
}

sub get_state_from_instance
{
    my ($self, $instance) = @_;
    my $id = $instance->instance_id();
    my $out = decode_azure_json(script_output("az vm get-instance-view --ids '$id' --query instanceView.statuses[1] --output json", quiet => 1));
    die("Expect PowerState but got " . $out->{code}) unless ($out->{code} =~ m'PowerState/(.+)$');
    return $1;
}

sub get_ip_from_instance
{
    my ($self, $instance) = @_;
    my $id = $instance->instance_id();

    my $out = decode_azure_json(script_output("az vm list-ip-addresses --ids '$id'", quiet => 1));
    return $out->[0]->{virtualMachine}->{network}->{publicIpAddresses}->[0]->{ipAddress};
}

sub stop_instance
{
    my ($self, $instance) = @_;
    # We assume that the instance_id on azure is actually the name
    # which is equal to the resource group
    # TODO maybe we need to change the azure.tf file to retrieve the id instead of the name
    my $id = $instance->instance_id();
    my $attempts = 60;

    die('Outdated instance object') if ($self->get_ip_from_instance($instance) ne $instance->public_ip);

    assert_script_run("az vm stop --ids '$id'", quiet => 1);
    while ($self->get_state_from_instance($instance) ne 'stopped' && $attempts-- > 0) {
        sleep 5;
    }
    die("Failed to stop instance $id") unless ($attempts > 0);
}

sub start_instance
{
    my ($self, $instance, %args) = @_;
    my $id = $instance->instance_id();

    die("Try to start a running instance") if ($self->get_state_from_instance($instance) ne 'stopped');

    assert_script_run("az vm start --ids '$id'", quiet => 1);
    $instance->public_ip($self->get_ip_from_instance($instance));
}

=head2
  my $parsed_id = $self->parse_instance_id($instance);
  say $parsed_id->{vm_name};
  say $parsed_id->{resource_group};

Extract resource group and vm name from full instance id which looks like
C</subscriptions/c011786b-59d7-4817-880c-7cd8a6ca4b19/resourceGroups/openqa-suse-de-1ec3f5a05b7c0712/providers/Microsoft.Compute/virtualMachines/openqa-suse-de-1ec3f5a05b7c0712>
=cut

sub parse_instance_id
{
    my ($self, $instance) = @_;

    if ($instance->instance_id() =~ m'/subscriptions/([^/]+)/resourceGroups/([^/]+)/.+/virtualMachines/(.+)$') {
        return {subscription => $1, resource_group => $2, vm_name => $3};
    }
    return;
}

=head2 cleanup
This method is called called after each test on failure or success to revoke the credentials
=cut

sub cleanup {
    my ($self) = @_;
    $self->SUPER::cleanup();
    $self->provider_client->cleanup();
}

1;
