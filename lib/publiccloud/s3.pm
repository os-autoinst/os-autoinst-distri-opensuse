# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Utils for S3 storage operations across cloud providers
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::s3;
use Mojo::Base -base;
use testapi;
use utils;
use File::Basename;

has 'provider';
has region => sub { die 'region is required' };
has azure_storage_account => undef;
has azure_storage_account_key => undef;

my %PROVIDER_CMDS = (
    EC2 => {
        bucket_uri => sub {
            my (%args) = @_;
            return $args{key} ? "s3://$args{bucket}/$args{key}" : "s3://$args{bucket}";
        },
        create_bucket => sub {
            my (%args) = @_;
            return "aws s3 mb '$args{uri}' --region '$args{region}'";
        },
        upload_file => sub {
            my (%args) = @_;
            # The cli flake container bind-mounts /root (no /tmp) on SLE 16
            return "aws s3 cp '$args{file}' '$args{uri}'";
        },
        list_bucket => sub {
            my (%args) = @_;
            return "aws s3 ls '$args{uri}/'";
        },
        download_file => sub {
            my (%args) = @_;
            # The cli flake container bind-mounts /root (no /tmp) on SLE 16
            return "aws s3 cp '$args{uri}' '$args{file}'";
        },
        delete_file => sub {
            my (%args) = @_;
            return "aws s3 rm '$args{uri}'";
        },
        delete_bucket => sub {
            my (%args) = @_;
            return "aws s3 rb '$args{uri}' --region '$args{region}'";
        },
        force_delete_bucket => sub {
            my (%args) = @_;
            return "aws s3 rb '$args{uri}' --force --region '$args{region}'";
        },
    },
    AZURE => {
        bucket_uri => sub {
            my (%args) = @_;
            return $args{bucket};
        },
        create_bucket => sub {
            my (%args) = @_;
            return "az storage container create --name '$args{bucket}' --account-name '$args{azure_storage_account}' --account-key '$args{azure_storage_account_key}'";
        },
        upload_file => sub {
            my (%args) = @_;
            return "az storage blob upload --file '$args{file}' --container-name '$args{bucket}' --name '$args{key}' --account-name '$args{azure_storage_account}' --account-key '$args{azure_storage_account_key}'";
        },
        list_bucket => sub {
            my (%args) = @_;
            return "az storage blob list --container-name '$args{bucket}' --output table --account-name '$args{azure_storage_account}' --account-key '$args{azure_storage_account_key}'";
        },
        download_file => sub {
            my (%args) = @_;
            return "az storage blob download --container-name '$args{bucket}' --name '$args{key}' --file '$args{file}' --account-name '$args{azure_storage_account}' --account-key '$args{azure_storage_account_key}'";
        },
        delete_file => sub {
            my (%args) = @_;
            return "az storage blob delete --container-name '$args{bucket}' --name '$args{key}' --account-name '$args{azure_storage_account}' --account-key '$args{azure_storage_account_key}'";
        },
        delete_bucket => sub {
            my (%args) = @_;
            return "az storage container delete --name '$args{bucket}' --account-name '$args{azure_storage_account}' --account-key '$args{azure_storage_account_key}'";
        },
        force_delete_bucket => sub {
            my (%args) = @_;
            # Azure container delete is recursive by design — removes container and all blobs.
            return "az storage container delete --name '$args{bucket}' --account-name '$args{azure_storage_account}' --account-key '$args{azure_storage_account_key}'";
        },
    },
);

=head1 METHODS

=head2 new

Create a new storage helper instance

    my $s3 = publiccloud::s3->new(provider => 'EC2', region => 'us-east-1');

Supported providers: 'EC2' (AWS S3), 'AZURE' (Azure Blob Storage)

=cut

sub new {
    my ($class, %args) = @_;
    my $provider = $args{provider} // die 'provider is required (EC2, or AZURE)';
    die("Unsupported provider: $provider") unless $PROVIDER_CMDS{$provider};
    return $class->SUPER::new(%args);
}

sub _provider_cmd {
    my ($self, $action, %args) = @_;
    # For AZURE, automatically include storage_account and storage_account_key if set
    if ($self->provider eq 'AZURE') {
        $args{azure_storage_account} = $self->azure_storage_account if $self->azure_storage_account;
        $args{azure_storage_account_key} = $self->azure_storage_account_key if $self->azure_storage_account_key;
    }
    return $PROVIDER_CMDS{$self->provider}{$action}->(%args);
}

=head2 get_bucket_uri

Generate bucket URI for the provider

    my $uri = $s3->get_bucket_uri($bucket_name);           # Returns: s3://bucket or gs://bucket
    my $uri = $s3->get_bucket_uri($bucket_name, $key);     # Returns: s3://bucket/key or gs://bucket/key

Returns the provider-specific URI format. For Azure, returns just the bucket name.

=cut

sub get_bucket_uri {
    my ($self, $bucket_name, $key) = @_;
    return $self->_provider_cmd('bucket_uri', bucket => $bucket_name, key => $key);
}

=head2 create_bucket

Create a storage bucket/container

    $s3->create_bucket($bucket_name);

=cut

sub create_bucket {
    my ($self, $bucket_name) = @_;
    die('bucket_name is required') unless $bucket_name;
    record_info('Create Bucket', "Creating bucket: $bucket_name");
    my $uri = $self->get_bucket_uri($bucket_name);
    my $cmd = $self->_provider_cmd('create_bucket', uri => $uri, bucket => $bucket_name, region => $self->region);
    assert_script_run($cmd, timeout => 120);
}

=head2 upload_file

Upload a file to a storage bucket

    $s3->upload_file(bucket => $bucket_name, file => $local_file, [key => $remote_key]);

If key is not specified, the basename of the file is used.

=cut

sub upload_file {
    my ($self, %args) = @_;

    die('bucket is required') unless $args{bucket};
    die('file is required') unless $args{file};

    my $bucket = $args{bucket};
    my $file = $args{file};
    my $key = $args{key} // basename($file);

    record_info('Upload File', "Uploading $file to $bucket/$key");

    my $uri = $self->get_bucket_uri($bucket, $key);
    my $cmd = $self->_provider_cmd('upload_file', file => $file, uri => $uri, bucket => $bucket, key => $key);
    assert_script_run($cmd, timeout => 120);
    return $key;
}

=head2 list_bucket

List contents of a storage bucket

    my $contents = $s3->list_bucket($bucket_name);

Returns the output of the list command

=cut

sub list_bucket {
    my ($self, $bucket_name) = @_;
    die('bucket_name is required') unless $bucket_name;
    record_info('List Bucket', "Listing contents of $bucket_name");
    my $uri = $self->get_bucket_uri($bucket_name);
    my $cmd = $self->_provider_cmd('list_bucket', uri => $uri, bucket => $bucket_name);
    my $contents = script_output($cmd, timeout => 120);
    return $contents;
}

=head2 download_file

Download a file from a storage bucket

    $s3->download_file(bucket => $bucket_name, key => $remote_key, file => $local_file);

=cut

sub download_file {
    my ($self, %args) = @_;

    die('bucket is required') unless $args{bucket};
    die('key is required') unless $args{key};
    die('file is required') unless $args{file};

    my $bucket = $args{bucket};
    my $key = $args{key};
    my $file = $args{file};

    record_info('Download File', "Downloading $bucket/$key to $file");

    my $uri = $self->get_bucket_uri($bucket, $key);
    my $cmd = $self->_provider_cmd('download_file', uri => $uri, bucket => $bucket, key => $key, file => $file);
    assert_script_run($cmd, timeout => 120);
}

=head2 delete_file

Delete a file from a storage bucket and verify deletion

    $s3->delete_file(bucket => $bucket_name, key => $file_key);

=cut

sub delete_file {
    my ($self, %args) = @_;

    die('bucket is required') unless $args{bucket};
    die('key is required') unless $args{key};

    my $bucket = $args{bucket};
    my $key = $args{key};

    record_info('Delete File', "Deleting $bucket/$key");

    my $uri = $self->get_bucket_uri($bucket, $key);
    my $cmd = $self->_provider_cmd('delete_file', uri => $uri, bucket => $bucket, key => $key);
    assert_script_run($cmd, timeout => 120);

    my $bucket_uri = $self->get_bucket_uri($bucket);
    my $list_cmd = $self->_provider_cmd('list_bucket', uri => $bucket_uri, bucket => $bucket);
    my $contents = script_output($list_cmd, timeout => 120);
    die("File $key still present in bucket $bucket after deletion") if ($contents =~ /\Q$key\E/);

    record_info('File Deleted', "Verified $key deleted from bucket $bucket");
}

=head2 delete_bucket

Delete a storage bucket (bucket must be empty)

    $s3->delete_bucket($bucket_name);

=cut

sub delete_bucket {
    my ($self, $bucket_name) = @_;
    die('bucket_name is required') unless $bucket_name;
    record_info('Delete Bucket', "Deleting bucket: $bucket_name");
    my $uri = $self->get_bucket_uri($bucket_name);
    my $cmd = $self->_provider_cmd('delete_bucket', uri => $uri, bucket => $bucket_name, region => $self->region);
    assert_script_run($cmd, timeout => 120);
}

=head2 force_delete_bucket

Delete a storage bucket along with any contents it still holds.

    $s3->force_delete_bucket($bucket_name);

Intended for cleanup paths where the bucket may not be empty (e.g. mid-test failure).

=cut

sub force_delete_bucket {
    my ($self, $bucket_name) = @_;
    die('bucket_name is required') unless $bucket_name;
    record_info('Force Delete Bucket', "Recursively deleting bucket: $bucket_name");
    my $uri = $self->get_bucket_uri($bucket_name);
    my $cmd = $self->_provider_cmd('force_delete_bucket', uri => $uri, bucket => $bucket_name, region => $self->region);
    assert_script_run($cmd, timeout => 240);
}

=head2 verify_file_exists

Verify that a file exists in an S3 bucket

    $s3->verify_file_exists(bucket => $bucket_name, key => $file_key);

Dies if the file is not found in the bucket listing.

=cut

sub verify_file_exists {
    my ($self, %args) = @_;

    die('bucket is required') unless $args{bucket};
    die('key is required') unless $args{key};

    my $bucket = $args{bucket};
    my $key = $args{key};

    my $contents = $self->list_bucket($bucket);
    die("File $key not found in bucket $bucket") unless ($contents =~ /\Q$key\E/);

    record_info('File Exists', "Verified $key exists in bucket $bucket");
}

=head2 verify_checksum

Verify that two files have the same SHA256 checksum

    $s3->verify_checksum(file1 => $path1, file2 => $path2);

Dies if checksums don't match.

=cut

sub verify_checksum {
    my ($self, %args) = @_;

    die('file1 is required') unless $args{file1};
    die('file2 is required') unless $args{file2};

    my $file1 = $args{file1};
    my $file2 = $args{file2};

    my ($checksum1) = split /\s+/, script_output("sha256sum '$file1'");
    record_info('Checksum', "SHA256 of $file1: $checksum1");

    my ($checksum2) = split /\s+/, script_output("sha256sum '$file2'");
    record_info('Checksum', "SHA256 of $file2: $checksum2");

    die("Checksum mismatch! File1: $checksum1, File2: $checksum2")
      unless ($checksum1 eq $checksum2);

    record_info('Checksum Match', 'File integrity verified successfully');
}

=head2 generate_unique_bucket_name

Generate a unique S3 bucket name

    my $bucket_name = $s3->generate_unique_bucket_name([$prefix]);

Generates a globally unique bucket name using a prefix (default: 'openqa-s3-test')
and timestamp. S3 bucket names must be globally unique and DNS-compliant.

=cut

sub generate_unique_bucket_name {
    my ($self, $prefix) = @_;

    $prefix //= 'openqa-s3-test';
    my $timestamp = time();
    my $bucket_name = "$prefix-$timestamp";

    record_info('Bucket Name', "Generated bucket name: $bucket_name");
    return $bucket_name;
}

1;
