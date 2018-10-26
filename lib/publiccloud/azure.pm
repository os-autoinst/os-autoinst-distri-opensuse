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
use testapi;

has tenantid     => undef;
has subscription => undef;

sub init {
    my ($self) = @_;

    assert_script_run('az login --service-principal -u ' . $self->key_id . ' -p '
          . $self->key_secret . ' -t ' . $self->tenantid);
}

sub filename_to_resgroup {
    my ($self, $name) = @_;

    ($name) = $name =~ m/([^\/]+)$/;
    $name =~ s/\.xz$//;
    $name =~ s/\.vhdfixed$/.vhd/;
    $name = $self->prefix . "-" . $name;
    return $name;
}

sub find_resgroup {
    my ($self, $name) = @_;

    my $jgroups = decode_json(script_output("az group list"));
    for my $g (@{$jgroups}) {
        if ($name eq $g->{name}) {
            return $name;
        }
    }

    return;
}

sub find_img {
    my ($self, $name) = @_;

    $name = $self->filename_to_resgroup($name);
    return unless $self->find_resgroup($name);

    my $images = decode_json(script_output("az image list --resource-group '$name'"));

    #retrives the first image of the resource group
    return $images->[0]->{name} if (@{$images});
    return;
}

sub upload_img {
    my ($self, $file) = @_;

    if ($file =~ m/vhdfixed\.xz$/) {
        assert_script_run("xz -d $file", timeout => 60 * 5);
        $file =~ s/\.xz$//;
    }

    my $suffix = time();
    my ($img_name) = $file =~ /([^\/]+)$/;
    $img_name =~ s/\.vhdfixed/.vhd/;

    my $group     = $self->filename_to_resgroup($file);
    my $acc       = $self->prefix . "-" . $suffix;
    my $container = $self->prefix . "-" . $suffix;
    my $disk_name = $self->prefix . "-" . $suffix;

    $acc = uc($acc);
    $acc =~ s/[^\da-z]//g;
    $acc = substr($acc, 0, 24);

    assert_script_run("az group create --name $group -l " . $self->region);

    assert_script_run("az storage account create --resource-group $group "
          . "-l " . $self->region . " --name $acc --kind Storage --sku Standard_LRS");

    my $output = script_output("az storage account keys list "
          . "--resource-group $group --account-name $acc");
    my $json = decode_json($output);
    my $key  = undef;
    if (@{$json} > 0) {
        $key = $json->[0]->{value};
    }
    die("Storage account key not found!") unless $key;

    assert_script_run("az storage container create --account-name $acc "
          . "--name $container");

    assert_script_run("az storage blob upload --max-connections 4 "
          . "--account-name $acc --account-key $key --container-name $container "
          . "--type page --file '$file' --name $img_name", timeout => 60 * 60 * 2);
    assert_script_run("az disk create --resource-group $group --name $disk_name "
          . "--source https://$acc.blob.core.windows.net/$container/$img_name");

    assert_script_run("az image create --resource-group $group --name $img_name "
          . "--os-type Linux --source='$disk_name'");

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
