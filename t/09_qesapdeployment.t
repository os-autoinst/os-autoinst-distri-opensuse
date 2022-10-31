use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use List::Util qw(any);
use testapi 'set_var';
use qesapdeployment;
set_var('QESAP_CONFIG_FILE', 'MARLIN');

subtest '[qesap_get_inventory] upper case' => sub {
    my $inventory_path = qesap_get_inventory('NEMO');
    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/root/qe-sap-deployment/terraform/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_get_inventory] lower case' => sub {
    my $inventory_path = qesap_get_inventory('nemo');
    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/root/qe-sap-deployment/terraform/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_create_folder_tree] default' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    qesap_create_folder_tree();
    note("\n  -->  " . join("\n  -->  ", @calls));
    is $calls[0], 'mkdir -p /root/qe-sap-deployment';
};

subtest '[qesap_create_folder_tree] user specified deployment_dir' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    qesap_create_folder_tree();
    note("\n  -->  " . join("\n  -->  ", @calls));
    set_var('QESAP_DEPLOYMENT_DIR', undef);
    is $calls[0], 'mkdir -p /DORY';
};

subtest '[qesap_get_deployment_code] from default github' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    qesap_get_deployment_code();
    set_var('QESAP_DEPLOYMENT_DIR', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok any { /git.*clone.*github.*com\/SUSE\/qe-sap-deployment.*DORY/ } @calls;
};

subtest '[qesap_get_deployment_code] from fork' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    set_var('QESAP_INSTALL_GITHUB_REPO', 'WHALE');
    qesap_get_deployment_code();
    set_var('QESAP_DEPLOYMENT_DIR', undef);
    set_var('QESAP_INSTALL_GITHUB_REPO', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok any { /git.*clone.*https:\/\/WHALE.*DORY/ } @calls;
};

subtest '[qesap_get_deployment_code] from branch' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    set_var('QESAP_INSTALL_GITHUB_BRANCH', 'TED');
    qesap_get_deployment_code();
    set_var('QESAP_DEPLOYMENT_DIR', undef);
    set_var('QESAP_INSTALL_GITHUB_BRANCH', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok any { /git.*clone.*--branch.*TED/ } @calls;
};

subtest '[qesap_get_deployment_code] from a release' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    set_var('QESAP_INSTALL_VERSION', 'CORAL');
    # set to test that it is ignored
    set_var('QESAP_INSTALL_GITHUB_REPO', 'WHALE');
    qesap_get_deployment_code();
    note("\n  -->  " . join("\n  -->  ", @calls));
    set_var('QESAP_INSTALL_VERSION', undef);
    set_var('QESAP_INSTALL_GITHUB_REPO', undef);
    ok any { /curl.*github.com\/SUSE\/qe-sap-deployment\/archive\/refs\/tags\/vCORAL\.tar\.gz.*-ovCORAL\.tar\.gz/ } @calls;
    ok any { /tar.*[xvf]+.*vCORAL\.tar\.gz/ } @calls;
};

subtest '[qesap_ansible_cmd]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN');
    note("\n  -->  " . join("\n  -->  ", @calls));
    like $calls[0], qr/ansible.*all.*-i.*ocean\/inventory.yaml.*-u.*cloudadmin.*-b.*--become-user=root.*-a.*"FINDING"/;
};

subtest '[qesap_ansible_cmd] filter and user' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN', filter => 'NEMO', user => 'DARLA');
    note("\n  -->  " . join("\n  -->  ", @calls));

    like $calls[0], qr/.*NEMO.*-u.*DARLA/;
};

subtest '[qesap_ansible_cmd] no cmd' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    dies_ok { qesap_ansible_cmd(provider => 'OCEAN') } "Expected die for missing cmd";
};

subtest '[qesap_execute] simpler call' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 0;
    my $cmd = 'GILL';
    my $expected_log_name = "qesap_exec_$cmd.log.txt";
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });

    $qesap->redefine(script_run => sub { push @calls, $_[0]; return $expected_res });
    my $res = qesap_execute(cmd => $cmd);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok any { /.*qesap.py.*-c.*-b.*$cmd\s+.*tee.*$expected_log_name/ } @calls;
    ok $res == $expected_res;
};

subtest '[qesap_execute] cmd_options' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 0;
    my $cmd = 'GILL';
    my $cmd_options = '--tankgang';
    my $expected_log_name = 'qesap_exec_' . $cmd . '__tankgang.log.txt';
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });

    $qesap->redefine(script_run => sub { push @calls, $_[0]; });
    qesap_execute(cmd => $cmd, cmd_options => $cmd_options);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok any { /.*$cmd\s+$cmd_options.*tee.*$expected_log_name/ } @calls;
};

subtest '[qesap_execute] failure' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 1;
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return $expected_res });
    my $res = qesap_execute(cmd => 'GILL');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res == $expected_res;
};

subtest '[qesap_get_nodes_number]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    my $cloud_provider = 'POLPETTE';
    set_var('PUBLIC_CLOUD_PROVIDER', $cloud_provider);
    set_var('QESAP_CONFIG_FILE', 'MELANZANE_FRITTE');

    my $tmp_folder = '/FESTA';
    note("-->tmp_folder=$tmp_folder");
    set_var('QESAP_DEPLOYMENT_DIR', $tmp_folder);

    my $inv_path = "$tmp_folder/terraform/" . lc $cloud_provider . '/inventory.yaml';
    note("-->inv_path=$inv_path");

    my $str = <<END;
all:
  children:
    hana:
      hosts:
        vmhana01:
          ansible_host: 1.2.3.4
          ansible_python_interpreter: /usr/bin/python3
        vmhana02:
          ansible_host: 1.2.3.5
          ansible_python_interpreter: /usr/bin/python3

    iscsi:
      hosts:
        vmiscsi01:
          ansible_host: 1.2.3.6
          ansible_python_interpreter: /usr/bin/python3

  hosts: null
END

    $qesap->redefine(script_output => sub { push @calls, $_[0]; return $str; });

    my $res = qesap_get_nodes_number();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    set_var('QESAP_CONFIG_FILE', undef);
    set_var('QESAP_DEPLOYMENT_DIR', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    is $res, 3, 'Number of agents like expected';
    like $calls[0], qr/cat $inv_path/;

};

done_testing;
