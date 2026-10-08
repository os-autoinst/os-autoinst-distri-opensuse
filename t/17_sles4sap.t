use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any none);
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
      INSTANCE_ID
      ASSET_0);
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

subtest '[share_hosts_entry] All args defined' => sub {
    my $mockObject = sles4sap->new();
    my @calls;
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    $sles4sap->redefine(assert_script_run => sub { push @calls, @_; return 0 });
    $sles4sap->redefine(script_run => sub { push @calls, @_; return 0 });
    set_var('INSTANCE_TYPE', 'Astrid');
    $mockObject->share_hosts_entry(virtual_hostname => 'Olivia', virtual_ip => '192.168.1.1', shared_directory_root => '/Peter/Walter');

    note("\n  -->  " . join("\n  -->  ", @calls));
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

    note("\n  -->  " . join("\n  -->  ", @calls));
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

subtest '[fix_path] unsupported protocols' => sub {
    my $mockObject = sles4sap->new();
    foreach my $protocol (qw(something http ftp)) {
        dies_ok { $mockObject->fix_path($protocol . '://somethingelse') } "Die for unsupported protocol $protocol";
    }
};

subtest '[fix_path] supported protocols' => sub {
    my $mockObject = sles4sap->new();
    foreach my $protocol (qw(smb smbfs nfs)) {
        my @ret = $mockObject->fix_path($protocol . '://somethingelse/else/other/somefile.someextension');
        note("proto:$ret[0] path:$ret[1]");
        ok($ret[0] eq 'cifs' or $ret[0] eq 'nfs');
    }
};

subtest '[download_hana_assets_from_server]' => sub {
    my $mockObject = sles4sap->new();
    my $sles4sap = Test::MockModule->new('sles4sap', no_auto => 1);
    my @calls;
    # Return 1 to simulate no asset lock
    $sles4sap->redefine(script_run => sub { push @calls, @_; return 1; });
    $sles4sap->redefine(assert_script_run => sub { push @calls, @_; return; });
    $sles4sap->redefine(data_url => sub { return 'MY_DOWNLOAD_URL'; });
    $sles4sap->redefine(zypper_call => sub { push @calls, @_; return 1; });

    set_var('ASSET_0', 'Zanzibar');
    $mockObject->download_hana_assets_from_server();
    undef_vars();
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /wget.*MY_DOWNLOAD_URL/ } @calls), 'wget call');
};

done_testing;
