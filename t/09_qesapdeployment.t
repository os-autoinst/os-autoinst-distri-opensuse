use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
use Data::Dumper;

use testapi 'set_var';
use qesapdeployment;
set_var('QESAP_CONFIG_FILE', 'MARLIN');

subtest '[qesap_get_inventory] upper case' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{terraform_dir} = '/BRUCE';
            return (%paths);
    });

    my $inventory_path = qesap_get_inventory(provider => 'NEMO');

    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/BRUCE/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_get_inventory] lower case' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{terraform_dir} = '/BRUCE';
            return (%paths);
    });

    my $inventory_path = qesap_get_inventory(provider => 'nemo');

    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/BRUCE/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_get_deployment_code] from default github' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{terraform_dir} = '/BRUCE/OCEAN';
            return (%paths);
    });

    qesap_get_deployment_code();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /git.*clone.*github.*com\/SUSE\/qe-sap-deployment.*\/BRUCE/ } @calls), 'Default repo cloned in /BRUCE');
};

subtest '[qesap_get_deployment_code] symlinks' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{terraform_dir} = '/BRUCE/OCEAN';
            return (%paths);
    });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');

    qesap_get_deployment_code();

    set_var('QESAP_DEPLOYMENT_DIR', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ln.*-s.*aws.*ec2/ } @calls), 'Link AWS to EC2');
    ok((any { /ln.*-s.*gcp.*gce/ } @calls), 'Link GCP to GCE');
};

subtest '[qesap_get_deployment_code] from fork' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{terraform_dir} = '/BRUCE/OCEAN';
            return (%paths);
    });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    set_var('QESAP_INSTALL_GITHUB_REPO', 'WHALE');

    qesap_get_deployment_code();

    set_var('QESAP_DEPLOYMENT_DIR', undef);
    set_var('QESAP_INSTALL_GITHUB_REPO', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /git.*clone.*https:\/\/WHALE.*/ } @calls), 'Clone from fork WHALE');
};

subtest '[qesap_get_deployment_code] from branch' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{terraform_dir} = '/BRUCE/OCEAN';
            return (%paths);
    });
    set_var('QESAP_DEPLOYMENT_DIR', '/DORY');
    set_var('QESAP_INSTALL_GITHUB_BRANCH', 'TED');

    qesap_get_deployment_code();

    set_var('QESAP_DEPLOYMENT_DIR', undef);
    set_var('QESAP_INSTALL_GITHUB_BRANCH', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /git.*clone.*--branch.*TED/ } @calls), 'Checkout expected branch');
};

subtest '[qesap_get_deployment_code] from a release' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{terraform_dir} = '/BRUCE/OCEAN';
            return (%paths);
    });
    set_var('QESAP_INSTALL_VERSION', 'CORAL');
    # set to test that it is ignored
    set_var('QESAP_INSTALL_GITHUB_REPO', 'WHALE');

    qesap_get_deployment_code();

    set_var('QESAP_INSTALL_VERSION', undef);
    set_var('QESAP_INSTALL_GITHUB_REPO', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /curl.*github.com\/SUSE\/qe-sap-deployment\/archive\/refs\/tags\/vCORAL\.tar\.gz.*-ovCORAL\.tar\.gz/ } @calls), 'Get release archive from github');
    ok((any { /tar.*[xvf]+.*vCORAL\.tar\.gz/ } @calls), 'Decompress the release archive');
};

subtest '[qesap_get_roles_code] from default github' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{roles_dir} = '/BRUCE';
            return (%paths);
    });

    qesap_get_roles_code();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /git.*clone.*github.*com\/sap-linuxlab\/community\.sles-for-sap.*BRUCE/ } @calls), 'Git clone of sap-linuxlab/community.sles-for-sap is ok.');
};

subtest '[qesap_get_roles_code] from fork' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{roles_dir} = '/BRUCE';
            return (%paths);
    });
    set_var('QESAP_ROLES_INSTALL_GITHUB_REPO', 'WHALE');

    qesap_get_roles_code();

    set_var('QESAP_ROLES_INSTALL_GITHUB_REPO', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /git.*clone.*https:\/\/WHALE.*/ } @calls), 'Clone from fork WHALE');
};

subtest '[qesap_get_roles_code] from branch' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{roles_dir} = '/BRUCE';
            return (%paths);
    });
    set_var('QESAP_ROLES_INSTALL_GITHUB_BRANCH', 'TED');

    qesap_get_roles_code();

    set_var('QESAP_ROLES_INSTALL_GITHUB_BRANCH', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /git.*clone.*--branch.*TED/ } @calls), 'Checkout expected branch');
};

subtest '[qesap_execute] simple call integrate qesap_venv_cmd_exec' => sub {
    # Call qesap_execute without to mock qesap_venv_cmd_exec
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 0;
    my $cmd = 'GILL';
    my $expected_log_name = "qesap_exec_$cmd.log.txt";
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return $expected_res });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return $expected_res });

    my @res = qesap_execute(cmd => $cmd);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*qesap.py.*-c.*-b.*$cmd\s+.*tee.*$expected_log_name/ } @calls), 'qesap.py and log redirection are fine');
    ok((any { /.*activate/ } @calls), 'virtual environment activated');
    ok((any { /.*deactivate/ } @calls), 'virtual environment deactivated');
    ok $res[0] == $expected_res;
};

subtest '[qesap_execute] simple call' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 0;
    my $cmd = 'GILL';
    my $expected_log_name = "qesap_exec_$cmd.log.txt";
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return $expected_res;
    });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });

    my @res = qesap_execute(cmd => $cmd);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*qesap.py.*-c.*-b.*$cmd\s+.*tee.*$expected_log_name/ } @calls), 'qesap.py and log redirection are fine');
    ok $res[0] == $expected_res, 'The function return what is internally returned by the command call';
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
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return $expected_res;
    });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });

    qesap_execute(cmd => $cmd, cmd_options => $cmd_options);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*$cmd\s+$cmd_options.*tee.*$expected_log_name/ } @calls), 'cmd_options result in proper qesap-py command composition');
};

subtest '[qesap_execute] failure' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 1;
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return $expected_res;
    });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });

    my @res = qesap_execute(cmd => 'GILL');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res[0] == $expected_res, 'result part of the return array is 1 when script_run fails';
};

subtest '[qesap_execute] check_logs' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 1;
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return $expected_res;
    });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });

    my @res = qesap_execute(cmd => 'GILL');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res[1] =~ /\/.*.log.txt/, 'File pattern is okay';
};

subtest '[qesap_execute] logname' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 0;
    my $cmd = 'GILL';
    my $expected_log_name = "GURLE.log.txt";
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return $expected_res;
    });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });

    my @res = qesap_execute(cmd => $cmd, logname => $expected_log_name);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*qesap.py.*-c.*-b.*$cmd\s+.*tee.*\/tmp\/$expected_log_name/ } @calls), 'log redirection to user specified filename');
    ok $res[0] == $expected_res, 'The function return what is internally returned by the command call';
};

subtest '[qesap_file_find_string] success' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    # internally the function is using grep to search for a specific
    # error string. Here the result of the grep.
    my $log = 'ERROR    OUTPUT:              "msg": "Timed out waiting for last boot time check (timeout=600)",';
    # Create a mock to replace the script_run
    # The mock will return, within the function under test,
    # the result of the grep. grep return 0 in case of string match
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    my $res = qesap_file_find_string(file => 'JACQUES', search_string => 'Timed out waiting for last boot time check');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res == 1, 'Return is 1 when string is detected';
    ok((any { /grep.*JACQUES/ } @calls), 'Function calling grep against the log file');
};

subtest '[qesap_file_find_string] fail' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    # Create a mock to replace the script_output
    # The mock will return, within the function under test,
    # the result of the grep.
    # Here simulate that the grep does not return any match
    # grep return 1 in case of string NOT matching
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 1; });

    my $res = qesap_file_find_string(file => 'JACQUES', search_string => 'Timed out waiting for last boot time check');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res == 0, 'Return is 0 when string is not detected';
};

subtest '[qesap_get_nodes_number]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my $cloud_provider = 'NEMO';
    set_var('PUBLIC_CLOUD_PROVIDER', $cloud_provider);
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
    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });

    my $res = qesap_get_nodes_number();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is $res, 3, 'Number of agents like expected';
    like $calls[0], qr/cat.*\/CRUSH/;
};



subtest '[qesap_remote_hana_public_ips]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    $qesap->redefine(qesap_get_terraform_dir => sub { return '/path/to/qesap/terraform/dir'; });
    $qesap->redefine(script_output => sub { return '{"hana_public_ip":{"value":["10.0.1.1","10.0.1.2"]}}'; });

    my @ips = qesap_remote_hana_public_ips();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  C-->  " . join("\n  C-->  ", @ips));
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /^10.0.1.1$/ } @ips), 'IP 1 matches');
    ok((any { /^10.0.1.2$/ } @ips), 'IP 2 matches');
};

subtest '[qesap_wait_for_ssh]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    my $duration = qesap_wait_for_ssh(host => '1.2.3.4');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /nc.*1\.2\.3\.4.*22/ } @calls), 'nc command properly composed with host and default port 22');
    ok($duration != -1, 'If pass does not return -1');
};

subtest '[qesap_wait_for_ssh] custom port' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    my $duration = qesap_wait_for_ssh(host => '1.2.3.4', port => 1234);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /nc.*1\.2\.3\.4.*1234/ } @calls), 'nc command properly composed with custom port 1234');
};

subtest '[qesap_wait_for_ssh] some failures' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @return_list = ();
    push @return_list, 0;
    push @return_list, 1;
    push @return_list, 1;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return pop @return_list; });

    my $duration = qesap_wait_for_ssh(host => '1.2.3.4');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(scalar @calls == 3, 'nc called 3 times as it fails the first two');
    ok($duration != -1, 'If pass does not return -1');
};

subtest '[qesap_wait_for_ssh] timeout' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @return_list = ();
    # each loop sleep 5, and we call the function with a timeout of 1sec.
    # So only one loop is expected before to reach the timeout
    push @return_list, 1;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return pop @return_list; });

    my $duration = qesap_wait_for_ssh(host => '1.2.3.4', timeout => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok($duration == -1, 'If fails it returns -1');
};

subtest '[qesap_cluster_logs]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @ansible_calls;
    my @save_file_calls;
    my @logfile_calls;
    $qesap->redefine(qesap_ansible_script_output_file => sub {
            my (%args) = @_;
            push @ansible_calls, $args{cmd};
            push @logfile_calls, $args{file};
            note("\n ###--> out_path : $args{out_path}");
            note("\n ###--> file : $args{file}");
            return 'BOUBLE BOUBLE BOUBLE'; });
    $qesap->redefine(qesap_get_inventory => sub { return '/BERMUDAS/TRIANGLE'; });
    $qesap->redefine(script_run => sub { return 0; });
    $qesap->redefine(upload_logs => sub { push @save_file_calls, $_[0]; return; });
    $qesap->redefine(qesap_cluster_log_cmds => sub { return ({Cmd => 'crm status', Output => 'crm_status.txt'}); });
    $qesap->redefine(qesap_upload_crm_report => sub { return 0; });
    my $cloud_provider = 'NEMO';
    set_var('PUBLIC_CLOUD_PROVIDER', $cloud_provider);

    qesap_cluster_logs();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  ANSIBLE_CMD-->  " . join("\n  ANSIBLE_CMD-->  ", @ansible_calls));
    note("\n  SAVE_FILE-->  " . join("\n  SAVE_FILE-->  ", @save_file_calls));
    note("\n  LOG_FILES-->  " . join("\n  LOG_FILES-->  ", @logfile_calls));
    ok((any { /crm status/ } @ansible_calls), 'expected command executed remotely');
    ok((any { /.*vmhana01-crm_status\.txt/ } @logfile_calls), 'qesap_ansible_script_output_file called with the expected vmhana01 log file');
    ok((any { /.*vmhana02-crm_status\.txt/ } @logfile_calls), 'qesap_ansible_script_output_file called with the expected vmhana02 log file');
    ok((any { /.*BOUBLE.*/ } @save_file_calls), 'upload_logs is called with whatever filename returned by qesap_ansible_script_output_file');
};

subtest '[qesap_cluster_logs] multi log command' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @ansible_calls;
    my @logfile_calls;
    $qesap->redefine(qesap_ansible_script_output_file => sub {
            my (%args) = @_;
            push @ansible_calls, $args{cmd};
            push @logfile_calls, $args{file};
            note("\n ###--> out_path : $args{out_path}");
            note("\n ###--> file : $args{file}");
            return 'BOUBLE BOUBLE BOUBLE'; });
    $qesap->redefine(qesap_get_inventory => sub { return '/BERMUDAS/TRIANGLE'; });
    $qesap->redefine(script_run => sub { return 0; });
    $qesap->redefine(upload_logs => sub { return; });
    $qesap->redefine(qesap_cluster_log_cmds => sub { return ({Cmd => 'crm status', Output => 'crm_status.txt', Logs => ['ignore_me.txt', 'ignore_me_too.txt']}); });
    $qesap->redefine(qesap_upload_crm_report => sub { return 0; });
    my $cloud_provider = 'NEMO';
    set_var('PUBLIC_CLOUD_PROVIDER', $cloud_provider);

    qesap_cluster_logs();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  ANSIBLE_CMD-->  " . join("\n  ANSIBLE_CMD-->  ", @ansible_calls));
    note("\n  LOG_FILES-->  " . join("\n  LOG_FILES-->  ", @logfile_calls));
    ok((none { /.*ignore_me\.txt/ } @logfile_calls), 'ignore_me.txt is expected to be ignored');
    ok((none { /.*ignore_me_too\.txt/ } @logfile_calls), 'ignore_me_too.txt is expected to be ignored');
};

subtest '[qesap_upload_crm_report] die for missing mandatory arguments' => sub {
    dies_ok { qesap_upload_crm_report(); } "Expected die if called without arguments";
    dies_ok { qesap_upload_crm_report(provider => 'SAND'); } "Expected die if called without host";
    dies_ok { qesap_upload_crm_report(host => 'SALT'); } "Expected die if called without provider";
};

subtest '[qesap_upload_crm_report]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(is_sle => sub { return 0; });
    $qesap->redefine(qesap_ansible_cmd => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0; });
    $qesap->redefine(qesap_ansible_fetch_file => sub { return 0; });
    $qesap->redefine(upload_logs => sub { return 0; });

    qesap_upload_crm_report(provider => 'SAND', host => 'SALT');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /.*crm report.*/ } @calls), 'crm report is called');
};

subtest '[qesap_calculate_deployment_name]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return 42; });

    my $result = qesap_calculate_deployment_name();

    ok($result eq '42', 'function return is proper deployment_name');
};

subtest '[qesap_calculate_deployment_name] with postfix' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return 42; });

    my $result = qesap_calculate_deployment_name('AUSTRALIA');

    ok($result eq 'AUSTRALIA42', 'function return is proper deployment_name');
};

subtest '[qesap_prepare_env] die for missing argument' => sub {
    dies_ok { qesap_prepare_env(); } "Expected die if called without provider arguments";
};

sub create_qesap_prepare_env_mocks_noret {
    my $called_functions = shift;
    my $mock_func = shift;
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);

    # First mock functions returning nothing
    foreach (@{$mock_func}) {
        my $fn = $_;
        $called_functions->{$fn} = 0;
        $qesap->redefine($fn => sub { $called_functions->{$fn} = 1; return; });
    }
    return $qesap;
}

sub create_qesap_prepare_env_mocks_with_calls {
    my $called_functions = shift;
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);

    # then mock functions with some more complex return value
    $called_functions->{qesap_get_file_paths} = 0;
    $qesap->redefine(qesap_get_file_paths => sub {
            $called_functions->{qesap_get_file_paths} = 1;
            my %paths;
            $paths{qesap_conf_src} = '/REEF';
            $paths{qesap_conf_trgt} = '/SYDNEY.YAML';
            $paths{terraform_dir} = '/SPLASH';
            $paths{deployment_dir} = '/WAVE';
            $paths{roles_dir} = '/BRUCE';
            return (%paths);
    });
    $called_functions->{qesap_get_terraform_dir} = 0;
    $qesap->redefine(qesap_get_terraform_dir => sub { $called_functions->{qesap_get_terraform_dir} = 1; return '/SHELL'; });
    $called_functions->{qesap_execute} = 0;
    $qesap->redefine(qesap_execute => sub { $called_functions->{qesap_execute} = 1; return (0, "ALL GOOD"); });

    return $qesap;
}

subtest '[qesap_prepare_env]' => sub {
    my %called_functions;
    my @mock_func = qw(qesap_get_variables
      qesap_yaml_replace
      qesap_create_folder_tree
      qesap_get_deployment_code
      qesap_get_roles_code
      qesap_pip_install
      qesap_galaxy_install);
    my $qesap = create_qesap_prepare_env_mocks_noret(\%called_functions, \@mock_func);
    $qesap = create_qesap_prepare_env_mocks_with_calls(\%called_functions);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });

    qesap_prepare_env(provider => 'DONALDUCK');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    foreach (qw(qesap_get_file_paths qesap_get_terraform_dir qesap_execute)) {
        my $fn = $_;
        ok $called_functions{$fn} eq 1, "$fn called by qesap_prepare_env";
    }
    foreach (@mock_func) {
        my $fn = $_;
        ok $called_functions{$fn} eq 1, "$fn called by qesap_prepare_env";
    }
};

subtest '[qesap_prepare_env] openqa_variables' => sub {
    my %called_functions;
    my @mock_func = qw(qesap_get_variables
      qesap_yaml_replace
      qesap_create_folder_tree
      qesap_get_deployment_code
      qesap_get_roles_code
      qesap_pip_install
      qesap_galaxy_install);
    my $qesap = create_qesap_prepare_env_mocks_noret(\%called_functions, \@mock_func);
    $qesap = create_qesap_prepare_env_mocks_with_calls(\%called_functions);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });

    my %variables;
    qesap_prepare_env(openqa_variables => \%variables, provider => 'DONALDUCK');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $called_functions{qesap_get_variables} eq 0, "qesap_get_variables not called by qesap_prepare_env when using openqa_variables";
};

subtest '[qesap_prepare_env] only_configure' => sub {
    my %called_functions;
    my @mock_func = qw(qesap_get_variables
      qesap_yaml_replace
      qesap_create_folder_tree
      qesap_get_deployment_code
      qesap_get_roles_code
      qesap_pip_install
      qesap_galaxy_install);
    my $qesap = create_qesap_prepare_env_mocks_noret(\%called_functions, \@mock_func);
    $qesap = create_qesap_prepare_env_mocks_with_calls(\%called_functions);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });

    qesap_prepare_env(provider => 'DONALDUCK', only_configure => 1);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # Check that a specific subset of function is not executed in only_configure mode
    foreach (qw(qesap_create_folder_tree qesap_get_deployment_code qesap_get_roles_code qesap_pip_install qesap_galaxy_install)) {
        my $fn = $_;
        ok $called_functions{$fn} eq 0, "$fn not called by qesap_prepare_env in only_configure mode";
    }
};

subtest '[qesap_prepare_env/qesap_yaml_replace]' => sub {
    my %called_functions;
    my @mock_func = qw(qesap_get_variables);
    my $qesap = create_qesap_prepare_env_mocks_noret(\%called_functions, \@mock_func);
    $qesap = create_qesap_prepare_env_mocks_with_calls(\%called_functions);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });
    $called_functions{file_content_replace} = 0;
    $qesap->redefine(file_content_replace => sub { $called_functions{file_content_replace} = 1; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });

    qesap_prepare_env(provider => 'DONALDUCK', only_configure => 1);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $called_functions{file_content_replace} eq 1, "file_content_replace called by qesap_yaml_replace";
};

subtest '[qesap_prepare_env/qesap_create_folder_tree/qesap_get_file_paths] default' => sub {
    my %called_functions;
    my @mock_func = qw(qesap_get_variables
      qesap_yaml_replace
      qesap_get_deployment_code
      qesap_get_roles_code
      qesap_pip_install
      qesap_galaxy_install);
    my $qesap = create_qesap_prepare_env_mocks_noret(\%called_functions, \@mock_func);
    my @calls;
    $qesap->redefine(data_url => sub { return '/TORNADO'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });

    qesap_prepare_env(provider => 'DONALDUCK');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is $calls[0], 'mkdir -p /root/qe-sap-deployment', "Default deployment_dir is /root/qe-sap-deployment";
    ok((any { qr/curl.*\/TORNADO -o \/root\/qe-sap-deployment\/scripts\/qesap\/MARLIN/ } @calls), 'Default location for the openQA conf.yaml templates');
};

subtest '[qesap_prepare_env/qesap_create_folder_tree/qesap_get_file_paths] user specified deployment_dir' => sub {
    my %called_functions;
    my @mock_func = qw(qesap_get_variables
      qesap_yaml_replace
      qesap_get_deployment_code
      qesap_get_roles_code
      qesap_pip_install
      qesap_galaxy_install);
    my $qesap = create_qesap_prepare_env_mocks_noret(\%called_functions, \@mock_func);
    my @calls;
    $qesap->redefine(data_url => sub { return '/TORNADO'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });

    set_var('QESAP_DEPLOYMENT_DIR', '/SUN');
    qesap_prepare_env(provider => 'DONALDUCK');
    set_var('QESAP_DEPLOYMENT_DIR', undef);

    note("\n  -->  " . join("\n  -->  ", @calls));
    is $calls[0], "mkdir -p /SUN", "Custom deploy location is /SUN";
};

sub create_qesap_prepare_env_mocks() {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_src} = '/REEF';
            $paths{qesap_conf_trgt} = '/SYDNEY.YAML';
            $paths{terraform_dir} = '/SPLASH';
            $paths{deployment_dir} = '/WAVE';
            return (%paths);
    });
    $qesap->redefine(get_credentials => sub {
            my %data;
            $data{access_key_id} = 'X';
            $data{secret_access_key} = 'As mute as a fish';
            return (\%data);
    });

    $qesap->redefine(qesap_create_folder_tree => sub { return; });
    $qesap->redefine(qesap_get_deployment_code => sub { return; });
    $qesap->redefine(qesap_get_roles_code => sub { return; });
    $qesap->redefine(qesap_pip_install => sub { return; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_get_variables => sub { return; });
    $qesap->redefine(qesap_yaml_replace => sub { return; });
    $qesap->redefine(qesap_execute => sub { return; });
    $qesap->redefine(script_run => sub { return 1; });
    $qesap->redefine(qesap_upload_logs => sub { return; });
    return $qesap;
}

subtest '[qesap_prepare_env] AWS' => sub {
    my $qesap = create_qesap_prepare_env_mocks();

    my $qesap_create_aws_config_called = 0;
    $qesap->redefine(qesap_create_aws_config => sub { $qesap_create_aws_config_called = 1; });
    my $qesap_create_aws_credentials_called = 0;
    $qesap->redefine(qesap_create_aws_credentials => sub { $qesap_create_aws_credentials_called = 1; });

    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });

    qesap_prepare_env(provider => 'EC2');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok($qesap_create_aws_config_called, '$qesap_create_aws_config called');
    ok($qesap_create_aws_credentials_called, '$qesap_create_aws_credentials called');
};

subtest '[qesap_prepare_env::qesap_create_aws_config]' => sub {
    my $qesap = create_qesap_prepare_env_mocks();
    my @calls;
    my @contents;

    $qesap->redefine(script_output => sub { return 'eu-central-1'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'http://10.0.2.2/tests/'; });
    set_var('PUBLIC_CLOUD_REGION', 'eu-south-2');

    qesap_prepare_env(provider => 'EC2');

    set_var('PUBLIC_CLOUD_REGION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    ok((any { qr|mkdir -p ~/\.aws| } @calls), '.aws directory initialized');
    ok((any { qr|curl.+/files/config.+~/\.aws/config| } @calls), 'AWS Config file downloaded');
    ok((any { qr/eu-central-1/ } @calls), 'AWS Region matches');
    is $contents[0], 'config', "AWS config file: config is the expected value and got $contents[0]";
    like $contents[1], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_prepare_env::qesap_create_aws_config] fix quote' => sub {
    my $qesap = create_qesap_prepare_env_mocks();
    my @calls;
    my @contents;

    $qesap->redefine(script_output => sub { return '"eu-central-1"'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'http://10.0.2.2/tests/'; });
    set_var('PUBLIC_CLOUD_REGION', 'eu-south-2');

    qesap_prepare_env(provider => 'EC2');

    set_var('PUBLIC_CLOUD_REGION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    ok((any { qr/eu-central-1/ } @calls), 'AWS Region matches');
};

subtest '[qesap_prepare_env::qesap_create_aws_config] not solved template' => sub {
    my $qesap = create_qesap_prepare_env_mocks();
    my @contents;

    $qesap->redefine(script_output => sub { return '%REGION%'; });
    $qesap->redefine(assert_script_run => sub { return; });
    $qesap->redefine(save_tmp_file => sub { push @contents, $_[1]; });
    $qesap->redefine(autoinst_url => sub { return ''; });
    set_var('PUBLIC_CLOUD_REGION', 'eu-central-1');

    qesap_prepare_env(provider => 'EC2');

    set_var('PUBLIC_CLOUD_REGION', undef);
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    like $contents[0], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_prepare_env::qesap_create_aws_config] not solved template with quote' => sub {
    my $qesap = create_qesap_prepare_env_mocks();
    my @contents;

    $qesap->redefine(script_output => sub { return '"%REGION%"'; });
    $qesap->redefine(assert_script_run => sub { return; });
    $qesap->redefine(save_tmp_file => sub { push @contents, $_[1]; });
    $qesap->redefine(autoinst_url => sub { return ''; });
    set_var('PUBLIC_CLOUD_REGION', 'eu-central-1');

    qesap_prepare_env(provider => 'EC2');

    set_var('PUBLIC_CLOUD_REGION', undef);
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    like $contents[0], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_prepare_env::qesap_create_aws_config] not solved template and variable with quote' => sub {
    my $qesap = create_qesap_prepare_env_mocks();
    my @contents;
    $qesap->redefine(script_output => sub { return '%REGION%'; });
    $qesap->redefine(assert_script_run => sub { return; });
    $qesap->redefine(save_tmp_file => sub { push @contents, $_[1]; });
    $qesap->redefine(autoinst_url => sub { return ''; });
    set_var('PUBLIC_CLOUD_REGION', '"eu-central-1"');

    qesap_prepare_env(provider => 'EC2');

    set_var('PUBLIC_CLOUD_REGION', undef);
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    like $contents[0], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_is_job_finished]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @results = ();
    $qesap->redefine(script_output => sub {
            if ($_[0] =~ /100000/) { return "not json"; }
            if ($_[0] =~ /200000/) { return "{\"job\":{\"state\":\"donaldduck\"}}"; }
            if ($_[0] =~ /300000/) { return "{\"job\":{\"state\":\"running\"}}"; }
    });

    $qesap->redefine(get_required_var => sub { return ''; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    push @results, qesap_is_job_finished(100000);
    push @results, qesap_is_job_finished(200000);
    push @results, qesap_is_job_finished(300000);


    ok($results[0] == 0, "Consider 'running' state if the openqa job status response isn't JSON");
    ok($results[1] == 1, "Considered 'finished' state if the openqa job status response exists and isn't 'running'");
    ok($results[2] == 0, "Consider 'running' if the openqa job status response is 'running'");
};

done_testing;
