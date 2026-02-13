use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::MockModule;
use Test::Mock::Time;
use hacluster;
use testapi;
use Scalar::Util qw(looks_like_number);
use List::Util qw(all any none);

my %sbd_delay_params = (
    sbd_delay_start => 'yes',
    corosync_token => 5,
    corosync_consensus => 5,
    sbd_watchdog_timeout => 5,
    pcmk_delay_max => 5
);

my %original_hacluster_sbd_delay_params = (
    corosync_token => $hacluster::corosync_token,
    corosync_consensus => $hacluster::corosync_consensus,
    sbd_watchdog_timeout => $hacluster::sbd_watchdog_timeout,
    sbd_delay_start => $hacluster::sbd_delay_start,
    pcmk_delay_max => $hacluster::pcmk_delay_max
);

sub mock_hacluster_sbd_delay_parameters {
    my %args = @_;
    $hacluster::corosync_token = $args{corosync_token} // 1;
    $hacluster::corosync_consensus = $args{corosync_consensus} // 2;
    $hacluster::sbd_watchdog_timeout = $args{sbd_watchdog_timeout} // 3;
    $hacluster::sbd_delay_start = $args{sbd_delay_start} // 4;
    $hacluster::pcmk_delay_max = $args{pcmk_delay_max} // 42;
}

sub reset_hacluster_sbd_delay_parameters {
    $hacluster::corosync_token = $original_hacluster_sbd_delay_params{corosync_token};
    $hacluster::corosync_consensus = $original_hacluster_sbd_delay_params{corosync_consensus};
    $hacluster::sbd_watchdog_timeout = $original_hacluster_sbd_delay_params{sbd_watchdog_timeout};
    $hacluster::sbd_delay_start = $original_hacluster_sbd_delay_params{sbd_delay_start};
    $hacluster::pcmk_delay_max = $original_hacluster_sbd_delay_params{pcmk_delay_max};
}

subtest '[calculate_sbd_start_delay] Check sbd_delay_start values' => sub {
    my $sbd_delay;
    my %value_vs_expected = (
        yes => 25,
        '1' => 25,
        no => 0,
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

subtest '[collect_sbd_delay_parameters] retry corosync-cmapctl' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    # Just returns whatever you put as command
    $hacluster->redefine(script_output => sub { return $_[0]; });
    my @retry_cmds = ();
    $hacluster->redefine(script_retry => sub { push @retry_cmds, @_; });

    mock_hacluster_sbd_delay_parameters();
    collect_sbd_delay_parameters();
    note(join(' ', 'SCRIPT_RETRY -->', @retry_cmds));
    is $retry_cmds[0], 'corosync-cmapctl', 'corosync-cmapctl called with script_retry()';
    is $retry_cmds[2], 30, 'script_retry() delay set to 30s';
    is $retry_cmds[4], $hacluster::default_timeout, "script_retry() timeout set to ${hacluster::default_timeout}s";
    reset_hacluster_sbd_delay_parameters();
};

subtest '[collect_sbd_delay_parameters] SBD scenario' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    # Just returns whatever you put as command
    $hacluster->redefine(script_output => sub { return $_[0]; });
    $hacluster->redefine(script_retry => sub { return 0; });

    mock_hacluster_sbd_delay_parameters();
    my %params = collect_sbd_delay_parameters();
    is $params{'corosync_token'}, 1, "Test corosync_token correctly set: = corosync_token $params{'corosync_token'}";
    is $params{'corosync_consensus'}, 2, "Test corosync_consensus correctly set: corosync_consensus = $params{'corosync_consensus'}";
    is $params{'sbd_watchdog_timeout'}, 3, "Test sbd_watchdog_timeout correctly set: sbd_watchdog_timeout = $params{'sbd_watchdog_timeout'}";
    is $params{'sbd_delay_start'}, 4, "Test sbd_delay_start correctly set: sbd_delay_start = $params{'sbd_delay_start'}";
    is $params{'pcmk_delay_max'}, 42, "Test pcmk_delay_max correctly set: pcmk_delay_max = $params{'pcmk_delay_max'}";
    reset_hacluster_sbd_delay_parameters();
};

subtest '[collect_sbd_delay_parameters] SBD scenario - undefined pcmk_delay_max' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @record_info = ();
    $hacluster->redefine(record_info => sub { push @record_info, @_; });
    # Just returns whatever you put as command
    $hacluster->redefine(script_output => sub { return $_[0]; });
    $hacluster->redefine(script_retry => sub { return 0; });

    mock_hacluster_sbd_delay_parameters(pcmk_delay_max => 'asdf');
    my %params = collect_sbd_delay_parameters();
    note(join(' ', 'RECORD_INFO -->', @record_info));
    is $params{'corosync_token'}, 1, "Test corosync_token correctly set: = corosync_token $params{'corosync_token'}";
    is $params{'corosync_consensus'}, 2, "Test corosync_consensus correctly set: corosync_consensus = $params{'corosync_consensus'}";
    is $params{'sbd_watchdog_timeout'}, 3, "Test sbd_watchdog_timeout correctly set: sbd_watchdog_timeout = $params{'sbd_watchdog_timeout'}";
    is $params{'sbd_delay_start'}, 4, "Test sbd_delay_start correctly set: sbd_delay_start = $params{'sbd_delay_start'}";
    is $params{'pcmk_delay_max'}, 0, "Test pcmk_delay_max undefined: pcmk_delay_max = $params{'pcmk_delay_max'}";
    ok((any { qr|Retry 3/3| } @record_info), 'pcmk_delay_max command retried 3 times');
    ok((any { /Script output did not match pattern/ } @record_info), 'pcmk_delay_max command retried 3 times due to unmatched pattern');
    ok((any { /Output: asdf/ } @record_info), 'pcmk_delay_max command retried 3 times due to unmatched pattern: "asfd" !~ /^\d+$/');
    reset_hacluster_sbd_delay_parameters();
};

subtest '[collect_sbd_delay_parameters] Diskless SBD scenario' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    # Just returns whatever you put as command
    $hacluster->redefine(script_output => sub { return $_[0]; });
    $hacluster->redefine(script_retry => sub { return 0; });

    mock_hacluster_sbd_delay_parameters();
    set_var('USE_DISKLESS_SBD', 1);
    my %params = collect_sbd_delay_parameters();
    is $params{'corosync_token'}, 1, "Test corosync_token correctly set: = corosync_token $params{'corosync_token'}";
    is $params{'corosync_consensus'}, 2, "Test corosync_consensus correctly set: corosync_consensus = $params{'corosync_consensus'}";
    is $params{'sbd_watchdog_timeout'}, 3, "Test sbd_watchdog_timeout correctly set: sbd_watchdog_timeout = $params{'sbd_watchdog_timeout'}";
    is $params{'sbd_delay_start'}, 4, "Test sbd_delay_start correctly set: sbd_delay_start = $params{'sbd_delay_start'}";
    is $params{'pcmk_delay_max'}, 30, "Test diskless scenario: pcmk_delay_max = $params{'pcmk_delay_max'}";
    set_var('USE_DISKLESS_SBD', undef);
    reset_hacluster_sbd_delay_parameters();
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
        * Clone Set: cln_SAPHanaTpg_HQ0_HDB00 [rsc_SAPHanaTpg_HQ0_HDB00]:
            * Started: [ vmhana01 vmhana02 ]
        * Clone Set: msl_SAPHanaCtl
            * rsc_SAPHanaCtl_HQ0_HDB00	(ocf::suse:SAPHana):	 Promoting vmhana02
            * Stopped: [ vmhana01 ]
        * rsc_socat_HQ0_HDB00	(ocf::heartbeat:azure-lb):	 Stopped vmhana02
        * Resource Group: g_ip_HQ0_HDB00:
            * rsc_ip_HQ0_HDB00	(ocf::heartbeat:IPaddr2):	 Stopped";
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $res = cluster_status_matches_regex($cmr_status);
    ok scalar $res == 1, 'Cluster health problem properly detected';
};

subtest '[cluster_status_matches_regex] Cluster with master failed errors' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $cmr_status = "* stonith-sbd	(stonith:external/sbd):	 Started vmhana01
    	* Clone Set: cln_azure-events [rsc_azure-events]:
    	* Started: [ vmhana01 vmhana02 ]
  	* Clone Set: cln_SAPHanaTpg_HQ0_HDB00 [rsc_SAPHanaTpg_HQ0_HDB00]:
    	     * Started: [ vmhana01 vmhana02 ]
  	* Clone Set: msl_SAPHanaCtl_HQ0_HDB00 [rsc_SAPHanaCtl_HQ0_HDB00] (promotable):
    	     * rsc_SAPHanaCtl_HQ0_HDB00	(ocf::suse:SAPHana):	 FAILED Master vmhana01 (Monitoring)
    	     * Slaves: [ vmhana02 ]
  	* rsc_socat_HQ0_HDB00	(ocf::heartbeat:azure-lb):	 Started vmhana02
  	* Resource Group: g_ip_HQ0_HDB00:
    	    * rsc_ip_HQ0_HDB00	(ocf::heartbeat:IPaddr2):	 Started vmhana01";
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $res = cluster_status_matches_regex($cmr_status);
    ok scalar $res == 1, 'Cluster health problem properly detected';
};

subtest '[cluster_status_matches_regex] Cluster with starting errors' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $cmr_status = "* rsc_stonith_azure	(stonith:fence_azure_arm):	 Started vmhana01
  	* Clone Set: cln_azure-events [rsc_azure-events]:
    	* Started: [ vmhana01 vmhana02 ]
  	* Clone Set: cln_SAPHanaTpg_HQ0_HA000 [rsc_SAPHanaTpg_HQ0_HA000]:
    	     * Started: [ vmhana01 vmhana02 ]
  	* Clone Set: msl_SAPHanaCtl_HQ0_HA000 [rsc_SAPHanaCtl_HQ0_HA000] (promotable):
    	     * rsc_SAPHanaCtl_HQ0_HA000	(ocf::suse:SAPHana):	 Starting vmhana02
             * Masters: [ vmhana01 ]
  	* rsc_socat_HQ0_HA000	(ocf::heartbeat:azure-lb):	 Started vmhana02
  	* Resource Group: g_ip_HQ0_HA000:
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
        yes => '30',
        '' => '30',
        no => '0',
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

subtest '[crm_wait_for_maintenance] arguments validation' => sub {
    # only supported values are 'false', 'true'
    dies_ok { crm_wait_for_maintenance(target_state => 'superposition',
            loop_sleep => 1) } 'Expected failure with incorrect argument';
};

subtest '[crm_wait_for_maintenance]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my %correct_output_values = (true => ' maintenance-mode=true ', false => ' maintenance-mode=false ');
    my @wrong_output_values = (' maintenance-mode=weirdKernelMessage ', 'as mweirdKernel_message aintenance-mode=false ');

    foreach (@wrong_output_values) {
        $hacluster->redefine(script_output => sub { return $_; });
        dies_ok { crm_wait_for_maintenance(target_state => $_, loop_sleep => 1) }
        'Fail with incorrect or mangled crm output';
    }

    foreach (keys %correct_output_values) {
        $hacluster->redefine(script_output => sub { return $correct_output_values{$_}; });
        is crm_wait_for_maintenance(target_state => $_, loop_sleep => 1), $_, "Return correct value: $_";
    }
};

subtest '[crm_check_resource_location]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $resource = 'grp_EN2_ASCS00';
    my $hostname = 'ensa-node01';
    my @calls;
    $hacluster->redefine(script_output => sub { return "resource $resource is running on: $hostname"; });

    is crm_check_resource_location(resource => $resource), $hostname, "Return correct hostname: $hostname";
    is crm_check_resource_location(resource => $resource, wait_for_target => $hostname),
      $hostname, "Return correct hostname: $hostname";
};

subtest '[set_cluster_parameter]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(assert_script_run => sub { @calls = @_; return; });

    set_cluster_parameter(resource => 'Hogwarts', parameter => 'RoomOfRequirement', value => 'open');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /crm/, @calls), 'Execute "crm" command.');
    ok((grep /resource param Hogwarts/, @calls), 'Call "resource" option');
    ok((grep /set/, @calls), 'Specify "set" action');
    ok((grep /RoomOfRequirement open/, @calls), 'Specify parameter name');
};

subtest '[show_cluster_parameter]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_output => sub { @calls = @_; return 'false'; });

    show_cluster_parameter(resource => 'Hogwarts', parameter => 'RoomOfRequirement');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /crm/, @calls), 'Execute "crm" command.');
    ok((grep /resource param Hogwarts/, @calls), 'Call "resource" option');
    ok((grep /show/, @calls), 'Specify "show" action');
    ok((grep /RoomOfRequirement/, @calls), 'Specify parameter name');
};

subtest '[execute_crm_resource_refresh_and_check]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(record_info => sub { return; });
    $hacluster->redefine(check_cluster_state => sub { return; });
    $hacluster->redefine(crm_check_resource_location => sub { return; });
    $hacluster->redefine(assert_script_run => sub { return; });
    $hacluster->redefine(script_output => sub { return 'Output value=0'; });

    set_var('SAP_SID', 'QES');
    execute_crm_resource_refresh_and_check(instance_type => 'type', instance_id => '01', instance_hostname => 'hostname');
    $hacluster->redefine(script_output => sub { return 'Output value=1'; });
    dies_ok { execute_crm_resource_refresh_and_check(instance_type => 'type', instance_id => '01', instance_hostname => 'hostname') } 'Expected value';
};

subtest '[check_online_nodes]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    # Define 3 configured nodes, and 3 online nodes
    my @outputs = ('|3|', 'Node List:
  * Online: [ node01 node02 node03 ]');
    my @calls;
    $hacluster->redefine(script_output => sub { shift @outputs; });
    $hacluster->redefine(record_info => sub { push @calls, $_[1]; });

    hacluster::check_online_nodes();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /Online nodes: 3/ } @calls), 'Correct number of online nodes');
    ok((any { /Configured nodes: 3/ } @calls), 'Correct number of configured nodes');
};

subtest '[check_online_nodes] proceed_on_failure' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    # Define 3 configured nodes, and 2 online nodes
    my @outputs = ('|3|', 'Node List:
  * Online: [ node01 node02 ]');
    my @calls;
    $hacluster->redefine(script_output => sub { shift @outputs; });
    $hacluster->redefine(record_info => sub { push @calls, $_[1]; });

    hacluster::check_online_nodes(proceed_on_failure => 1);
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /Online nodes: 2/ } @calls), 'Correct number of online nodes');
    ok((any { /Configured nodes: 3/ } @calls), 'Correct number of configured nodes');
};

subtest '[check_online_nodes] proceed_on_failure zero nodes' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    # Define 0 configured nodes
    my @outputs = ('|0|', 'Node List:
  * Online: [ node01 ]');
    my @calls;
    $hacluster->redefine(script_output => sub { shift @outputs; });
    $hacluster->redefine(record_info => sub { push @calls, $_[1]; });

    hacluster::check_online_nodes(proceed_on_failure => 1);
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /Online nodes: 1/ } @calls), 'Correct number of online nodes');
    ok((any { /Configured nodes: 0/ } @calls), 'Correct number of configured nodes');
};

subtest '[check_online_nodes] unexpected text failok' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @outputs = ('|unexpected text|', 'Node List:
  * Online: [ node01 node02 ]');
    my @calls;
    $hacluster->redefine(script_output => sub { shift @outputs; });
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO --> ', @_)); });

    dies_ok { hacluster::check_online_nodes(); } 'Cluster has 0 nodes';
    like($@, qr/Cluster has 0 nodes/, 'Cluster has 0 nodes');
};

subtest '[check_online_nodes] zero nodes failok' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    # Define 0 configured nodes
    my @outputs = ('|0|', 'Node List:
  * Online: [ node01 ]');
    $hacluster->redefine(script_output => sub { shift @outputs; });
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO --> ', @_)); });

    dies_ok { hacluster::check_online_nodes(); } 'Cluster has 0 nodes';
    like($@, qr/Cluster has 0 nodes/, 'Cluster has 0 nodes');
};

subtest '[check_online_nodes] mismatched nodes failok' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    # Define 0 configured nodes
    my @outputs = ('|3|', 'Node List:
  * Online: [ node01 node02 ]');
    $hacluster->redefine(script_output => sub { shift @outputs; });
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO --> ', @_)); });

    dies_ok { hacluster::check_online_nodes(); } 'Mismatched online and configured nodes';
    like($@, qr/Not all configured nodes are online/, 'Not all configured nodes are online');
};

subtest '[check_online_nodes] cannot calculate online nodes failok' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    # Define 0 configured nodes
    my @outputs = ('|3|', 'Node List:');
    $hacluster->redefine(script_output => sub { shift @outputs; });
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO --> ', @_)); });

    dies_ok { hacluster::check_online_nodes(); } 'Failed to calculate online nodes';
    like($@, qr/Could not calculate online nodes/, $@);
};

subtest '[check_cluster_state]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_run => sub { push @calls, $_[0]; });
    $hacluster->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $hacluster->redefine(check_online_nodes => sub { push @calls, 'check_online_nodes'; });
    $hacluster->redefine(script_output => sub { return 'crmshver=4.4.2'; });

    check_cluster_state();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /crm_mon/ } @calls), 'At least one crm_mon call found');
    ok((any { /check_online_nodes/ } @calls), 'check_online_nodes called');
    ok((any { /crm_verify/ } @calls), 'At least one crm_verify call found');
};

subtest '[check_cluster_state] assert calls normally' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_run => sub { push @calls, 'script_run'; });
    $hacluster->redefine(assert_script_run => sub { push @calls, 'assert_script_run'; });
    $hacluster->redefine(check_online_nodes => sub { return; });
    $hacluster->redefine(script_output => sub { return 'crmshver=4.4.2'; });

    check_cluster_state();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((all { /assert_script_run/ } @calls), 'check_cluster_state used assert_script_run');
};

subtest '[check_cluster_state] proceed_on_failure' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_run => sub { push @calls, 'script_run'; });
    $hacluster->redefine(assert_script_run => sub { push @calls, 'assert_script_run'; });
    $hacluster->redefine(check_online_nodes => sub { return; });
    $hacluster->redefine(script_output => sub { return 'crmshver=4.4.2'; });

    check_cluster_state(proceed_on_failure => 1);
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((all { /^script_run$/ } @calls), 'check_cluster_state used script_run');
};

subtest '[check_cluster_state] migration scenario' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_run => sub { push @calls, 'script_run'; });
    $hacluster->redefine(assert_script_run => sub { push @calls, 'assert_script_run'; });
    $hacluster->redefine(check_online_nodes => sub { return; });
    $hacluster->redefine(script_output => sub { return 'crmshver=4.4.2'; });
    set_var('HDDVERSION', 'some version');

    check_cluster_state();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((scalar(grep { /^script_run$/ } @calls)) == 1, 'One call with script_run');
    ok((scalar(grep { /assert_script_run/ } @calls) == (scalar(@calls) - 1)), 'Remaining calls with assert_script_run');
    set_var('HDDVERSION', undef);
};

subtest '[check_cluster_state] old crmsh' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_run => sub { push @calls, $_[0]; });
    $hacluster->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $hacluster->redefine(check_online_nodes => sub { push @calls, 'check_online_nodes'; });
    $hacluster->redefine(script_output => sub { return 'crmshver=3.6.0'; });

    check_cluster_state();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /crm_mon -s/ } @calls), 'crm_mon -s used');
    ok((none { /check_online_nodes/ } @calls), 'check_online_nodes not called');
};

subtest '[wait_for_idle_cluster] with ClusterTools2' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    # Simulate ClusterTools2 installed
    $hacluster->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $hacluster->redefine(script_output => sub { push @calls, $_[0]; return 'S_IDLE'; });

    wait_for_idle_cluster();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /ClusterTools2/ } @calls), 'ClusterTools2 checked');
    ok((any { /cs_wait_for_idle/ } @calls), 'cs_wait_for_idle used');
};

subtest '[wait_for_idle_cluster] without ClusterTools2' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    # Simulate ClusterTools2 not installed
    $hacluster->redefine(script_run => sub { push @calls, $_[0]; return 1; });
    $hacluster->redefine(script_output => sub { push @calls, $_[0]; return 'S_IDLE'; });

    wait_for_idle_cluster();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /ClusterTools2/ } @calls), 'ClusterTools2 checked');
    ok((any { /crmadmin/ } @calls), 'crmadmin used');
};

subtest '[wait_for_idle_cluster] timeout' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    # Simulate ClusterTools2 installed
    $hacluster->redefine(script_run => sub { return 0; });
    $hacluster->redefine(script_output => sub { return 'S_NOT_IDLE'; });

    dies_ok { wait_for_idle_cluster(); } 'Cluster not idle in 120s';
    like($@, qr/Cluster was not idle for 120 seconds/, $@);

    dies_ok { wait_for_idle_cluster(timeout => 30); } 'Cluster not idle in 30s';
    like($@, qr/Cluster was not idle for 30 seconds/, $@);
};

subtest '[prepare_console_for_fencing]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(select_console => sub { push @calls, @_; });
    $hacluster->redefine(send_key => sub { push @calls, $_[0]; });

    prepare_console_for_fencing();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /^ctrl\-l$/ } @calls), 'Ctrl-L detected');
    ok((any { /^ret$/ } @calls), 'Return detected');
    ok((scalar(grep { /^root-console$/ } @calls) == 2), 'root-console selected twice');
    ok((any { /await_console/ } @calls), 'await_console argument passed');
};

subtest '[crm_get_failcount] Mandatory args' => sub {
    dies_ok { crm_get_failcount() } 'Fail with missing mandatory arg: resource';
};

subtest '[crm_get_failcount] Command composition' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_output =>
          sub { @calls = @_; return 'scope=status  name=fail-count-rsc_sap_QES_ASCS01 value=0'; });

    crm_get_failcount(crm_resource => 'rsc_sap_QES_ASCS01');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /crm_failcount/, @calls), 'Execute "crm_failcount" command.');
    ok((grep /--query/, @calls), 'Query current value using "--query"');
    ok((grep /--resource/, @calls), 'Query value for specific resource using "--resource"');
};

subtest '[crm_get_failcount] Verify result' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_output => sub { return 'scope=status  name=fail-count-rsc_sap_QES_ASCS01 value=0'; });
    is crm_get_failcount(crm_resource => 'rsc_sap_QES_ASCS01'), '0', 'Return fail count: 0';
    $hacluster->redefine(script_output => sub { return 'scope=status  name=fail-count-rsc_sap_QES_ASCS01 value=1000'; });
    is crm_get_failcount(crm_resource => 'rsc_sap_QES_ASCS01'), '1000', 'Return fail count: 1000';
};

subtest '[crm_resources_by_class] Mandatory args' => sub {
    dies_ok { crm_resources_by_class() } 'Fail with missing argument "primitive_class"';
};

subtest '[crm_resources_by_class] Command composition' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_output => sub { @calls = @_; return 'primitive rsc_sap_QES_ASCS01 SAPInstance'; });
    $hacluster->redefine(assert_script_run => sub { return; });
    crm_resources_by_class(primitive_class => 'SAPInstance');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /crm/, @calls), 'Execute "crm" command.');
    ok((grep /configure/, @calls), 'Execute "configure" subcommand.');
    ok((grep /show/, @calls), 'Execute "show" option.');
    ok((grep /related:SAPInstance/, @calls), 'Include class');
    ok((grep /| grep primitive/, @calls), 'Show only "primitive" lines');
};

subtest '[crm_resources_by_class] Result verification' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_output => sub { return 'primitive rsc_sap_QES_ASCS01 SAPInstance
primitive rsc_sap_QES_ERS02 SAPInstance'; });
    $hacluster->redefine(assert_script_run => sub { return; });
    my @resources_found = @{crm_resources_by_class(primitive_class => 'SAPInstance')};
    note("\n  -->  " . join("\n  -->  ", @resources_found));
    ok((grep /SCS/, @resources_found), 'Result finds ASCS instance name');
    ok((grep /ERS/, @resources_found), 'Result finds ERS instance name');
};

subtest '[crm_wait_failcount] Check exceptions' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(crm_get_failcount => sub { return 0; });

    dies_ok { crm_wait_failcount() } "Fail with missing argument: crm_resource";
    dies_ok { crm_wait_failcount(crm_resource => 'raspberry') } 'Fail with fail count not increasing';
};

subtest '[crm_wait_failcount]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(crm_get_failcount => sub { return 1; });

    ok(crm_wait_failcount(crm_resource => 'raspberry'), 'PASS with fail count increasing');
};

subtest '[crm_resource_locate] Mandatory args' => sub {
    dies_ok { crm_resource_locate }, 'Missing mandaroty $args{crm_resource}';
};

subtest '[crm_resource_locate] Verify cmd' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_output => sub { @calls = @_; return 'someting'; });
    crm_resource_locate(crm_resource => 'rsc_sap_QES_ASCS01');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /crm/, @calls), 'Execute "crm" command.');
    ok((grep /resource/, @calls), 'Add "resource" subcommand.');
    ok((grep /locate/, @calls), 'Include "locate" argument.');
    ok((grep /rsc_sap_QES_ASCS01/, @calls), 'Specify resource name.');
};

subtest '[crm_resource_locate] Verify cmd' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_output => sub { return 'resource rsc_sap_QES_ASCS01 is running on: qesscs01lc14'; });
    is crm_resource_locate(crm_resource => 'rsc_sap_QES_ASCS01'), 'qesscs01lc14', 'Return correct hostname';
};

subtest '[crm_resource_meta_show]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(script_output => sub { @calls = @_; return; });

    crm_resource_meta_show(resource => 'Hogwarts', meta_argument => 'RoomOfRequirement');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /crm/, @calls), 'Execute "crm" command.');
    ok((grep /resource meta Hogwarts/, @calls), 'Call "meta" option');
    ok((grep /show/, @calls), 'Specify "show" action');
    ok((grep /RoomOfRequirement/, @calls), 'Specify meta-arg name');
};

subtest '[crm_resource_meta_set] Set value' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(assert_script_run => sub { @calls = @_; return; });
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    crm_resource_meta_set(resource => 'Hogwarts', meta_argument => 'RoomOfRequirement', argument_value => 'enter');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /crm/, @calls), 'Execute "crm" command.');
    ok((grep /resource meta Hogwarts/, @calls), 'Call "meta" option');
    ok((grep /set/, @calls), 'Specify "set" action');
    ok((grep /RoomOfRequirement/, @calls), 'Specify meta-arg name');
    ok((grep /enter/, @calls), 'Specify meta-arg value');
};

subtest '[crm_resource_meta_set] Delete meta-argument' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;
    $hacluster->redefine(assert_script_run => sub { @calls = @_; return; });
    $hacluster->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    crm_resource_meta_set(resource => 'Hogwarts', meta_argument => 'RoomOfRequirement');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /delete/, @calls), 'Specify "delete" action');

};

subtest '[crm_list_options] no op for crm verions older than 5.0.0' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;

    my $this_test_ver;
    $hacluster->redefine(script_output => sub { push @calls, $_[0]; return $this_test_ver; });
    $hacluster->redefine(record_info => sub { note(join(' ', "RECORD_INFO ( $this_test_ver )-->", @_)); });

    foreach ('crmshver=0.1.1', 'crmshver=4.3.2', 'crmshver=4.4.1', 'crmshver=4.4.2', 'crmshver=4.5.2') {
        @calls = ();
        $this_test_ver = $_;
        my $res = crm_list_options();
        ok $res eq 0, "res:$res is 0 if any crmsh with valid version is available";
        ok((all { /rpm.*crms/ } @calls), 'script_output should only be user for rpm but it gets ' . "\n  -->  " . join("\n  -->  ", @calls));
    }
};

subtest '[crm_list_options] ver newer than 5.0.0' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;

    my $this_test_ver;
    $hacluster->redefine(script_output => sub {
            return $this_test_ver if ($_[0] =~ /rpm/);
            # Intentionally do not collect rpm calls
            push @calls, $_[0];
            return <<END;
<pacemaker-result api-version="1.23" request="crm_resource --list-options primitive --output-as xml">
  <resource-agent name="primitive-meta" version="1.2.3">
  </resource-agent>
  <status code="0" message="OK"/>
</pacemaker-result>
END
    });
    $hacluster->redefine(record_info => sub { note(join(' ', "RECORD_INFO ( $this_test_ver )-->", @_)); });

    foreach ('5.0.0', '5.0.4', '6.0.0') {
        $this_test_ver = "crmshver=$_";
        @calls = ();
        my $res = crm_list_options();
        note("\n  -->  " . join("\n  -->  ", @calls));
        ok $res > 0, "res:$res is great than 0 for a valid XML";
        ok((any { /crm_resource.*primitive/ } @calls), 'There is a call to crm_resource --list-options primitive');
        ok((any { /crm_resource.*fencing/ } @calls), 'There is a call to crm_resource --list-options fencing');
        ok((any { /crm_attribute.*cluster/ } @calls), 'There is a call to crm_attribute --list-options cluster');
    }
};

subtest '[crm_list_options] invalid xml' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @calls;

    my $this_test_ver;
    $hacluster->redefine(script_output => sub {
            return "crmshver=$this_test_ver" if ($_[0] =~ /rpm/);
            # Intentionally do not collect rpm calls
            push @calls, $_[0];
            # Intentionally invalid XML
            return <<END;
<<<pacemaker-result api-version="1.23" request="crm_resource --list-options primitive --output-as xml">
  <resource-agent name="primitive-meta" version="1.2.3">
  </resource-agent>
  <status code="0" message="OK"/>
<__/pacemaker-result>
END
    });
    $hacluster->redefine(record_info => sub { note(join(' ', "RECORD_INFO ( $this_test_ver )-->", @_)); });

    $this_test_ver = '5.0.0';
    my $res = crm_list_options();
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res < 0, "res:$res is less than 0 for invalid xml";
    # All 3 commands has to be executed even if one has an issue
    ok((any { /crm_resource.*primitive/ } @calls), 'There is a call to crm_resource --list-options primitive');
    ok((any { /crm_resource.*fencing/ } @calls), 'There is a call to crm_resource --list-options fencing');
    ok((any { /crm_attribute.*cluster/ } @calls), 'There is a call to crm_attribute --list-options cluster');
};

subtest 'return sbd device list by running crm sbd status [get_sbd_devices]' => sub {
    my $output = <<'EOF';
# status of sdb.service:
Node                          |Active      |Enable         |Since
2nodes-node01:       |YES          |YES              | active since: Tue 2025-07-22 09:45:21
2nodes-node02:       |YES          |YES              | active since: Tue 2025-07-22 09:45:21

# Status of the sbd disk watcher process on sbdcommand-node01:
|-3059 sbd: watcher: /dev/disk/by-path/lun-0 - slot : 0 --uuid xxxxxxxxxxxxx
|-3060 sbd: watcher: /dev/disk/by-path/lun-4 - slot : 0 --uuid xxxxxxxxxxxxx

# Status of the sbd disk watcher process on sbdcommand-node02:
|-3058 sbd: watcher: /dev/disk/by-path/lun-0 - slot : 0 --uuid xxxxxxxxxxxxx
|-3061 sbd: watcher: /dev/disk/by-path/lun-4 - slot : 0 --uuid xxxxxxxxxxxxx

# Watchdog info:
Node.                    |Device                    |Driver           |Kernel Timeout
2nodes-node01  |/dev/watchdog.   | <unknown>    | 10
2nodes-node02  |/dev/watchdog.   | <unknown>    | 10
EOF

    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_output => sub { return $output });
    my @devices_node01 = get_sbd_devices("sbdcommand-node01");

    my $expect_value = ['/dev/disk/by-path/lun-0', '/dev/disk/by-path/lun-4'];
    is_deeply(\@devices_node01, $expect_value, 'Get sbd devices for node01 successfully');

    my @devices_node02 = get_sbd_devices("sbdcommand-node02");
    is_deeply(\@devices_node02, $expect_value, 'Get sbd devices for node02 successfully');
};

subtest 'parse result of command "crm sbd configure show disk_metadata" [parse_sbd_metadata]' => sub {
    my $output = <<'EOF';
INFO: crm sbd configure show disk_metadata
==Dumping header on disk /dev/disk/by-path/xxxxx
Header version  : 2.1
UUID            :
Number of slots: 123
Sector size: 123
Timeout (watchdog)  : 15
Timeout (allocate)  : 2
Timeout (loop)      : 1
Timeout (msgwait)   : 30
==Header on disk /dev/disk/by-path/xxxxxxx is dumped

==Dumping header on disk /dev/disk/by-path/yyyy
Header version  : 2.1
UUID            : 123
Number of slots: 123
Sector size: 123
Timeout (watchdog) : 16
Timeout (allocate) : 3
Timeout (loop)     : 2
Timeout (msgwait)  : 32
==Header on disk /dev/disk/by-path/yyyyyyy is dumped
EOF

    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_output => sub { return $output });
    my @sbd_conf = parse_sbd_metadata();

    my $expect_value = [
        {
            device_name => '/dev/disk/by-path/xxxxx',
            metadata => {
                watchdog => 15,
                allocate => 2,
                loop => 1,
                msgwait => 30,
            }
        },
        {
            device_name => '/dev/disk/by-path/yyyy',
            metadata => {
                watchdog => 16,
                allocate => 3,
                loop => 2,
                msgwait => 32,
            }
        }
    ];
    is_deeply(\@sbd_conf, $expect_value, 'Parse crm sbd configure show disk_metadata successfully');
};

subtest '[list_configured_sbd] ' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my $mock_out = 'SBD_DEVICE="/dev/disk/by-id/scsi-1;/dev/disk/by-id/scsi-2;/dev/disk/by-id/scsi-3"';
    $hacluster->redefine(script_output => sub { return $mock_out; });
    $hacluster->redefine(script_run => sub { return '0'; });
    $hacluster->redefine(assert_script_run => sub { return '0'; });
    my @sbd_devices = @{list_configured_sbd()};
    note("\n  -->  " . join("\n  -->  ", @sbd_devices));
    ok((any { /\/dev\/disk\/by-id\/scsi-1/ } @sbd_devices), 'First SBD device');
    ok((any { /\/dev\/disk\/by-id\/scsi-2/ } @sbd_devices), 'Second SBD device');
    ok((any { /\/dev\/disk\/by-id\/scsi-3/ } @sbd_devices), 'Third SBD device');
};

subtest '[list_configured_sbd] Return empty ARRAY if there is no SBD config present' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_run => sub { return '1'; });
    $hacluster->redefine(assert_script_run => sub { return '0'; });
    ok(!@{list_configured_sbd()}, 'Return empty ARRAY');
};

subtest '[sbd_device_report]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_output => sub {
            return 'list_out' if grep /list/, @_;
            return 'dump_out' if grep /dump/, @_;
    });
    my $report = sbd_device_report(device_list => ['/dev/a']);
    note("\n  -->  " . join("\n  -->  ", $report));

    ok($report =~ /list_out/, 'Report contains "sbd list" command output');
    ok($report =~ /dump_out/, 'Report contains "sbd dump" command output');
};

subtest '[sbd_device_report] Expected device count check' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    $hacluster->redefine(script_output => sub { return 'sbd out'; });
    my $report = sbd_device_report(expected_sbd_devices_count => '1', device_list => ['/dev/a']);
    note("\n  -->  " . join("\n  -->  ", $report));
    ok($report =~ /PASS/, 'Pass with matching SBD device count');
};

subtest '[get_fencing_type] ' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my %tested_values = (
        'external/sbd' => 'primitive some-name stonith:external/sbd \\',
        'fence_azure_arm' => 'primitive rsc_st_azure stonith:fence_azure_arm \\',
    );
    my @tested_keys = keys(%tested_values);
    $hacluster->redefine(script_output => sub { return $tested_values{shift(@tested_keys)}; });
    is get_fencing_type, $_, "Return correct fencing type '$_'" foreach @tested_keys;
};

subtest '[generate_lun_list]' => sub {
    my $hacluster = Test::MockModule->new('hacluster', no_auto => 1);
    my @results = ();
    $hacluster->redefine(script_run => sub { push @results, $_[0]; });
    my $tgt_ip_port = '10.0.0.2:3260';
    $hacluster->redefine(script_output => sub { return $tgt_ip_port; });
    my $iqn = 'iqn.2026-02.unit.test';
    $hacluster->redefine(lio_show_iqn => sub { return $iqn; });
    my $numluns = 3;
    set_var('CLUSTER_INFOS', 'cluster:2:' . $numluns);
    generate_lun_list();
    set_var('CLUSTER_INFOS', undef);
    note("\n --> " . join("\n --> ", @results));
    ok(@results == $numluns, 'Correct number of LUNs');
    foreach my $i (0 .. 2) { ok($results[$i] =~ /.+$tgt_ip_port.+$iqn-lun\-$i/, "Correct LUN path [$i]"); }
};

done_testing;
