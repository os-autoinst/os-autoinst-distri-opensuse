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
            my $expected_server = $test_data{host};
            $expected_server =~ s/\./-/g;
            is(
                $tags{openqa_var_server},
                $expected_server,
                "openqa_var_server tag is '" . ($tags{openqa_var_server} // 'undef') . "' and expect '$expected_server' for $url"
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
    set_var('NAME', 'spock');

    my %tags_fallback = qesap_get_public_cloud_tags();

    set_var('OPENQA_HOSTNAME', undef);
    set_var('NAME', undef);
    is(
        $tags_fallback{openqa_var_server},
        'openqa-USS-Enterprise-NCC-1701',
        "openqa_var_server tag is '" . ($tags_fallback{openqa_var_server} // 'undef') . "' and expect 'openqa-USS-Enterprise-NCC-1701'"
    );
    like(
        $tags_fallback{openqa_created_date},
        qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/,
        "openqa_created_date tag is '" . ($tags_fallback{openqa_created_date} // 'undef') . "' and expect ISO 8601 format"
    );
};

subtest '[qesap_get_public_cloud_tags] openqa_var_name sanitization' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::utils', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return '42'; });
    set_var('OPENQA_HOSTNAME', 'openqa.suse.de');

    my %test_cases = (
        'removes @... suffix and truncates to 63 chars' => {
            input => '00389322-sle-15-SP7-Qesap-Gcp-Byos-x86_64-Buildmpagot_VR-qesap_gcp_angi_test@64bit',
            expected => '00389322-sle-15-SP7-Qesap-Gcp-Byos-x86_64-Buildmpagot_VR-qesap_',
        },
        'keeps short name without @ intact' => {
            input => 'enterprise',
            expected => 'enterprise',
        },
        'removes @ suffix on short name' => {
            input => 'shuttle@flavor',
            expected => 'shuttle',
        },
        'truncates long name without @ to 63 chars' => {
            input => 'a' x 80,
            expected => 'a' x 63,
        },
        'handles empty name' => {
            input => '',
            expected => '',
        },
        'handles undefined name' => {
            input => undef,
            expected => '',
        },
    );

    for my $desc (sort keys %test_cases) {
        my $tc = $test_cases{$desc};
        set_var('NAME', $tc->{input});
        my %tags = qesap_get_public_cloud_tags();
        is($tags{openqa_var_name}, $tc->{expected}, "$desc: '$tags{openqa_var_name}'");
        ok(length($tags{openqa_var_name}) <= 63, "length <= 63 for '$desc'");
    }

    set_var('OPENQA_HOSTNAME', undef);
    set_var('NAME', undef);
};

subtest '[qesap_get_public_cloud_tags] openqa_var_server GCP sanitization' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::utils', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return '42'; });

    my %test_cases = (
        'replaces dots with dashes' => {
            input => 'openqaworker15.qe.prg2.suse.org',
            expected => 'openqaworker15-qe-prg2-suse-org',
        },
        'handles hostname without dots' => {
            input => 'enterprise',
            expected => 'enterprise',
        },
        'handles multiple consecutive dots' => {
            input => 'shuttle..vulcan',
            expected => 'shuttle--vulcan',
        },
    );

    for my $desc (sort keys %test_cases) {
        my $tc = $test_cases{$desc};
        set_var('OPENQA_HOSTNAME', $tc->{input});
        my %tags = qesap_get_public_cloud_tags();
        is($tags{openqa_var_server}, $tc->{expected}, "$desc: '$tags{openqa_var_server}'");
        ok(length($tags{openqa_var_server}) <= 63, "length <= 63 for '$desc'");
        like($tags{openqa_var_server}, qr/^[a-z0-9_-]+$/, "GCP-safe for '$desc'");
    }

    set_var('OPENQA_HOSTNAME', undef);
};

done_testing;
