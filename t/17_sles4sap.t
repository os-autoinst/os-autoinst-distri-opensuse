use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap;

sub undef_vars {
    set_var($_, undef) for qw(
      INSTANCE_ALIAS
      INSTANCE_TYPE
      INSTANCE_IP_CIDR
      HOSTS_SHARED_DIRECTORY
      SAP_INSTANCES
      INSTANCE_SID
      _SECRET_SAP_MASTER_PASSWORD
      ASCS_PRODUCT_ID
      INSTANCE_ID);
}

subtest '[prepare_swpm]' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(assert_script_run => sub { return 0 });
    $sles4sap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap->redefine(script_output => sub { return 1; });
    my %input_vars = (sapcar_bin_path => '/sapinst/SAPCAR',
        sar_archives_dir => '/sapinst/',
        swpm_sar_filename => 'SWPM10SP36_4-20009701.SAR',
        target_path => '/tmp/SWPM');

    is $mockObject->prepare_swpm(%input_vars), '/tmp/SWPM/sapinst', 'Pass with returning correct username';

    # Fail with missing arguments
    foreach my $argument (keys %input_vars) {
        my $original_value = $input_vars{$argument};
        $input_vars{$argument} = undef;
        dies_ok { $mockObject->prepare_swpm(%input_vars) } "Fail with missing argument: '$argument'";
        $input_vars{$argument} = $original_value;
    }

    $sles4sap->redefine(assert_script_run => sub { die if grep /test/, @_; return 0; });
    dies_ok { $mockObject->prepare_swpm(%input_vars) } "Fail with missing executable 'sapinst' in path";

};

subtest '[is_instance_type_supported]' => sub {
    my $mockObject = sles4sap->new();
    my @supported_values = qw(ASCS HDB ERS PAS AAS);
    my @unsupported_values = ('ASC', 'HD', 'DB', '00', 'ASCS00', ' ', '');

    foreach (@supported_values) { is $mockObject->is_instance_type_supported($_), $_,
          "Return instance type with supported value '$_'."; }
    foreach (@unsupported_values) { dies_ok { $mockObject->is_instance_type_supported($_) }
        "Fail with missing argument or unsupported value:'$_'"; }
    dies_ok { $mockObject->is_instance_type_supported() } 'Fail with undefined argument';
};

subtest '[get_nw_instance_name] Test expected failures.' => sub {
    my $mockObject = sles4sap->new();
    my $instance_id = '00';
    my $sap_sid = 'EN2';
    my %passing_values = (
        ASCS => "ASCS$instance_id",
        ERS => "ERS$instance_id",
        PAS => "D$instance_id",
        AAS => "D$instance_id"
    );

    foreach (keys %passing_values) {
        is $mockObject->get_nw_instance_name(sap_sid => $sap_sid, instance_id => $instance_id, instance_type => $_),
          $passing_values{$_}, "Pass with path for $_: $passing_values{$_}";
    }
};

subtest '[netweaver_installation_data] Test passing values.' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(get_nw_instance_name => sub { return '/usr/sap/something' });
    $sles4sap->redefine(get_sidadm => sub { return 'loladm' });
    set_var('INSTANCE_SID', 'LOL');
    set_var('_SECRET_SAP_MASTER_PASSWORD', 'CorrectHorseBatteryStaple');
    set_var('INSTANCE_ALIAS', 'virtual_hostname');
    my $product_id = 'SAP:PRODUCT.ID';
    my @sap_instances = ('HDB', 'ASCS', 'ERS', 'PAS', 'AAS');
    foreach (@sap_instances) { set_var($_ . '_PRODUCT_ID', $product_id); }

    my %correct_values = (
        'HDB,ASCS,ERS,PAS,AAS' => 'all supported instances defined',
        'ASCS,ERS' => '2 supported instances defined',
        ASCS => 'single instance defined'
    );

    foreach (keys(%correct_values)) {
        set_var('SAP_INSTANCES', $_);
        ok $mockObject->netweaver_installation_data(), "Pass with $correct_values{$_}";
    }
    undef_vars();
};

subtest '[netweaver_installation_data] Test expected failures.' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(get_sidadm => sub { return 'loladm' });
    my $product_id = 'SAP:PRODUCT.ID';
    my @sap_instances = ('HDB', 'ASCS', 'ERS', 'PAS', 'AAS');
    foreach (@sap_instances) { set_var($_ . '_PRODUCT_ID', $product_id); }

    set_var('SAP_INSTANCES', 'HDB;ASCS;ERS;PAS;AAS');
    dies_ok { $mockObject->netweaver_installation_data() } "Expected failure with incorrect delimiter used ';'";
    set_var('SAP_INSTANCES', '');
    dies_ok { $mockObject->netweaver_installation_data() } "Expected failure with parameter 'SAP_INSTANCES' empty";
    set_var('SAP_INSTANCES', undef);
    dies_ok { $mockObject->netweaver_installation_data() } "Expected failure with parameter 'SAP_INSTANCES' undefined";
    undef_vars();
};

subtest '[netweaver_installation_data] Test returned values - instance data' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(get_sidadm => sub { return 'loladm' });
    my $sap_dir_placeholder = 'DIR00';
    $sles4sap->redefine(get_nw_instance_name => sub { return $sap_dir_placeholder });

    # Set required variables
    my $sap_sid = 'LOL';
    my $product_id = 'SAP:PRODUCT.ID';
    my $instance_id = 0;
    my @sap_instances = ('HDB', 'ASCS', 'ERS', 'PAS', 'AAS');
    set_var('SAP_INSTANCES', join(',', @sap_instances));
    set_var('INSTANCE_SID', $sap_sid);
    set_var('_SECRET_SAP_MASTER_PASSWORD', 'CorrectHorseBatteryStaple');
    foreach (@sap_instances) { set_var($_ . '_PRODUCT_ID', $product_id); }

    my $nw_install_data = $mockObject->netweaver_installation_data();

    foreach (@sap_instances) {
        my $instance_data = $nw_install_data->{instances}{$_};
        my $sap_dir = $_ eq 'HDB' ? undef : $sap_dir_placeholder;    # DB export does not have directory
        is $instance_data->{instance_id}, sprintf("%02d", $instance_id), "Pass with correct 'instance_sid' for instance type '$_'";
        is $instance_data->{product_id}, $product_id, "Pass with correct 'product_id' for instance type '$_'";
        is $instance_data->{instance_dir_name}, $sap_dir, "Pass with correct 'instance_dir' for instance type '$_'";
        $instance_id++;
    }
    undef_vars();
};

subtest '[netweaver_installation_data] Test returned values - common variables' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(get_nw_instance_name => sub { return 'DIR00' });
    $sles4sap->redefine(get_sidadm => sub { return 'loladm' });
    # Set required variables
    my $sap_sid = 'LOL';
    my $product_id = 'SAP:PRODUCT.ID';
    my $sappassword = 'CorrectHorseBatteryStaple';
    set_var('SAP_INSTANCES', ('ASCS'));
    set_var('INSTANCE_SID', $sap_sid);
    set_var('_SECRET_SAP_MASTER_PASSWORD', $sappassword);
    set_var('ASCS_PRODUCT_ID', $product_id);

    my $nw_install_data = $mockObject->netweaver_installation_data();

    is $nw_install_data->{instance_sid}, $sap_sid, "Pass with correct 'instance_sid'";
    is $nw_install_data->{sidadm}, lc $sap_sid . 'adm', "Pass with correct 'sidadm'";
    is $nw_install_data->{sidadm_uid}, '1001', "Pass with correct 'sidadm_uid'";
    is $nw_install_data->{sapsys_gid}, '1002', "Pass with correct 'sapsys_gid'";
    is $nw_install_data->{sap_master_password}, $sappassword, "Pass with correct 'sap_master_password'";
    is $nw_install_data->{sap_directory}, "/usr/sap/$sap_sid", "Pass with correct 'sap_directory'";
    undef_vars();
};

subtest '[sapcontrol_process_check] Test expected failures.' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap->redefine(sapcontrol => sub { return '3'; });
    my %argument_values = (
        sidadm => 'sidadm', instance_id => '00', expected_state => 'started');

    $argument_values{expected_state} = undef;
    dies_ok { $mockObject->sapcontrol_process_check(%argument_values) } "Expected failure with missing argument: 'expected_state'";
    $argument_values{expected_state} = 'started';

    foreach ('stoped', 'stated', 'sstopped', 'startedd', 'somethingweird', ' started ') {
        my $orig_value = $argument_values{expected_state};
        $argument_values{expected_state} = $_;
        dies_ok { $mockObject->sapcontrol_process_check(%argument_values) } "Fail with unsupported 'expected_state' value: \'$_'";
        $argument_values{expected_state} = $orig_value;
    }

    $sles4sap->redefine(sapcontrol => sub { return '3' });
    $argument_values{expected_state} = 'stopped';
    dies_ok { $mockObject->sapcontrol_process_check(%argument_values) } 'Fail with services not stopped.';
    $sles4sap->redefine(sapcontrol => sub { return '4' });
    $argument_values{expected_state} = 'started';
    dies_ok { $mockObject->sapcontrol_process_check(%argument_values) } 'Fail with services not started.';
};

subtest '[sapcontrol_process_check] Function PASS.' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %argument_values = (instance_id => '00', expected_state => 'started');

    $sles4sap->redefine(sapcontrol => sub { return '4' });
    $argument_values{expected_state} = 'stopped';
    is $mockObject->sapcontrol_process_check(%argument_values), 'stopped', 'Pass with services being stopped (RC4)';
    $sles4sap->redefine(sapcontrol => sub { return '3' });
    $argument_values{expected_state} = 'started';
    is $mockObject->sapcontrol_process_check(%argument_values), 'started', 'Pass with services being started (RC3)';
};

subtest '[share_hosts_entry] All args defined' => sub {
    my $mockObject = sles4sap->new();
    my @calls;
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(assert_script_run => sub { push @calls, @_; return 0 });
    $sles4sap->redefine(script_run => sub { push @calls, @_; return 0 });
    set_var('INSTANCE_TYPE', 'Astrid');
    $mockObject->share_hosts_entry(virtual_hostname => 'Olivia', virtual_ip => '192.168.1.1', shared_directory_root => '/Peter/Walter');

    is $calls[1], 'mkdir -p /Peter/Walter/hosts', "Test 'mkdir' command";
    is $calls[2], "echo '192.168.1.1 Olivia' >> /Peter/Walter/hosts/Astrid", "Test 'hosts' file entry";

    undef_vars();
};

subtest '[share_hosts_entry] Test default values' => sub {
    my $mockObject = sles4sap->new();
    my @calls;
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(assert_script_run => sub { push @calls, @_; return 0 });
    $sles4sap->redefine(script_run => sub { push @calls, @_; return 0 });
    set_var('INSTANCE_ALIAS', 'Olivia');
    set_var('INSTANCE_TYPE', 'Astrid');
    set_var('INSTANCE_IP_CIDR', '192.168.1.1/24');

    $mockObject->share_hosts_entry();

    is $calls[1], 'mkdir -p /sapmnt/hosts', "Test 'mkdir' command";
    is $calls[2], "echo '192.168.1.1 Olivia' >> /sapmnt/hosts/Astrid", "Test 'hosts' file entry";
    undef_vars();
};

subtest '[share_hosts_entry] Test default values' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(assert_script_run => sub { return 1; });
    $sles4sap->redefine(assert_script_run => sub { return 1; });
    set_var('INSTANCE_ALIAS', 'Olivia');
    set_var('INSTANCE_TYPE', 'Astrid');
    set_var('INSTANCE_IP_CIDR', '192.168.1.1/24');

    dies_ok { $mockObject->share_hosts_entry(shared_directory_root => '/Peter/Walter') } 'Fail if directory is not mount point';
    undef_vars();
};

subtest '[add_hosts_file_entries]' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    my @cat_commands;
    $sles4sap->redefine(assert_script_run => sub { push @cat_commands, @_; });

    $mockObject->add_hosts_file_entries();
    is $cat_commands[0], 'cat /sapmnt/hosts/* >> /etc/hosts', 'Check correct command composition.';
};

subtest '[get_sidadm]' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);

    dies_ok { $mockObject->get_sidadm() } "Fail with missing 'INSTANCE_SID' parameter";
    set_var('INSTANCE_SID', 'BEL');

    $sles4sap->redefine(script_run => sub { return 1; });
    dies_ok { $mockObject->get_sidadm('must_exist' => 1) } 'Fail if sidadm does not exist [RC1]';

    $sles4sap->redefine(script_run => sub { return 0; });
    is $mockObject->get_sidadm('must_exist' => 1), 'beladm', 'Pass if sidadm does exist [RC0]';

    is $mockObject->get_sidadm(), 'beladm', 'Generate correct username.';
    undef_vars();
};

subtest '[sapcontrol] Test expected failures' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap->redefine(get_sidadm => sub { return 'abcadm'; });
    my %arguments = (instance_id => '00', webmethod => 'GoOverThere');

    $sles4sap->redefine(script_output_retry_check => sub { return 'abcadm'; });
    $sles4sap->redefine(script_run => sub { return '0'; });
    $arguments{webmethod} = '';
    dies_ok { $mockObject->sapcontrol(%arguments) } 'Fail without specifying webmethod';
    $arguments{webmethod} = 'GoOverThere';

    $arguments{instance_id} = '';
    dies_ok { $mockObject->sapcontrol(%arguments) } 'Fail without specifying instance_id';
    $arguments{instance_id} = '00';

    $sles4sap->redefine(script_output_retry_check => sub { return 'ninasharp'; });
    dies_ok { $mockObject->sapcontrol(%arguments) } 'Fail if running under incorrect user';
    $sles4sap->redefine(script_output_retry_check => sub { return 'abcadm'; });

    $arguments{remote_hostname} = 'charlie';
    dies_ok { $mockObject->sapcontrol(%arguments) } 'Remote execution fail without sidadm password';
};

subtest '[sapcontrol] Test using correct values' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    my @calls;
    $sles4sap->redefine(script_output => sub { return 'command output' });
    $sles4sap->redefine(script_output_retry_check => sub { return 'abcadm'; });
    $sles4sap->redefine(script_run => sub { push(@calls, @_); return '0'; });
    $sles4sap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap->redefine(get_sidadm => sub { return 'abcadm'; });

    my %arguments = (instance_id => '00', webmethod => 'GoOverThere');

    is $mockObject->sapcontrol(%arguments), '0', 'Return correct RC';
    is $calls[0], 'sapcontrol -nr 00 -function GoOverThere', 'Execute correct command';
    $arguments{additional_args} = 'And Return Back';
    $mockObject->sapcontrol(%arguments);
    is $calls[1], 'sapcontrol -nr 00 -function GoOverThere And Return Back', 'Execute correct command with additional args';
    $arguments{additional_args} = '';

    $arguments{return_output} = 1;
    is $mockObject->sapcontrol(%arguments), 'command output', 'Return command output instead of RC';
    $arguments{return_output} = 0;

    $arguments{remote_hostname} = 'charlie';
    $arguments{sidadm_password} = 'Fr@ncis';
    $mockObject->sapcontrol(%arguments);
    is $calls[2], 'sapcontrol -nr 00 -host charlie -user abcadm Fr@ncis -function GoOverThere',
      'Execute correct command for remote execution';
};

subtest '[get_instance_profile_path]' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    set_var('INSTANCE_SID', 'EN2');
    set_var('INSTANCE_TYPE', 'ASCS');

    $sles4sap->redefine(get_sidadm => sub { return 'abcadm'; });
    $sles4sap->redefine(script_run => sub { return '0'; });
    $sles4sap->redefine(script_output => sub { return 'EN2_ASCS00_sapen2as'; });
    $sles4sap->redefine(get_nw_instance_name => sub { return 'ASCS00'; });
    is $mockObject->get_instance_profile_path(instance_id => '00', instance_type => 'ASCS'), '/sapmnt/EN2/profile/EN2_ASCS00_sapen2as', 'Return correct ASCS profile path.';
    undef_vars();
};

subtest '[get_remote_instance_number]' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    set_var('INSTANCE_ID', '00');
    my $sapcontrol_out = '
30.11.2023 07:15:42
GetSystemInstanceList
OK
hostname, instanceNr, httpPort, httpsPort, startPriority, features, dispstatus
sapen2er, 1, 50113, 50114, 0.5, ENQREP, GREEN
sapen2as, 0, 50013, 50014, 1, MESSAGESERVER|ENQUE, GREEN';
    $sles4sap->redefine(sapcontrol => sub { return $sapcontrol_out });

    is $mockObject->get_remote_instance_number(instance_type => 'ASCS'), '00', 'Return correct ASCS instance number.';
    is $mockObject->get_remote_instance_number(instance_type => 'ERS'), '01', 'Return correct ERS instance number.';

    undef_vars();
};

done_testing;
