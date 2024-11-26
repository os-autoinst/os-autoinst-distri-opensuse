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
use JSON;
use XML::LibXML;

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
    script_output ("cat /tmp/$aitl_manifest");
    assert_script_run ("python3.11 /tmp/aitl.py job create -s $subscription_id -r $resource_group -n $aitl_job_name -b @/tmp/$aitl_manifest");

    # Wait a few seconds to give Azure time to create the jobs
    
    sleep(10);

    # Get AITL job status
    # Need to save results to a variable
    
    my $results = script_output ("python3.11 /tmp/aitl.py job get -s $subscription_id -r $resource_group -n $aitl_job_name -q 'properties.results[]'");
    record_info("results:", $results);

    # Remove the first two non-JSON lines from the results JSON.
    $results =~ s/^(?:.*\n){1,3}//;
    record_info("results_clean:", $results);

    my $status = script_output ("python3.11 /tmp/aitl.py job get -s $subscription_id -r $resource_group -n $aitl_job_name -q 'properties.results[].status|{RUNNING:length([?@==\"RUNNING\"]),QUEUED:length([?@==\"QUEUED\"])}'");

    # Remove the first two non-JSON lines from the status JSON.
    $status =~ s/^(?:.*\n){1,3}//;
    my $status_data = decode_json($status);

    while ($status_data->{RUNNING} ne 0 || $status_data->{QUEUED} ne 0) {
        sleep(30);
        $status = script_output ("python3.11 /tmp/aitl.py job get -s $subscription_id -r $resource_group -n $aitl_job_name -q 'properties.results[].status|{RUNNING:length([?@==\"RUNNING\"]),QUEUED:length([?@==\"QUEUED\"])}'");
        $status =~ s/^(?:.*\n){1,3}//;
        $status_data = decode_json($status);
        print("Unfinished AITL Jobs! Running:", $status_data->{RUNNING}, " QUEUED: ", $status_data->{QUEUED});
    }

    # Convert to JUnit XML and upload to host
    my $extra_log = json_to_xml($results, $aitl_image_name);

    # Download file from host pool to the instance
    assert_script_run('curl -s ' . autoinst_url('/files/aitl_results.xml') . ' -o /tmp/aitl_results.xml');
    parse_extra_log('XUnit','/tmp/aitl_results.xml');

}

sub json_to_xml {
  my ($json, $imageName) = @_;
  my $data = decode_json($json);

  my $dom = XML::LibXML::Document->new('1.0','UTF-8');
  my $testsuite = $dom->createElement('testsuite');

  $testsuite->setAttribute('name', 'AITL');
  $testsuite->setAttribute('image', $imageName);

  foreach my $test (@$data) {
    my $testcase = $dom->createElement('testcase');
    $testcase->setAttribute('name', $test->{testName});
    $testcase->setAttribute('duration', $test->{duration});
    $testcase->setAttribute('status', $test->{status});
    $testcase->setAttribute('message', $test->{message});
    
    $testsuite->appendChild($testcase);
  }

  $dom->setDocumentElement($testsuite);
  $dom->toFile(hashed_string('aitl_results.xml'),1);
  
}

1;
