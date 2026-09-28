use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any);
use sles4sap::qesap::utils;

subtest '[qesap_is_job_finished]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::utils', no_auto => 1);
    my @results = ();
    $qesap->redefine(script_output => sub {
            if ($_[0] =~ /100000/) { return "not json"; }
            if ($_[0] =~ /200000/) { return '{"state":"donaldduck"}'; }
            if ($_[0] =~ /300000/) { return '{"state":"running"}'; }
    });

    $qesap->redefine(get_required_var => sub { return ''; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    push @results, qesap_is_job_finished(job_id => 100000);
    push @results, qesap_is_job_finished(job_id => 200000);
    push @results, qesap_is_job_finished(job_id => 300000);


    ok($results[0] == 0, "Consider 'running' state if the openqa job status response isn't JSON");
    ok($results[1] == 1, "Considered 'finished' state if the openqa job status response exists and isn't 'running'");
    ok($results[2] == 0, "Consider 'running' if the openqa job status response is 'running'");
};

subtest '[qesap_get_public_cloud_tags]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::utils', no_auto => 1);
    my $var_value;
    $qesap->redefine(get_var => sub { return $var_value; });
    $qesap->redefine(get_current_job_id => sub { return '42'; });

    # Case 1: PUBLIC_CLOUD_TAGS is undef/empty
    $var_value = undef;
    is(qesap_get_public_cloud_tags(), '', 'Returns empty string if PUBLIC_CLOUD_TAGS is undef');

    # Case 2: Standard tags without openqa_var_job_id
    $var_value = 'key1=value1,key2=value2,key3';
    is(qesap_get_public_cloud_tags(), 'key1=value1 key2=value2 key3=1', 'Correctly formats standard tags');

    # Case 3: Tags containing openqa_var_job_id
    $var_value = 'key1=value1,openqa_var_job_id';
    is(qesap_get_public_cloud_tags(), 'key1=value1 openqa_var_job_id=42', 'Substitutes openqa_var_job_id with get_current_job_id');
};

done_testing;
