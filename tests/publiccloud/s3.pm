# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Cloud storage S3-compatible API smoke test (AWS S3, Azure Blob)
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::s3;
use testapi;
use utils;
use mmapi 'get_current_job_id';
use publiccloud::utils 'calculate_custodian_ttl';

my $bucket_name;
my $s3;
my $azure_resource_group;
my $azure_storage_account;
my $azure_storage_account_key;

sub run {
    my ($self, $args) = @_;

    select_host_console();

    my $provider = $self->provider_factory();
    my $cloud_provider = get_required_var('PUBLIC_CLOUD_PROVIDER');

    my $job_id = get_current_job_id();
    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $openqa_url = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    my $custodian_ttl = calculate_custodian_ttl($openqa_ttl);
    my $tags = "openqa_var_job_id=$job_id custodian_ttl=$custodian_ttl openqa_created_by=$openqa_url/t$job_id";

    # Azure-specific: Create ResourceGroup and StorageAccount
    if ($cloud_provider eq 'AZURE') {

        $azure_resource_group = "openqa-s3-test-rg-$job_id";
        $azure_storage_account = "openqas3test$job_id";

        record_info('Create ResourceGroup', "Creating resource group: $azure_resource_group");
        assert_script_run("az group create -n $azure_resource_group -l " . $provider->provider_client->region . " --tags $tags", timeout => 300);

        # Azure S3 buckets (containers) can only be created inside a storage account
        record_info('Create StorageAccount', "Creating storage account: $azure_storage_account");
        assert_script_run("az storage account create --resource-group $azure_resource_group -l " . $provider->provider_client->region .
              " --name $azure_storage_account --kind StorageV2 --sku Standard_LRS", timeout => 300);

        # Get storage account key for authentication
        # Suppress stderr to avoid Python warnings in the output
        $azure_storage_account_key = script_output("az storage account keys list --resource-group $azure_resource_group --account-name $azure_storage_account 2>/dev/null | jq -r '.[0].value'");
        die("Failed to retrieve Azure storage account key") unless $azure_storage_account_key;
    }

    # Initialize S3 helper
    $s3 = publiccloud::s3->new(
        provider => $cloud_provider,
        region => $provider->provider_client->region,
        ($cloud_provider eq 'AZURE' ? (
                azure_storage_account => $azure_storage_account,
                azure_storage_account_key => $azure_storage_account_key
        ) : ())
    );

    # Generate unique bucket name
    $bucket_name = $s3->generate_unique_bucket_name();

    # Create test data file
    # On SLE 16 the CLI is a flake container that only mounts /root
    # so the files must be saved to /root
    my $test_file = '/root/hello-suse.txt';
    my $test_file_key = 'hello-suse.txt';    # Key as in S3 Object Key
    assert_script_run("echo geeko123 > $test_file");

    # Create bucket and upload file
    $s3->create_bucket($bucket_name);
    $s3->upload_file(bucket => $bucket_name, file => $test_file, key => $test_file_key);

    # List bucket contents and verify file exists
    $s3->verify_file_exists(bucket => $bucket_name, key => $test_file_key);

    # Download file and verify checksum
    my $downloaded_file = "$test_file-downloaded";
    $s3->download_file(bucket => $bucket_name, key => $test_file_key, file => $downloaded_file);
    $s3->verify_checksum(file1 => $test_file, file2 => $downloaded_file);

    # Delete file and bucket
    $s3->delete_file(bucket => $bucket_name, key => $test_file_key);
    $s3->delete_bucket($bucket_name);

    # Clean up downloaded files
    assert_script_run("rm -f $downloaded_file $test_file");

    record_info('Test Complete', "$cloud_provider S3-compatible storage smoke test completed successfully");
}

sub cleanup {
    # For Azure, delete the entire resource group (removes storage account, containers, and blobs)
    if ($azure_resource_group) {
        eval { script_run("az group delete --resource-group $azure_resource_group --yes", timeout => 360) };
        record_info('Azure cleanup failed', $@, result => 'softfail') if $@;
        return;
    }

    # For EC2, delete individual bucket
    return unless $s3 && $bucket_name;
    eval { $s3->force_delete_bucket($bucket_name) };
    record_info('Cleanup failed', $@, result => 'softfail') if $@;
}

sub post_run_hook { cleanup() }
sub post_fail_hook { cleanup() }

1;
