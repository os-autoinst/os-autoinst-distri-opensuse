use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi 'set_var';

use publiccloud::azure;

subtest '[get_image_name]' => sub {
    my $provider = publiccloud::azure->new();
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');
    my $res = $provider->get_image_name('SOMETHING.vhdfixed.xz');
    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
    is $res, 'SOMETHING-V2.vhd', "The image name is properly composed";
};

subtest '[get_image_name] without .xz' => sub {
    my $provider = publiccloud::azure->new();
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');
    my $res = $provider->get_image_name('SOMETHING.vhdfixed');
    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
    is $res, 'SOMETHING-V2.vhd', "The image name is properly composed";
};

subtest '[get_image_name] with URL' => sub {
    my $provider = publiccloud::azure->new();
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');
    my $res = $provider->get_image_name('https://download.somewhere.org/SUSE:/SLE-15-SP5:/Update:/PubClouds/images/SOMETHING.vhdfixed.xz');
    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
    is $res, 'SOMETHING-V2.vhd', "The image name is properly composed";
};

subtest '[get_os_vhd_uri]' => sub {
    my $provider = publiccloud::azure->new();
    set_var('PUBLIC_CLOUD_AZURE_SKU', 'gen2');
    set_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', 'SOMEWHERE');
    my $res = $provider->get_os_vhd_uri('SOMETHING.vhdfixed.xz');
    set_var('PUBLIC_CLOUD_AZURE_SKU', undef);
    set_var('PUBLIC_CLOUD_STORAGE_ACCOUNT', undef);
    is $res, 'https://SOMEWHERE.blob.core.windows.net/sle-images/SOMETHING-V2.vhd', "The image uri is properly composed";
};

done_testing;
