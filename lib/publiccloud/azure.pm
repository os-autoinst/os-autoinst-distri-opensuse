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
use mmapi 'get_current_job_id';
use utils qw(script_output_retry);
use publiccloud::azure_client;
use publiccloud::ssh_interactive 'select_host_console';
use Data::Dumper;

has resource_group => 'openqa-upload';
has container => 'sle-images';
has image_gallery => 'test_image_gallery';
has lease_id => undef;
has storage_region => 'westeurope';

my $default_sku = 'gen2';

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

=head2 resource_group_exist

    $self->resource_group_exist();

Checks if the Azure resource group exists and returns boolean

=cut


sub resource_group_exist {
    my ($self) = @_;
    my $group = $self->resource_group;
    my $output = script_output_retry("az group show --name '$group' --output json", retry => 3, timeout => 30, delay => 10);
    return ($output ne '[]') ? 1 : 0;
}

sub get_image_id {
    my ($self, $img_url) = @_;
    $img_url //= get_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    # Very special case for Azure. if image id is not provided and OFFER is then return empty string.
    return "" if ((!$img_url) && get_var('PUBLIC_CLOUD_AZURE_OFFER'));
    return $self->SUPER::get_image_id($img_url);
}

=head2 img_blob_exists

Finds the image blob in Azure

 * Requires image name parameter, e.g. 'SLES15-SP5-BYOS.aarch64-1.0.0-Azure-Build1.68.xz'
 * Returns 0 if the image blob  has not been found or 1 if the image blob has ben found.

=cut

sub img_blob_exists {
    my ($self, $name) = @_;
    my $md5;

    my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'eisleqaopenqa');
    my $key = $self->get_storage_account_keys($storage_account);

    my $container = $self->container;

    # TODO: This is for transition period only. We used to upload blobs such as:
    # SLES15-SP5-SAP.x86_64-1.0.0-Azure-Build1.78-V1.vhd but the '-V1' at the end is not needed
    # and only makes us to upload one blob twice.
    my $gen = (check_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2')) ? 'V2' : 'V1';
    my $old_name = $name;
    $old_name =~ s/\.vhd$/-$gen.vhd/;

    # 1) Check if the image blob exists
    my $json = script_output("az storage blob show --account-key $key -o json " .
          "--container-name '$container' --account-name '$storage_account' --name '$name' " .
          '--query="{name: name,createTime: properties.creationTime,md5: properties.contentSettings.contentMd5}"',
        proceed_on_failure => 1);
    eval { $md5 = decode_azure_json($json)->{md5}; };
    if ($@) {
        record_info('BLOB NOT-FOUND', "Cannot find blob $name. Need to upload it.\n$@");
        return 0;
    } elsif (!$md5 || $md5 !~ /^[a-fA-F0-9]{32}$/) {
        record_info('BLOB INVALID', "The blob $name does not have valid md5 field.");
        return 0;
    }
    record_info('BLOB FOUND', "The blob $name has been found.");
    return 1;
}

=head2 get_image_version

Finds the image version in Azure

Returns the image version id or undef if not found.

Return example: '/subscriptions/SMTHNG-XYZ-123/resourceGroups/openqa-upload/providers/Microsoft.Compute/galleries/test_image_gallery/images/SLE-15-SP5-AZURE-BYOS-X64-GEN2/versions/1.64.100'

=cut

sub get_image_version {
    my $self = shift;
    my $image;

    my $resource_group = $self->resource_group;
    my $gallery = $self->image_gallery;
    my $version = generate_img_version();
    my $definition = $self->generate_azure_image_definition();
    my $json = script_output("az sig image-version show --resource-group '$resource_group' --gallery-name '$gallery' " .
          "--gallery-image-definition '$definition' --gallery-image-version '$version'", proceed_on_failure => 1, timeout => 60 * 30);
    record_info('IMG VER', $json);
    eval { $image = decode_azure_json($json)->{id}; };
    if ($@) {
        record_info('IMG VER NOT-FOUND', "Cannot find image-version $version in definition image definition. Need to upload it.\n$@");
        return undef;
    }
    record_info('IMG VER FOUND', "Found $image image version.");

    my $regions = decode_azure_json($json)->{publishingProfile}->{targetRegions};
    my @regions_list = map { lc($_->{name} =~ s/[-\s]//gr) } @$regions;
    if (!grep(/^$self->{provider_client}->{region}$/, @regions_list)) {
        record_info('REGION MISMATCH', 'The ' . $self->provider_client->region . ' is not listed in the targetRegions(' . join(',', @regions_list) . ') of this image version.');
        return undef;
    }
    record_info('REGION OK', 'The ' . $self->provider_client->region . ' is listed in the targetRegions(' . join(',', @regions_list) . ') of this image version.');

    return $image;
}

=head2 find_img

    my $image_id = $self->find_img($name);

Requires the image name:
 * The variable may also be URL and the name will be extracted from it.
 * The name is then used to search for the image blob.

Does the following steps:
 1) Checks if the image blob exists
 2) Checks if the image version exists

 * If the image definition does not exist the image version does not either.

Return example: '/subscriptions/SMTHNG-XYZ-123/resourceGroups/openqa-upload/providers/Microsoft.Compute/galleries/test_image_gallery/images/SLE-15-SP5-AZURE-BYOS-X64-GEN2/versions/1.64.100'
If either blob or the image version were not found then the default empty list or undef in the scalar context is returned.
=cut

sub find_img {
    my ($self, $name) = @_;

    return undef unless ($self->resource_group_exist());

    $name = $self->get_blob_name($name);

    # 1) Checks if the image blob exists
    return undef unless ($self->img_blob_exists($name));

    # 2) Check if the image version exists
    return $self->get_image_version();
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
    my $container = $self->container;
    my $timeout = 60 * 5;

    record_info('INFO', 'Create resource group ' . $self->resource_group);
    assert_script_run('az group create --name ' . $self->resource_group . ' -l ' . $self->provider_client->region, $timeout);

    record_info('INFO', 'Create storage account ' . $storage_account);
    assert_script_run('az storage account create --resource-group ' . $self->resource_group . ' -l ' . $self->storage_region
          . ' --name ' . $storage_account . ' --kind Storage --sku Standard_LRS', $timeout);

    record_info('INFO', 'Create storage container ' . $container);
    assert_script_run('az storage container create --account-name ' . $storage_account
          . ' --name ' . $container, $timeout);

    record_info('INFO', 'Create image gallery ' . $self->image_gallery);
    assert_script_run('az sig create --resource-group ' . $self->resource_group . ' --gallery-name "' . $self->image_gallery . '" --description "openQA upload Gallery"', timeout => 300);
}

=head2 generate_img_version
Build the image Version for upload to the Compute Gallery.
The expected format is 'X.Y.Z'.
We assemble the img version by the PUBLIC_CLOUD_BUILD (Format: 'X.Y') and the digits of PUBLIC_CLOUD_KIWI_BUILD, formatted as integer
=cut

sub generate_img_version {
    my $build = get_required_var('PUBLIC_CLOUD_BUILD');
    # Take only the digits of PUBLIC_CLOUD_KIWI_BUILD and convert to an int, to remove leading zeros
    my $kiwi = get_required_var('PUBLIC_CLOUD_BUILD_KIWI');
    $kiwi =~ s/\.//g;
    $kiwi = int($kiwi);
    return "$build.$kiwi";
}

sub generate_tags {
    # Define tags
    my $job_id = get_current_job_id();
    my $openqa_url = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    $openqa_url =~ s@^https?://|/$@@gm;
    my $created_by = "$openqa_url/t$job_id";
    my $tags = "'openqa_created_by=$created_by' 'openqa_var_server=$openqa_url' 'openqa_var_job_id=$job_id'";

    return $tags;
}

=head2 generate_azure_image_definition

    my $definition = $self->generate_azure_image_definition();

Generated the Azure Image name from the job settings. If present, it takes the PUBLIC_CLOUD_AZURE_IMAGE_DEFINITION setting.
If not present it generated the image definition name based on distri, version, flavor and SKU.

Note: Image definitions needs to be distinct names and can only serve one architecture!

Example: 'SLE-MICRO-5.4-BYOS-AZURE-X86_64-GEN2'
=cut

sub generate_azure_image_definition {
    my ($self) = @_;
    return get_var('PUBLIC_CLOUD_AZURE_IMAGE_DEFINITION') if (get_var('PUBLIC_CLOUD_AZURE_IMAGE_DEFINITION'));

    my $distri = get_required_var('DISTRI');
    my $version = get_required_var('VERSION');
    my $flavor = get_required_var('FLAVOR');
    my $arch = (get_var('PUBLIC_CLOUD_ARCH', get_required_var('ARCH'))) eq 'x86_64' ? 'x64' : 'Arm64';
    my $sku = get_var('PUBLIC_CLOUD_AZURE_SKU', $default_sku);
    my $image = uc("$distri-$version-$flavor-$arch-$sku");
    return $image;
}

=head2 get_image_definition
Check if the given image definition, identified by the tuple (publisher, offer and sku) is present in the given image gallery
returns the name of the found image definition or undef if not found
=cut

sub get_image_definition {
    my ($self, $resource_group, $gallery) = @_;
    my $name = $self->generate_azure_image_definition();
    record_info('get_image_definition', "Searching for image definition in gallery=$gallery under group=$resource_group with name=$name");

    my $definitions = script_output("az sig image-definition list --resource-group '$resource_group' --gallery-name '$gallery'");
    return undef unless ($definitions);
    my $json_data = decode_azure_json($definitions);
    foreach my $def (@$json_data) {
        next unless (defined $def->{name});
        if ($def->{name} eq $name) {
            record_info('image_definition', "Found $def->{name} image definition");
            return $def->{name};
        }
    }
    record_info('no image_definition', "Did not found image definition.");
    return undef;
}

=head2 get_blob_name

    Calculate the image (blob) name
    from the file name used in SUSE download server (usually PUBLIC_CLOUD_IMAGE_LOCATION)

    B<return> a string with the image name

=over 1

=item B<FILE> - filename, usually extracted from PUBLIC_CLOUD_IMAGE_LOCATION

=back
=cut

sub get_blob_name {
    my ($self, $file) = @_;

    # check if the $file is non-zero length string
    die('The image name is wrong.') unless (defined($file) && length($file) > 3);

    my ($img_name) = $file =~ /([^\/]+)$/;
    $img_name =~ s/\.xz$//;
    $img_name =~ s/\.vhdfixed/.vhd/;
    return $img_name;
}

=head2 get_blob_uri

    Calculate the image URI in the Azure Blob Server
    from the file name used in SUSE download server (usually PUBLIC_CLOUD_IMAGE_LOCATION)

    PUBLIC_CLOUD_STORAGE_ACCOUNT setting is used to compose the url

    B<return> a string with the image uri on the blob server

=over 1

=item B<FILE> - filename, usually extracted from PUBLIC_CLOUD_IMAGE_LOCATION

=back
=cut

sub get_blob_uri {
    my ($self, $file) = @_;
    my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'eisleqaopenqa');
    my $container = $self->container;
    my $img_name = $self->get_blob_name($file);

    return "https://$storage_account.blob.core.windows.net/$container/$img_name";
}

sub upload_blob {
    my ($self, $file) = @_;

    # Decompress the image
    if ($file =~ m/vhdfixed\.xz$/) {
        assert_script_run("xz -d $file", timeout => 60 * 5);
        $file =~ s/\.xz$//;
    }

    my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'eisleqaopenqa');

    my $img_name = $self->get_blob_name($file);
    my $container = $self->container;
    my $key = $self->get_storage_account_keys($storage_account);
    my $tags = generate_tags();
    # Note: VM images need to be a page blob type
    assert_script_run('az storage blob upload --max-connections 4 --type page --overwrite --no-progress'
          . " --account-name '$storage_account' --account-key '$key' --container-name '$container'"
          . " --file '$file' --name '$img_name' --tags $tags", timeout => 60 * 60 * 2);
    # After blob is uploaded we save the MD5 of it as its metadata.
    # This is also to verify that the upload has been finished.
    my $file_md5 = script_output("md5sum $file | cut -d' ' -f1", timeout => 240);
    assert_script_run("az storage blob update --account-key $key --container-name '$container' --account-name '$storage_account' --name $img_name --content-md5 $file_md5");
}

# Create new definition only, if there is no previous definition present

# This image definition can then be used by addressing it with it's
# /subscription/.../resourceGroups/openqa-upload/providers/Microsoft.Compute/galleries/...
# link.

sub create_image_definition {
    my $self = shift;
    my $resource_group = $self->resource_group;
    my $gallery = $self->image_gallery;

    # Print image definitions as a help to debug possible conflicting definitions
    my $images = script_output("az sig image-definition list -g '$resource_group' -r '$gallery'");
    record_info("img-defs", "Existing image definitions:\n$images");

    my $sku = get_var("PUBLIC_CLOUD_AZURE_SKU", $default_sku);
    my $gen = ($sku =~ "gen2" ? "V2" : "V1");
    my $tags = generate_tags();

    my $arch = (get_var('PUBLIC_CLOUD_ARCH', get_required_var('ARCH'))) eq 'x86_64' ? 'x64' : 'Arm64';
    my $publisher = get_var("PUBLIC_CLOUD_AZURE_PUBLISHER", "qe-c");
    my $offer = get_var("PUBLIC_CLOUD_AZURE_OFFER", get_var('DISTRI') . '-' . get_var('VERSION') . '-' . get_var('FLAVOR') . '-' . $arch);

    my $definition = $self->get_image_definition($resource_group, $gallery);
    if (defined $definition) {
        record_info("use img-def", "Using found image definitions:\n$definition");
    } else {
        $definition = $self->generate_azure_image_definition();
        record_info("gen img-def", "Create image definitions:\n$definition");
        assert_script_run("az sig image-definition create --resource-group '$resource_group' --gallery-name '$gallery' " .
              "--gallery-image-definition '$definition' --os-type Linux --publisher '$publisher' --offer '$offer' --sku '$sku' " .
              "--architecture '$arch' --hyper-v-generation '$gen' --os-state 'Generalized' --location " . $self->storage_region, timeout => 300);
    }
}

sub create_image_version {
    my ($self, $file) = @_;

    my $resource_group = $self->resource_group;
    my $gallery = $self->image_gallery;

    my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'eisleqaopenqa');

    my $subscription = $self->provider_client->subscription;
    my $sa_url = "/subscriptions/$subscription/resourceGroups/imageGroups/providers/Microsoft.Storage/storageAccounts/$storage_account";

    my $definition = $self->get_image_definition($resource_group, $gallery);
    my $version = generate_img_version();
    my $os_vhd_uri = $self->get_blob_uri($file);
    my $tags = generate_tags();
    my $target_regions = ($self->provider_client->region !~ $self->storage_region) ? $self->provider_client->region . ' ' . $self->storage_region : $self->provider_client->region;
    # Note: Repetitive calls do not fail
    assert_script_run("az sig image-version create --debug --resource-group '$resource_group' --gallery-name '$gallery' " .
          "--gallery-image-definition '$definition' --gallery-image-version '$version' --os-vhd-storage-account '$sa_url' " .
          "--os-vhd-uri $os_vhd_uri --target-regions $target_regions --location " . $self->storage_region, timeout => 60 * 30);
}

=head2 upload_img

1) Create resources
2) Upload the image blob
3) Create image definition
4) Create new image version for that definition. Use the link to the uploaded blob to create this version

=cut

sub upload_img {
    my ($self, $file) = @_;

    # 1) Create resources
    $self->create_resources() unless ($self->resource_group_exist());

    # 2) Upload the image blob
    $self->upload_blob($file);

    # 3) Ensure the image definition exists
    $self->create_image_definition();

    # 4) Create new image version for that definition. Use the link to the uploaded blob to create this version
    $self->create_image_version($file);
}

sub img_proof {
    my ($self, %args) = @_;

    my $credentials_file = 'azure_credentials.txt';

    save_tmp_file($credentials_file, $self->provider_client->credentials_file_content);
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
    my ($self, $args) = @_;
    select_host_console(force => 1);

    $self->get_image_version() if (get_var('PUBLIC_CLOUD_BUILD'));

    if (defined($args->{my_instance}->{instance_id})) {
        my $id = $args->{my_instance}->{instance_id};
        script_run("az vm boot-diagnostics get-boot-log --ids $id | jq -r '.' > bootlog.txt", timeout => 120, die_on_timeout => 0);
        upload_logs("bootlog.txt", failok => 1);
    }
    $self->SUPER::cleanup();
}

1;
