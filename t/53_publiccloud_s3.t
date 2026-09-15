# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Unit tests for publiccloud::s3
# Maintainer: QE-C team <qa-c@suse.de>

use strict;
use warnings;
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Test::Exception;
use Test::Warnings;

use publiccloud::s3;

# Silence record_info by default across all subtests
my $s3mod = Test::MockModule->new('publiccloud::s3', no_auto => 1);
$s3mod->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

sub _ec2 { publiccloud::s3->new(provider => 'EC2', region => 'us-east-1') }

sub _azure {
    publiccloud::s3->new(
        provider => 'AZURE',
        region => 'westeurope',
        azure_storage_account => 'acct1',
        azure_storage_account_key => 'k3y==',
    );
}

subtest '[new] validates provider' => sub {
    throws_ok { publiccloud::s3->new() } qr/provider is required/, 'dies without provider';
    throws_ok { publiccloud::s3->new(provider => 'GCE') } qr/Unsupported provider: GCE/, 'dies on unsupported provider';
    isa_ok(_ec2(), 'publiccloud::s3', 'EC2 provider accepted');
    isa_ok(_azure(), 'publiccloud::s3', 'AZURE provider accepted');
};

subtest '[region] required at access time' => sub {
    my $s3 = publiccloud::s3->new(provider => 'EC2');
    throws_ok { $s3->region } qr/region is required/, 'accessing region without setting dies';
};

subtest '[get_bucket_uri] EC2 shape' => sub {
    my $s3 = _ec2();
    is($s3->get_bucket_uri('mybucket'), 's3://mybucket', 'bucket only');
    is($s3->get_bucket_uri('mybucket', 'path/to/key'), 's3://mybucket/path/to/key', 'bucket + key');
};

subtest '[get_bucket_uri] AZURE shape returns bare bucket' => sub {
    my $s3 = _azure();
    is($s3->get_bucket_uri('mybucket'), 'mybucket', 'bucket only');
    is($s3->get_bucket_uri('mybucket', 'blob.txt'), 'mybucket', 'key is ignored');
};

subtest '[create_bucket] EC2 composes aws s3 mb with region' => sub {
    my $s3 = _ec2();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->create_bucket('mybucket');
    like($seen, qr{aws s3 mb 's3://mybucket'}, 'uses s3 mb with s3 uri');
    like($seen, qr{--region 'us-east-1'}, 'passes region');
};

subtest '[create_bucket] AZURE composes az storage container create' => sub {
    my $s3 = _azure();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->create_bucket('mybucket');
    like($seen, qr{az storage container create --name 'mybucket'}, 'creates container by name');
    like($seen, qr{--account-name 'acct1'}, 'passes storage account');
    like($seen, qr{--account-key 'k3y=='}, 'passes storage account key');
};

subtest '[create_bucket] dies without bucket_name' => sub {
    throws_ok { _ec2()->create_bucket() } qr/bucket_name is required/, 'dies on missing bucket_name';
};

subtest '[upload_file] EC2 composes aws s3 cp' => sub {
    my $s3 = _ec2();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    my $key = $s3->upload_file(bucket => 'b', file => '/root/hello.txt', key => 'hi.txt');
    is($key, 'hi.txt', 'returns the explicit key');
    like($seen, qr{aws s3 cp '/root/hello.txt' 's3://b/hi.txt'}, 'cp local to s3 uri');
};

subtest '[upload_file] AZURE composes az storage blob upload' => sub {
    my $s3 = _azure();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->upload_file(bucket => 'b', file => '/root/hello.txt', key => 'hi.txt');
    like($seen, qr{az storage blob upload --file '/root/hello.txt'}, 'uploads local file');
    like($seen, qr{--container-name 'b'}, 'targets container');
    like($seen, qr{--name 'hi.txt'}, 'targets blob name');
    like($seen, qr{--account-name 'acct1'}, 'passes account');
};

subtest '[upload_file] key defaults to basename' => sub {
    my $s3 = _ec2();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    my $key = $s3->upload_file(bucket => 'b', file => '/root/dir/hello.txt');
    is($key, 'hello.txt', 'basename used when key omitted');
    like($seen, qr{'s3://b/hello.txt'}, 's3 uri built from basename');
};

subtest '[upload_file] dies on missing required args' => sub {
    my $s3 = _ec2();
    throws_ok { $s3->upload_file(file => '/f') } qr/bucket is required/, 'dies without bucket';
    throws_ok { $s3->upload_file(bucket => 'b') } qr/file is required/, 'dies without file';
};

subtest '[list_bucket] EC2 composes aws s3 ls and returns output' => sub {
    my $s3 = _ec2();
    my $seen;
    $s3mod->redefine(script_output => sub { $seen = $_[0]; return "2026-01-01 hi.txt\n" });
    my $out = $s3->list_bucket('mybucket');
    like($seen, qr{aws s3 ls 's3://mybucket/'}, 'lists bucket with trailing slash');
    like($out, qr/hi\.txt/, 'returns listing verbatim');
};

subtest '[list_bucket] AZURE composes az storage blob list' => sub {
    my $s3 = _azure();
    my $seen;
    $s3mod->redefine(script_output => sub { $seen = $_[0]; return '' });
    $s3->list_bucket('mybucket');
    like($seen, qr{az storage blob list --container-name 'mybucket'}, 'lists container');
    like($seen, qr{--output table}, 'uses table output');
    like($seen, qr{--account-name 'acct1'}, 'passes account');
};

subtest '[list_bucket] dies without bucket_name' => sub {
    throws_ok { _ec2()->list_bucket() } qr/bucket_name is required/, 'dies without bucket_name';
};

subtest '[download_file] EC2 composes aws s3 cp from s3' => sub {
    my $s3 = _ec2();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->download_file(bucket => 'b', key => 'hi.txt', file => '/root/hi.txt');
    like($seen, qr{aws s3 cp 's3://b/hi.txt' '/root/hi.txt'}, 'cp s3 uri to local file');
};

subtest '[download_file] AZURE composes az storage blob download' => sub {
    my $s3 = _azure();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->download_file(bucket => 'b', key => 'hi.txt', file => '/root/hi.txt');
    like($seen, qr{az storage blob download --container-name 'b'}, 'targets container');
    like($seen, qr{--name 'hi.txt'}, 'targets blob');
    like($seen, qr{--file '/root/hi.txt'}, 'writes to local file');
};

subtest '[download_file] dies on missing required args' => sub {
    my $s3 = _ec2();
    throws_ok { $s3->download_file(key => 'k', file => '/f') } qr/bucket is required/, 'dies without bucket';
    throws_ok { $s3->download_file(bucket => 'b', file => '/f') } qr/key is required/, 'dies without key';
    throws_ok { $s3->download_file(bucket => 'b', key => 'k') } qr/file is required/, 'dies without file';
};

subtest '[delete_file] EC2 issues aws s3 rm then verifies via listing' => sub {
    my $s3 = _ec2();
    my @asr;
    $s3mod->redefine(assert_script_run => sub { push @asr, $_[0]; return 0 });
    # After deletion, listing must not contain the key
    $s3mod->redefine(script_output => sub { return "2026-01-01 other.txt\n" });

    lives_ok { $s3->delete_file(bucket => 'b', key => 'hi.txt') } 'deletes and verifies';
    ok((grep { m{aws s3 rm 's3://b/hi\.txt'} } @asr), 'issues aws s3 rm');
};

subtest '[delete_file] dies when file still present after delete' => sub {
    my $s3 = _ec2();
    $s3mod->redefine(assert_script_run => sub { 0 });
    $s3mod->redefine(script_output => sub { return "2026-01-01 hi.txt\n" });

    throws_ok { $s3->delete_file(bucket => 'b', key => 'hi.txt') }
    qr/hi\.txt still present in bucket b/, 'dies when listing still shows key';
};

subtest '[delete_file] dies on missing required args' => sub {
    my $s3 = _ec2();
    throws_ok { $s3->delete_file(key => 'k') } qr/bucket is required/, 'dies without bucket';
    throws_ok { $s3->delete_file(bucket => 'b') } qr/key is required/, 'dies without key';
};

subtest '[delete_bucket] EC2 composes aws s3 rb' => sub {
    my $s3 = _ec2();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->delete_bucket('mybucket');
    like($seen, qr{aws s3 rb 's3://mybucket'}, 'removes bucket');
    like($seen, qr{--region 'us-east-1'}, 'passes region');
    unlike($seen, qr/--force/, 'no --force on plain delete');
};

subtest '[delete_bucket] AZURE composes az storage container delete' => sub {
    my $s3 = _azure();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->delete_bucket('mybucket');
    like($seen, qr{az storage container delete --name 'mybucket'}, 'deletes container');
    like($seen, qr{--account-name 'acct1'}, 'passes account');
};

subtest '[delete_bucket] dies without bucket_name' => sub {
    throws_ok { _ec2()->delete_bucket() } qr/bucket_name is required/, 'dies without bucket_name';
};

subtest '[force_delete_bucket] EC2 adds --force' => sub {
    my $s3 = _ec2();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->force_delete_bucket('mybucket');
    like($seen, qr{aws s3 rb 's3://mybucket' --force}, 'uses --force to remove non-empty bucket');
    like($seen, qr{--region 'us-east-1'}, 'passes region');
};

subtest '[force_delete_bucket] AZURE uses container delete (recursive by design)' => sub {
    my $s3 = _azure();
    my $seen;
    $s3mod->redefine(assert_script_run => sub { $seen = $_[0]; return 0 });
    $s3->force_delete_bucket('mybucket');
    like($seen, qr{az storage container delete --name 'mybucket'}, 'deletes container');
};

subtest '[force_delete_bucket] dies without bucket_name' => sub {
    throws_ok { _ec2()->force_delete_bucket() } qr/bucket_name is required/, 'dies without bucket_name';
};

subtest '[verify_file_exists] passes when listing contains key' => sub {
    my $s3 = _ec2();
    $s3mod->redefine(script_output => sub { "2026-01-01 hi.txt\n" });
    lives_ok { $s3->verify_file_exists(bucket => 'b', key => 'hi.txt') } 'passes when key present';
};

subtest '[verify_file_exists] dies when key not present' => sub {
    my $s3 = _ec2();
    $s3mod->redefine(script_output => sub { "2026-01-01 other.txt\n" });
    throws_ok { $s3->verify_file_exists(bucket => 'b', key => 'hi.txt') }
    qr/hi\.txt not found in bucket b/, 'dies when listing lacks key';
};

subtest '[verify_file_exists] dies on missing required args' => sub {
    my $s3 = _ec2();
    throws_ok { $s3->verify_file_exists(key => 'k') } qr/bucket is required/, 'dies without bucket';
    throws_ok { $s3->verify_file_exists(bucket => 'b') } qr/key is required/, 'dies without key';
};

subtest '[verify_checksum] passes on match' => sub {
    my $s3 = _ec2();
    # First and second sha256sum calls return the same digest
    $s3mod->redefine(script_output => sub { 'beetroot  /some/file' });
    lives_ok { $s3->verify_checksum(file1 => '/a', file2 => '/b') } 'matching checksums pass';
};

subtest '[verify_checksum] dies on mismatch' => sub {
    my $s3 = _ec2();
    my @sums = ('aaaa1111  /a', 'bbbb2222  /b');
    $s3mod->redefine(script_output => sub { shift @sums });
    throws_ok { $s3->verify_checksum(file1 => '/a', file2 => '/b') }
    qr/Checksum mismatch.*aaaa1111.*bbbb2222/, 'dies with both digests in message';
};

subtest '[verify_checksum] dies on missing required args' => sub {
    my $s3 = _ec2();
    throws_ok { $s3->verify_checksum(file2 => '/b') } qr/file1 is required/, 'dies without file1';
    throws_ok { $s3->verify_checksum(file1 => '/a') } qr/file2 is required/, 'dies without file2';
};

subtest '[generate_unique_bucket_name] default and custom prefix' => sub {
    my $s3 = _ec2();
    my $default = $s3->generate_unique_bucket_name();
    like($default, qr/^openqa-s3-test-\d+$/, 'default prefix + numeric timestamp');

    my $custom = $s3->generate_unique_bucket_name('my-prefix');
    like($custom, qr/^my-prefix-\d+$/, 'custom prefix respected');
};

done_testing;
