use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any);
use testapi qw(set_var);
use sles4sap::qesap::utils;

subtest '[qesap_is_job_finished]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::utils', no_auto => 1);
    my @results = ();
    $qesap->redefine(script_output => sub {
            if ($_[0] =~ /100000/) { return 'not json'; }
            if ($_[0] =~ /200000/) { return '{"state":"warpdrive"}'; }
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

subtest '[qesap_get_public_cloud_tags] HTTP/HTTPS URLs with and without trailing slash' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::utils', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return '42'; });

    # Single hash containing the common test variables
    my %test_data = (
        host => 'openqa.USS.Enterprise.NCC-1701',
        name => 'kirk',
    );

    for my $protocol ('http://', 'https://') {
        for my $slash ('', '/') {
            my $url = $protocol . $test_data{host} . $slash;

            set_var('OPENQA_URL', $url);
            set_var('NAME', $test_data{name});

            my %tags = qesap_get_public_cloud_tags();

            # Clean up variables
            set_var('OPENQA_URL', undef);
            set_var('NAME', undef);

            is(
                $tags{openqa_var_job_id},
                '42',
                "openqa_var_job_id tag is '" . ($tags{openqa_var_job_id} // 'undef') . "' and expect '42'"
            );
            is(
                $tags{openqa_var_name},
                $test_data{name},
                "openqa_var_name tag is '" . ($tags{openqa_var_name} // 'undef') . "' and expect '$test_data{name}'"
            );
            is(
                $tags{openqa_var_server},
                $test_data{host},
                "openqa_var_server tag is '" . ($tags{openqa_var_server} // 'undef') . "' and expect '$test_data{host}' for $url"
            );
            like(
                $tags{openqa_created_date},
                qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/,
                "openqa_created_date tag is '" . ($tags{openqa_created_date} // 'undef') . "' and expect ISO 8601 format"
            );
        }
    }
};

subtest '[qesap_get_public_cloud_tags] Fallback to OPENQA_HOSTNAME' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::utils', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return '42'; });

    set_var('OPENQA_HOSTNAME', 'openqa.USS.Enterprise.NCC-1701');
    set_var('NAME', 'fallback_test');

    my %tags_fallback = qesap_get_public_cloud_tags();

    set_var('OPENQA_HOSTNAME', undef);
    set_var('NAME', undef);
    is(
        $tags_fallback{openqa_var_server},
        'openqa.USS.Enterprise.NCC-1701',
        "openqa_var_server tag is '" . ($tags_fallback{openqa_var_server} // 'undef') . "' and expect 'openqa.USS.Enterprise.NCC-1701'"
    );
    like(
        $tags_fallback{openqa_created_date},
        qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/,
        "openqa_created_date tag is '" . ($tags_fallback{openqa_created_date} // 'undef') . "' and expect ISO 8601 format"
    );
};

done_testing;
