use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockModule;
use hacluster;
use testapi;
use Scalar::Util 'looks_like_number';

my %sbd_delay_params = (
    'sbd_delay_start' => 'yes',
    'corosync_token' => 5,
    'corosync_consensus' => 5,
    'sbd_watchdog_timeout' => 5,
    'pcmk_delay_max' => 5
);

subtest '[calculate_sbd_start_delay] Check sbd_delay_start values' => sub {
    my $sbd_delay;
    my %value_vs_expected = (
        'yes' => 25,
        '1' => 25,
        'no' => 0,
        '0' => 0,
        '120' => 120,
    );

    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $hacluster->redefine(record_soft_failure => sub { note(join(' ', 'RECORD_SOFT_FAILURE -->', @_)); });
    $hacluster->redefine(script_output => sub { note(join(' ', 'SCRIPT_OUTPUT -->', @_)); });

    for my $input_value (keys %value_vs_expected) {
        my $expected = $value_vs_expected{$input_value};
        $sbd_delay_params{'sbd_delay_start'} = $input_value;
        $sbd_delay = calculate_sbd_start_delay(\%sbd_delay_params);
        is $sbd_delay, $expected, "Testing 'sbd_delay_start' value: $input_value";
    }
    $sbd_delay_params{'sbd_delay_start'} = 'yes';
};

subtest '[calculate_sbd_start_delay] Return default on non numeric value' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $hacluster->redefine(record_soft_failure => sub { note(join(' ', 'RECORD_SOFT_FAILURE -->', @_)); });
    $hacluster->redefine(script_output => sub { note(join(' ', 'SCRIPT_OUTPUT -->', @_)); });
    $hacluster->redefine(croak => sub { die; });

    my $corosync_token_original = $sbd_delay_params{'corosync_token'};
    $sbd_delay_params{'corosync_token'} = 'asdf';
    $sbd_delay_params{'sbd_delay_start'} = 'yes';

    dies_ok { calculate_sbd_start_delay(\%sbd_delay_params) } "Test should die with unexpected values";
    $sbd_delay_params{'corosync_token'} = $corosync_token_original;
};

subtest '[script_output_retry_check] Check input values' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    # Just returns whatever you put as command
    $hacluster->redefine(script_output => sub { return $_[0]; });

    # Test mandatory args
    dies_ok { script_output_retry_check(cmd => undef, regex_string => 'test', sleep => '1') } "Die without cmd arg";
    dies_ok { script_output_retry_check(cmd => 'rm -Rf /', regex_string => undef, sleep => '1') } "Die without regex arg";

    # Test regex
    is script_output_retry_check(cmd => '42', regex_string => '^\d+$', sleep => '1', retry => '2'), '42', "Test passing regex";
    dies_ok { script_output_retry_check(cmd => 'rm -Rf /', regex_string => '^\d+$', sleep => '1', retry => '2') } "Test failing regex";
};

subtest '[script_output_retry_check] Diskless SBD scenario' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    # Just returns whatever you put as command
    $hacluster->redefine(script_output => sub { return $_[0]; });

    $corosync_token = 1;
    $corosync_consensus = 2;
    $sbd_watchdog_timeout = 3;
    $sbd_delay_start = 4;
    $pcmk_delay_max = "asdf";

    my %params = collect_sbd_delay_parameters();
    is $params{'pcmk_delay_max'}, 0, "Test pcmk_delay_max undefined: pcmk_delay_max = $params{'pcmk_delay_max'}";

    set_var('USE_DISKLESS_SBD', 1);
    my %params = collect_sbd_delay_parameters();
    is $params{'pcmk_delay_max'}, 30, "Test diskless scenario: pcmk_delay_max = $params{'pcmk_delay_max'}";
    set_var('USE_DISKLESS_SBD', undef);
};

done_testing;
