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

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    assert_script_run('az login --service-principal -u ' . $self->key_id . ' -p '
          . $self->key_secret . ' -t ' . $self->tenantid);
    assert_script_run("export ARM_SUBSCRIPTION_ID=" . $self->subscription);
    assert_script_run("export ARM_CLIENT_ID=" . $self->key_id);
    assert_script_run("export ARM_CLIENT_SECRET=" . $self->key_secret);
    assert_script_run('export ARM_TENANT_ID="' . $self->tenantid . '"');
    assert_script_run('export ARM_ENVIRONMENT="public"');
    assert_script_run('export ARM_TEST_LOCATION="' . $self->region . '"');
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

1;
