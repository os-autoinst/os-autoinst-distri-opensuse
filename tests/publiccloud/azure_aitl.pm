# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
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
use utils qw(zypper_call);
use JSON;
use XML::LibXML;
use Data::Dumper;

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    my $job_id = get_current_job_id();

    assert_script_run('az version');

    my $provider = $self->provider_factory();

    my $region = "westeurope";    #get_var('PUBLIC_CLOUD_REGION');
    my $resource_group = "openqa-aitl-$job_id";
    my $subscription_id = $provider->provider_client->subscription;

    my $aitl_client_version = "20241118.1";
    my $aitl_image_gallery = "test_image_gallery";
    my $aitl_image_version = "latest";
    my $aitl_job_name = "openqa-aitl-$job_id";
    my $aitl_manifest = "custom.json";
    my $aitl_image_name = $provider->generate_azure_image_definition();

    my $aitl_get_options = "-s $subscription_id -r $resource_group -n $aitl_job_name";

    my $openqa_url = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    my $created_by = "$openqa_url/t$job_id";
    my $tags = "openqa-aitl=$job_id openqa_created_by=$created_by openqa_var_server=$openqa_url";

    my $timeout //= get_var('PUBLIC_CLOUD_AITL_TIMEOUT', 3600 * 1.5);
    my $aitl_job = "python3.11 /tmp/aitl.py job";
    my $monitoring = "{RUNNING:length([?@=='RUNNING']),QUEUED:length([?@=='QUEUED']),ASSIGNED:length([?@=='ASSIGNED']),FAILED:length([?@=='FAILED'])}";

    # Get the AITL script
    assert_script_run("curl https://raw.githubusercontent.com/microsoft/lisa/refs/tags/$aitl_client_version/microsoft/utils/aitl/aitl.py -o /tmp/aitl.py");

    # Create Resource group in $region
    assert_script_run("az group create -n $resource_group -l $region --tags '$tags'");

    # Get manifest from data folder
    assert_script_run("curl " . data_url("publiccloud/aitl/$aitl_manifest") . " -o /tmp/$aitl_manifest");
    assert_script_run("sed -i -e 's/<IMAGE_NAME>/$aitl_image_name/g' -e 's/<IMAGE_VERSION>/$aitl_image_version/g' -e 's/<IMAGE_GALLERY_NAME>/$aitl_image_gallery/g' /tmp/$aitl_manifest");

    # Exclude tests (if any to exclude are invoked)
    # Wildcards are supported, e.g. `nvme` will disable all tests with nvme.
    if (get_var('PUBLIC_CLOUD_AITL_EXCLUDE_TESTS')) {
        my @excluded_tests_list = split(',', get_var('PUBLIC_CLOUD_AITL_EXCLUDE_TESTS'));
        foreach my $aitl_test (@excluded_tests_list) {
            assert_script_run(qq(sed -i -e "/$aitl_test/d" /tmp/$aitl_manifest));
        }
    }

    # Create AITL Job based on a manifest
    assert_script_run("$aitl_job create $aitl_get_options -b @/tmp/$aitl_manifest");

    # Wait a few seconds to give Azure time to create the jobs
    sleep(10);

    # Get AITL job status
    # AITL Jobs run in parallel so it's possible to have Jobs in all kind of states.
    # The goal of the loop is to check there are no Jobs Queued or currently Running.
    my $status_data;
    while (1) {
        # Get the current job status
        my $status = script_output(qq($aitl_job get $aitl_get_options -q "properties.results[].status|$monitoring"));

        if ($status =~ /no result returned/ig) {
            sleep(60);
            record_info("WARN:", "no results:\n" . $status);
            next;
        }

        # Remove the first two/3 non-JSON lines from the status JSON
        $status =~ s/^(?:.*\n){1,3}//;

        # Decode the status JSON
        eval { $status_data = decode_json($status); };

        # Check if there are still jobs in RUNNING, QUEUED, or ASSIGNED state
        if ($@ || $status_data->{RUNNING} == 0 && $status_data->{QUEUED} == 0 && $status_data->{ASSIGNED} == 0) {
            last;    # Exit the loop if no jobs are in these states
        }

        # Print the status
        print("Unfinished AITL Jobs! Running:", $status_data->{RUNNING}, " QUEUED: ", $status_data->{QUEUED}, " ASSIGNED: ", $status_data->{ASSIGNED});

        # Wait before checking again
        sleep(65);
    }

    # Need to save results to a variable
    my $results = script_output("$aitl_job get $aitl_get_options -q 'properties.results[]'");

    # Remove the first two non-JSON lines from the results JSON.
    $results =~ s/^(?:.*\n){1,3}//;

    # Convert to JUnit XML and upload to host
    my $extra_log;
    eval { $extra_log = json_to_xml($results, $aitl_image_name); };
    die "AITL tests: bad or missing results:\n" . Dumper($results) if ($@);

    # Download file from host pool to the instance
    assert_script_run('curl -s ' . autoinst_url('/files/aitl_results.xml') . ' -o /tmp/aitl_results.xml');
    parse_extra_log('XUnit', '/tmp/aitl_results.xml');
    die "AITL test(s) failed: " . $status_data->{FAILED} . "\n" if ($status_data->{FAILED} > 0);
}

sub json_to_xml {
    my ($json, $imageName) = @_;
    my $data = decode_json($json);

    my $dom = XML::LibXML::Document->new('1.0', 'UTF-8');
    my $testsuite = $dom->createElement('testsuite');

    my $failed_tests = 0;

    $testsuite->setAttribute('name', 'AITL');
    $testsuite->setAttribute('image', $imageName);

    foreach my $test (@$data) {
        my $testcase = $dom->createElement('testcase');
        $testcase->setAttribute('name', $test->{testName});
        $testcase->setAttribute('duration', $test->{duration});

        if ($test->{status} =~ /FAILED/) {
            my $failure = $dom->createElement('failure');
            $failure->setAttribute('message', $test->{message});
            $testcase->appendChild($failure);
            $failed_tests++;

        } elsif ($test->{status} =~ /SKIPPED/) {
            my $skipped = $dom->createElement('skipped');
            $skipped->setAttribute('message', $test->{message});
            $testcase->appendChild($skipped);

        } else {
            $testcase->setAttribute('status', $test->{status});
        }
        $testsuite->setAttribute('failures', $failed_tests);
        $testsuite->appendChild($testcase);
    }

    $dom->setDocumentElement($testsuite);
    $dom->toFile(hashed_string('aitl_results.xml'), 1);
}

1;
