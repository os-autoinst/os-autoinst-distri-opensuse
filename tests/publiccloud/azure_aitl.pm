# SUSE's openQA tests
#
# Copyright 2021-2024 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create VM in Azure using azure-cli binary
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';
use utils qw(zypper_call script_retry);
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();

    # If 'az' is preinstalled, we test that version
    if (script_run("which az") != 0) {
        add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef));
        add_suseconnect_product(get_addon_fullname('phub')) if is_sle('=12-sp5');
        zypper_call('in azure-cli jq python311 python3-susepubliccloudinfo ');
    }
    assert_script_run('az version');

    my $provider = $self->provider_factory();
    
    my $image_url = get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    my $region = get_var('PUBLIC_CLOUD_REGION', 'westeurope');
    my $resource_group = "openqa-aitl-$job_id";
    my $subscription_id = $provider->provider_client->subscription;

    my $aitl_image_gallery = "test_image_gallery";
    my $aitl_image_version = "latest";
    my $aitl_job_name = "openqa-aitl-$job_id";
    my $aitl_manifest = "shared_gallery.json";
    my ($aitl_image_name) = $image_url =~ /(?!.*\/)(?<image>.*)(?=\.\w+\.)/; # 1st group matches the URL up to the start of the name, 2nd group is the name, 3rd group is the file type. We drop groups 1 and 3.

    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $openqa_url = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    my $created_by = "$openqa_url/t$job_id";
    my $tags = "openqa-aitl=$job_id openqa_created_by=$created_by openqa_var_server=$openqa_url";
    
    # Get the AITL script
    assert_script_run("curl https://raw.githubusercontent.com/microsoft/lisa/refs/heads/main/microsoft/utils/aitl/aitl.py -o /tmp/aitl.py");

    # Configure default location and create Resource group
    assert_script_run("az configure --defaults location=$region");
    assert_script_run("az group create -n $resource_group --tags '$tags'");

    # Get manifest from data folder
    assert_script_run ("curl " . data_url("publiccloud/aitl/$aitl_manifest") . " -o /tmp/$aitl_manifest");
    assert_script_run ("sed -i -e 's/<IMAGE_NAME>/$aitl_image_name/g' -e 's/<IMAGE_VERSION>/$aitl_image_version/g' -e 's/<IMAGE_GALLERY_NAME>/$aitl_image_gallery/g' /tmp/$aitl_manifest");

    # Create AITL Job based on a manifest
    record_info ("$aitl_manifest", "cat /tmp/$aitl_manifest");
    assert_script_run ("python3.11 /tmp/aitl.py job create -s $subscription_id -r $resource_group -n $aitl_job_name -b @/tmp/$aitl_manifest");
}

1;
