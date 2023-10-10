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
    %params = collect_sbd_delay_parameters();
    is $params{'pcmk_delay_max'}, 30, "Test diskless scenario: pcmk_delay_max = $params{'pcmk_delay_max'}";
    set_var('USE_DISKLESS_SBD', undef);
};

subtest '[cluster_status_matches_regex]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $cmr_status = "Some long string to simulate crm status output here";
    my $res = cluster_status_matches_regex($cmr_status);
    ok scalar $res == 0, 'Cluster health is excellent!!';
};

subtest '[cluster_status_matches_regex] Cluster with errors' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $cmr_status = "* stonith-sbd	(stonith:external/sbd):	 Stopped vmhana01
        * Clone Set: cln_azure-events [rsc_azure-events]:
        * Started: [ vmhana01 vmhana02 ]
        * Clone Set: cln_SAPHanaTopology_HDB_HDB00 [rsc_SAPHanaTopology_HDB_HDB00]:
            * Started: [ vmhana01 vmhana02 ]
        * Clone Set: msl_SAPHana_HDB_HDB00 [rsc_SAPHana_HDB_HDB00] (promotable):
            * rsc_SAPHana_HDB_HDB00	(ocf::suse:SAPHana):	 Promoting vmhana02
            * Stopped: [ vmhana01 ]
        * rsc_socat_HDB_HDB00	(ocf::heartbeat:azure-lb):	 Stopped vmhana02
        * Resource Group: g_ip_HDB_HDB00:
            * rsc_ip_HDB00	(ocf::heartbeat:IPaddr2):	 Stopped";
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $res = cluster_status_matches_regex($cmr_status);
    ok scalar $res == 1, 'Cluster health problem properly detected';
};

subtest '[cluster_status_matches_regex] Cluster with master failed errors' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $cmr_status = "* stonith-sbd	(stonith:external/sbd):	 Started vmhana01
    	* Clone Set: cln_azure-events [rsc_azure-events]:
    	* Started: [ vmhana01 vmhana02 ]
  	* Clone Set: cln_SAPHanaTopology_HDB_HDB00 [rsc_SAPHanaTopology_HDB_HDB00]:
    	     * Started: [ vmhana01 vmhana02 ]
  	* Clone Set: msl_SAPHana_HDB_HDB00 [rsc_SAPHana_HDB_HDB00] (promotable):
    	     * rsc_SAPHana_HDB_HDB00	(ocf::suse:SAPHana):	 FAILED Master vmhana01 (Monitoring)
    	     * Slaves: [ vmhana02 ]
  	* rsc_socat_HDB_HDB00	(ocf::heartbeat:azure-lb):	 Started vmhana02
  	* Resource Group: g_ip_HDB_HDB00:
    	    * rsc_ip_HDB00	(ocf::heartbeat:IPaddr2):	 Started vmhana01";
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $res = cluster_status_matches_regex($cmr_status);
    ok scalar $res == 1, 'Cluster health problem properly detected';
};

subtest '[cluster_status_matches_regex] Cluster with starting errors' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $cmr_status = "* rsc_stonith_azure	(stonith:fence_azure_arm):	 Started vmhana01
  	* Clone Set: cln_azure-events [rsc_azure-events]:
    	* Started: [ vmhana01 vmhana02 ]
  	* Clone Set: cln_SAPHanaTopology_HDB_HA000 [rsc_SAPHanaTopology_HDB_HA000]:
    	     * Started: [ vmhana01 vmhana02 ]
  	* Clone Set: msl_SAPHana_HDB_HA000 [rsc_SAPHana_HDB_HA000] (promotable):
    	     * rsc_SAPHana_HDB_HA000	(ocf::suse:SAPHana):	 Starting vmhana02
             * Masters: [ vmhana01 ]
  	* rsc_socat_HDB_HA000	(ocf::heartbeat:azure-lb):	 Started vmhana02
  	* Resource Group: g_ip_HDB_HA000:
            * rsc_ip_HA000	(ocf::heartbeat:IPaddr2):	 Started vmhana01";
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $res = cluster_status_matches_regex($cmr_status);
    ok scalar $res == 1, 'Cluster health problem properly detected';
};

subtest '[setup_sbd_delay] Test OpenQA parameter input' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $hacluster->redefine(file_content_replace => sub { return 1; });
    $hacluster->redefine(calculate_sbd_start_delay => sub {
            my $param = get_var('HA_SBD_START_DELAY', '');
            my $default = 30;
            return $default if grep /$param/, ('yes', '1', '');
            return 0 if grep /$param/, qw(no 0);
            return 100 if $param eq '100s';
            return $param if looks_like_number($param); });
    $hacluster->redefine(set_sbd_service_timeout => sub {
            my ($timeout) = @_;
            return $timeout;
    });

    my %passing_values_vs_expected = (
        'yes' => '30',
        '' => '30',
        'no' => '0',
        '0' => '0',
        '100' => '100',
        '100s' => '100');

    my @failok_values = ('aasd', '100asd', '100S', ' ');

    for my $input_value (@failok_values) {
        set_var('HA_SBD_START_DELAY', $input_value);
        dies_ok { setup_sbd_delay() } "Test expected failing 'HA_SBD_START_DELAY' value: $input_value";
    }

    for my $value (keys %passing_values_vs_expected) {
        set_var('HA_SBD_START_DELAY', $value);
        my $returned_value = setup_sbd_delay();
        is($returned_value, $passing_values_vs_expected{$value},
            "Test 'HA_SBD_START_DELAY' passing values:\ninput_value: $value\n result: $returned_value");
    }

};

subtest '[set_sbd_service_timeout] Check failing values' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $hacluster->redefine(file_content_replace => sub { return 1; });
    $hacluster->redefine(assert_script_run => sub { return 1; });
    $hacluster->redefine(script_run => sub { return 0; });
    dies_ok { set_sbd_service_timeout() } 'Expected failure if no argument is provided';
    dies_ok { set_sbd_service_timeout('Chupacabras') } 'Expected failure if argument is not a number';
    is set_sbd_service_timeout('42'), '42', 'Function should not change delay time';
};

done_testing;
