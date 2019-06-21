# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: helper class for azure
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::azure;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper;
use testapi;

has tenantid        => undef;
has subscription    => undef;
has resource_group  => 'openqa-upload';
has storage_account => 'openqa';
has container       => 'sle-images';
has lease_id        => undef;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->vault_create_credentials() unless ($self->key_id);
    $self->az_login();
    assert_script_run("export ARM_SUBSCRIPTION_ID=" . $self->subscription);
    assert_script_run("export ARM_CLIENT_ID=" . $self->key_id);
    assert_script_run("export ARM_CLIENT_SECRET=" . $self->key_secret);
    assert_script_run('export ARM_TENANT_ID="' . $self->tenantid . '"');
    assert_script_run('export ARM_ENVIRONMENT="public"');
    assert_script_run('export ARM_TEST_LOCATION="' . $self->region . '"');
}

sub az_login {
    my ($self)    = @_;
    my $max_tries = 3;
    my $login_cmd = sprintf('az login --service-principal -u %s -p %s -t %s',
        $self->key_id, $self->key_secret, $self->tenantid);

    for (1 .. $max_tries) {
        my $ret = script_run($login_cmd);
        return 1 if (defined($ret) && $ret == 0);
        sleep 30;
    }
    die("Azure login failed!");
}

sub vault_create_credentials {
    my ($self) = @_;

    record_info('INFO', 'Get credentials from VAULT server.');
    my $res = $self->vault_api('/v1/azure/creds/openqa-role', method => 'get');
    $self->vault_lease_id($res->{lease_id});
    $self->key_id($res->{data}->{client_id});
    $self->key_secret($res->{data}->{client_secret});

    $res = $self->vault_api('/v1/secret/azure/openqa-role', method => 'get');
    $self->tenantid($res->{data}->{tenant_id});
    $self->subscription($res->{data}->{subscription_id});

    for my $i (('key_id', 'key_secret', 'tenantid', 'subscription')) {
        die("Failed to retrieve key - missing $i") unless (defined($self->$i));
    }
}

sub resource_exist {
    my ($self) = @_;
    my $output = script_output(q(az group list --query "[?name=='openqa-upload']"));
    return ($output ne '[]');
}

sub find_img {
    my ($self, $name) = @_;

    return if (!$self->resource_exist());

    ($name) = $name =~ m/([^\/]+)$/;
    $name =~ s/\.xz$//;
    $name =~ s/\.vhdfixed$/.vhd/;
    my $json = script_output("az image show --resource-group " . $self->resource_group . " --name $name", 60, proceed_on_failure => 1);
    record_info('INFO', $json);
    eval {
        my $image = decode_json($json);
        return $image->{name};
    };
}

sub get_storage_account_keys {
    my ($self, %args) = @_;
    my $output = script_output("az storage account keys list --resource-group "
          . $self->resource_group . " --account-name " . $self->storage_account);
    my $json = decode_json($output);
    my $key  = undef;
    if (@{$json} > 0) {
        $key = $json->[0]->{value};
    }
    die("Storage account key not found!") unless $key;
    return $key;
}

sub create_resources {
    my ($self) = @_;
    my $timeout = 60 * 5;
    record_info('INFO', 'Create resource group ' . $self->resource_group);
    assert_script_run('az group create --name ' . $self->resource_group . ' -l ' . $self->region, $timeout);
    record_info('INFO', 'Create storage account ' . $self->storage_account);
    assert_script_run('az storage account create --resource-group ' . $self->resource_group . ' -l '
          . $self->region . ' --name ' . $self->storage_account . ' --kind Storage --sku Standard_LRS', $timeout);
    my $key = $self->get_storage_account_keys($self->resource_group, $self->storage_account);
    record_info('INFO', 'Create storage container ' . $self->container);
    assert_script_run('az storage container create --account-name ' . $self->storage_account
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

    my $rg_exist = $self->resource_exist();

    $self->create_resources() if (!$rg_exist);

    my $key = $self->get_storage_account_keys();

    assert_script_run('az storage blob upload --max-connections 4 --account-name '
          . $self->storage_account . ' --account-key ' . $key . ' --container-name ' . $self->container
          . ' --type page --file ' . $file . ' --name ' . $img_name, timeout => 60 * 60 * 2);
    assert_script_run('az disk create --resource-group ' . $self->resource_group . ' --name ' . $disk_name
          . ' --source https://' . $self->storage_account . '.blob.core.windows.net/' . $self->container . '/' . $img_name);

    assert_script_run('az image create --resource-group ' . $self->resource_group . ' --name ' . $img_name
          . ' --os-type Linux --source=' . $disk_name);

    return $img_name;
}

sub ipa {
    my ($self, %args) = @_;

    my $credentials_file = 'azure_credentials.txt';
    my $credentials      = "{" . $/
      . '"clientId": "' . $self->key_id . '", ' . $/
      . '"clientSecret": "' . $self->key_secret . '", ' . $/
      . '"subscriptionId": "' . $self->subscription . '", ' . $/
      . '"tenantId": "' . $self->tenantid . '", ' . $/
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
    $args{user}          //= 'azureuser';
    $args{provider}      //= 'azure';

    return $self->run_ipa(%args);
}

sub on_terraform_timeout {
    my ($self) = @_;
    my $out = script_output('terraform state show azurerm_resource_group.openqa-group');
    if ($out !~ /name\s+=\s+(openqa-[a-z0-9]+)/m) {
        record_info('ERROR', 'Unable to get resource-group:' . $/ . $out, result => 'fail');
        return;
    }
    my $resgroup = $1;

    my $tries = 3;
    while ($tries gt 0) {
        $tries = $tries - 1;
        eval {
            my $bootlog_name = '/tmp/azure-bootlog.txt';
            my $cmd_enable = 'az vm boot-diagnostics enable --ids $(az vm list -g ' . $resgroup . ' --query \'[].id\' -o tsv) --storage ' . $self->storage_account;
            $out = script_output($cmd_enable, 60 * 5, proceed_on_failure => 1);
            record_info('INFO', $cmd_enable . $/ . $out);
            script_run('az vm boot-diagnostics get-boot-log --ids $(az vm list -g ' . $resgroup . ' --query \'[].id\' -o tsv) > ' . $bootlog_name);
            upload_logs($bootlog_name, failok => 1);
            $tries = 0;
        };
        if ($@) {
            type_string(qq(\c\\));
        }
    }

    assert_script_run("az group delete --yes --no-wait --name $resgroup");
}

sub get_state_from_instance
{
    my ($self, $instance) = @_;
    my $name = $instance->instance_id();
    my $out = decode_json(script_output("az vm get-instance-view --name $name --resource-group $name --query instanceView.statuses[1] --output json", quiet => 1));
    die("Expect PowerState but got " . $out->{code}) unless ($out->{code} =~ m'PowerState/(.+)$');
    return $1;
}

sub get_ip_from_instance
{
    my ($self, $instance) = @_;
    my $name = $instance->instance_id();

    my $out = decode_json(script_output("az vm list-ip-addresses --name $name --resource-group $name", quiet => 1));
    return $out->[0]->{virtualMachine}->{network}->{publicIpAddresses}->[0]->{ipAddress};
}

sub stop_instance
{
    my ($self, $instance) = @_;
    # We assume that the instance_id on azure is actually the name
    # which is equal to the resource group
    # TODO maybe we need to change the azure.tf file to retrieve the id instead of the name
    my $name     = $instance->instance_id();
    my $attempts = 60;

    die('Outdated instance object') if ($self->get_ip_from_instance($instance) ne $instance->public_ip);

    assert_script_run("az vm stop --resource-group $name --name $name", quiet => 1);
    while ($self->get_state_from_instance($instance) ne 'stopped' && $attempts-- > 0) {
        sleep 5;
    }
    die("Failed to stop instance $name") unless ($attempts > 0);
}

sub start_instance
{
    my ($self, $instance, %args) = @_;
    my $name = $instance->instance_id();

    die("Try to start a running instance") if ($self->get_state_from_instance($instance) ne 'stopped');

    assert_script_run("az vm start --name $name --resource-group $name", quiet => 1);
    $instance->public_ip($self->get_ip_from_instance($instance));
}

1;
