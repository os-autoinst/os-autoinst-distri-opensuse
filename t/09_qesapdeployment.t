use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
use NetAddr::IP;

use testapi 'set_var';
use sles4sap::qesap::qesapdeployment;

set_var('QESAP_CONFIG_FILE', 'MARLIN');

sub create_qesap_prepare_env_mocks_noret {
    my $called_functions = shift;
    my $mock_func = shift;
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);

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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);

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

subtest '[qesap_get_inventory] upper case' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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

subtest '[qesap_get_deployment_code] from a specific release' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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

subtest '[qesap_get_deployment_code] from the latest release' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_output => sub { return "MYGITHUBREPO/tag/v1.0.0" });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{terraform_dir} = '/BRUCE/OCEAN';
            return (%paths);
    });
    set_var('QESAP_INSTALL_VERSION', 'latest');
    # set to test that it is ignored
    set_var('QESAP_INSTALL_GITHUB_REPO', 'WHALE');

    qesap_get_deployment_code();

    set_var('QESAP_INSTALL_VERSION', undef);
    set_var('QESAP_INSTALL_GITHUB_REPO', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /curl.*github.com\/SUSE\/qe-sap-deployment\/archive\/refs\/tags\/v1.0.0\.tar\.gz.*-ov1.0.0\.tar\.gz/ } @calls), 'Get latest release archive from github');
    ok((any { /tar.*[xvf]+.*v1.0.0\.tar\.gz/ } @calls), 'Decompress the release archive');
};

subtest '[qesap_get_roles_code] from default github' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 0;
    my $cmd = 'GILL';

    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return $expected_res; });
    $qesap->redefine(script_retry => sub { push @calls, $_[0]; return $expected_res; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return ""; });
    # needed within the qesap_venv_cmd_exec as activating the vevn
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0] });

    my @res = qesap_execute(cmd => $cmd, logname => 'WALLABY_STREET');

    note("qesap_execute res[0]: $res[0]  res[1]: $res[1]");
    note("\n  -->  " . join("\n  -->  ", @calls));
    # command composition
    ok((any { /.*qesap\.py.*-c.*-b.*$cmd\s+/ } @calls), 'qesap.py cmd composition is fine');
    ok((any { /.*qesap\.py.*tee.*\/tmp\/WALLABY_STREET/ } @calls), 'qesap.py log redirection is fine');

    # venv activate/deactivate
    ok((any { /.*activate/ } @calls), 'virtual environment activated');
    ok((any { /.*deactivate/ } @calls), 'virtual environment deactivated');

    # redirect log to file
    ok((any { /.*qesap\.py.*tee.*\/tmp\/WALLABY_STREET/ } @calls), 'qesap.py log redirection is fine');

    ok $res[0] == $expected_res;
};

subtest '[qesap_execute] simplest call' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my @logs = ();
    my $expected_res = 0;
    my $cmd = 'GILL';
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { push @logs, $_[0]; note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return $expected_res; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths); });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return ""; });

    my @res = qesap_execute(cmd => $cmd, logname => 'WALLABY_STREET');

    note("qesap_execute res[0]: $res[0]  res[1]: $res[1]");
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*qesap\.py.*-c.*-b.*$cmd\s+/ } @calls), 'qesap.py cmd composition is fine');
    ok(($res[0] == $expected_res), 'The function return what is internally returned by the command call');
};

subtest '[qesap_execute] invalid timeout' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my $cmd = 'GILL';
    $qesap->redefine(record_info => sub { note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(upload_logs => sub { note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return ""; });

    dies_ok { qesap_execute(cmd => $cmd, logname => 'WALLABY_STREET', timeout => 0) } "Call qesap_exec with timeout 0 is invalid";
    note("\n  -->  " . join("\n  -->  ", @calls));

    @calls = ();
    dies_ok { qesap_execute(cmd => $cmd, logname => 'WALLABY_STREET', timeout => -1234) } "Call qesap_exec with negative timeout is invalid";
    note("\n  -->  " . join("\n  -->  ", @calls));
};

subtest '[qesap_execute] cmd_options' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return ""; });

    my @res = qesap_execute(cmd => $cmd, cmd_options => $cmd_options, logname => 'WALLABY_STREET');

    note("qesap_execute res[0]: $res[0]  res[1]: $res[1]");
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*$cmd\s+$cmd_options.*/ } @calls), 'cmd_options result in proper qesap-py command composition');
};

subtest '[qesap_execute] failure' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return ""; });

    my @res = qesap_execute(cmd => 'GILL', logname => 'WALLABY_STREET');

    note("\n  -->  " . join("\n  -->  ", @calls));
    note("qesap_execute res[0]: $res[0]  res[1]: $res[1]");
    ok $res[0] == $expected_res, 'result part of the return array is 1 when script_run fails';
};

subtest '[qesap_execute] check_logs' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    $qesap->redefine(enter_cmd => sub {
            push @calls, $_[0]; });
    $qesap->redefine(script_output => sub {
            push @calls, $_[0];
            return <<END
        terraform.init.log.txt
        terraform.apply.log.txt
END
              ; });

    my @res = qesap_execute(cmd => 'GILL', logname => 'WALLABY_STREET');

    note("qesap_execute res[0]: $res[0]  res[1]: $res[1]");
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res[1] =~ /\/WALLABY_STREET/, "File pattern '$res[1]' is okay";
    ok((any { /terraform.init.log.txt/ } @logs), 'terraform.init.log.txt in the list of uploaded logs');
};

subtest '[qesap_terraform_conditional_retry] pass at first' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(record_info => sub {
            note(join(' # ', 'RECORD_INFO -->', @_)); });
    my @return_list = ();
    $qesap->redefine(qesap_execute => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            my @results = (0, 'some_log_name');
            return @results; });

    my @res = qesap_terraform_conditional_retry(
        error_list => ['AERIS'],
        logname => 'WALLABY_STREET',
        retries => 5);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $res[0] == 0, "Check that the rc of the result $res[0] is 0";
    ok scalar @calls == 1, "Exactly '" . scalar @calls . "' as expected 1 retry";
};

subtest '[qesap_terraform_conditional_retry] retry after fail with expected error message' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(record_info => sub {
            note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_cluster_logs => sub { return 1; });
    my @return_list = ();
    # Reverse order than used in the execution,
    # so it simulate 2 consecutive fails and a PASS at 3rd attempt.
    push @return_list, 0;
    push @return_list, 1;
    push @return_list, 1;
    $qesap->redefine(qesap_execute => sub {
            my (%args) = @_;
            my $cmd = $args{cmd};
            $cmd .= " $args{cmd_options}" if $args{cmd_options};
            push @calls, $cmd;
            my @results = (pop @return_list, 0);
            return @results; });
    # Simulate qesap_execute always having 'AERIS' in the log
    $qesap->redefine(qesap_file_find_strings => sub { return 1; });
    #    $qesap->redefine(get_required_var => sub { return ''; });

    my @res = qesap_terraform_conditional_retry(
        error_list => ['AERIS'],
        logname => 'WALLABY_STREET',
        retries => 5);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $res[0] == 0, "Check that the rc of the result $res[0] is 0";
    ok scalar @calls == 3, "Exactly '" . scalar @calls . "' as expected 3 retry";
};

subtest '[qesap_terraform_conditional_retry] retry with destroy terraform' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my @return_list = (0, 0, 1, 0, 1);
    # Simulate sequence of return codes for qesap_execute,
    # and because the pop function is used, they are retrieved in reverse order: from right to left.
    # This sequence is simulating:
    # 1. terraform apply fails with 1
    # 2. terraform destroy, as part of the RETRY procedure, is passing
    # 3. retry terraform apply fails with 1
    # 4. re-retry terraform destroy fails with 1
    # 5. re-retry terraform apply PASS

    $qesap->redefine(record_info => sub {
            note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_execute => sub {
            my (%args) = @_;
            my $cmd = $args{cmd};
            $cmd .= " $args{cmd_options}" if $args{cmd_options};
            push @calls, $cmd;
            my @results = (pop @return_list, 0);
            return @results; });

    $qesap->redefine(qesap_file_find_strings => sub { return 1; });

    my @res = qesap_terraform_conditional_retry(
        error_list => ['AERIS'],
        logname => 'FOO',
        retries => 2,
        destroy => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    my @terraform_destroy = grep { $_ eq 'terraform -d' } @calls;
    ok scalar @terraform_destroy == 2, "Terraform destroy as expected 2 retry";
    ok $res[0] == 0, "Check that the rc of the result $res[0] is 0";
};

subtest '[qesap_terraform_conditional_retry] retry with destroy terraform and fail during destruction' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my @return_list = (42, 1);

    $qesap->redefine(record_info => sub {
            note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_execute => sub {
            my (%args) = @_;
            my $cmd = $args{cmd_options} ? $args{cmd} . " " . $args{cmd_options} : $args{cmd};
            push @calls, $cmd;
            my @results = (pop @return_list, 0);
            return @results; });

    $qesap->redefine(qesap_file_find_strings => sub { return 1; });

    my @res = qesap_terraform_conditional_retry(
        error_list => ['AERIS'],
        logname => 'FOO',
        retries => 2,
        destroy => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    my @terraform_destroy = grep { $_ eq 'terraform -d' } @calls;
    ok scalar @terraform_destroy == 1, "Terraform destroy as expected 1 retry";
    ok $res[0] == 42, "Check that the rc of the result $res[0] is 42";
};

subtest '[qesap_terraform_conditional_retry] dies if expected error message is not found' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    $qesap->redefine(record_info => sub {
            note(join(' # ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $qesap->redefine(qesap_execute => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return (1, 'log');
    });
    # Simulate that 'AERIS' is not in the log, ever
    $qesap->redefine(qesap_file_find_strings => sub { return 0; });

    my @res = qesap_terraform_conditional_retry(
        logname => 'WALLABY_STREET',
        error_list => ['AERIS'],
        retries => 5);
    # No retry if 'AERIS' is not in the log
    ok scalar @calls == 1, "Exactly '" . scalar @calls . "' as expected 1 retry";
    ok $res[0] == 1, "Check that the rc of the result $res[0] is 1";
};

subtest '[qesap_terraform_conditional_retry] test qesap_file_find_strings' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(record_info => sub {
            note(join(' # ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_cluster_logs => sub { return 1; });
    my @return_list = ();
    # Reverse order than used in the execution,
    # so it simulate 2 consecutive fails and a PASS at 3rd attempt.
    push @return_list, 0;
    push @return_list, 1;
    push @return_list, 1;
    $qesap->redefine(qesap_execute => sub {
            my (%args) = @_;
            my $cmd = $args{cmd};
            $cmd .= " $args{cmd_options}" if $args{cmd_options};
            push @calls, $cmd;
            my @results = (pop @return_list, 'SHARK.log');
            return @results; });
    # internally the function is using grep to search for a set of specific
    # error strings. Here is an example of grep result.
    #      'ERROR    OUTPUT:              "msg": "Timed out waiting for last boot time check (timeout=600)",';

    # The mock will return, within the function under test,
    # the result of the grep. grep return 0 in case of string match
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    my @res = qesap_terraform_conditional_retry(
        error_list => ['AERIS'],
        logname => 'WALLABY_STREET',
        retries => 5);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $res[0] == 0, "Check that the rc of the result $res[0] is 0";
};

subtest '[qesap_get_nodes_number]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
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

    my $res = qesap_get_nodes_number(provider => 'NEMO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is $res, 3, 'Number of agents like expected';
    like $calls[0], qr/cat.*\/CRUSH/;
};

subtest '[qesap_remote_hana_public_ips]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    set_var('PUBLIC_CLOUD_PROVIDER', 'EC2');
    $qesap->redefine(qesap_get_terraform_dir => sub { return '/path/to/qesap/terraform/dir'; });
    $qesap->redefine(script_output => sub { return '{"hana_public_ip":{"value":["10.0.1.1","10.0.1.2"]}}'; });

    my @ips = qesap_remote_hana_public_ips();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  IP-->  " . join("\n  IP-->  ", @ips));
    ok((any { /^10.0.1.1$/ } @ips), 'IP 1 matches');
    ok((any { /^10.0.1.2$/ } @ips), 'IP 2 matches');
};

subtest '[qesap_wait_for_ssh]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    my $duration = qesap_wait_for_ssh(host => '1.2.3.4');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /nc.*1\.2\.3\.4.*22/ } @calls), 'nc command properly composed with host and default port 22');
    ok($duration != -1, 'If pass does not return -1');
};

subtest '[qesap_wait_for_ssh] custom port' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    my $duration = qesap_wait_for_ssh(host => '1.2.3.4', port => 1234);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /nc.*1\.2\.3\.4.*1234/ } @calls), 'nc command properly composed with custom port 1234');
};

subtest '[qesap_wait_for_ssh] some failures' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @ansible_calls;
    my @crm_report_calls;
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
    $qesap->redefine(qesap_upload_crm_report => sub { my (%args) = @_; push @crm_report_calls, $args{host}; return 0; });
    $qesap->redefine(qesap_save_y2logs => sub { return 0; });
    my $cloud_provider = 'NEMO';
    set_var('PUBLIC_CLOUD_PROVIDER', $cloud_provider);

    qesap_cluster_logs();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  ANSIBLE_CMD-->  " . join("\n  ANSIBLE_CMD-->  ", @ansible_calls));
    note("\n  CRM_REPORT-->  " . join("\n  CRM_REPORT-->  ", @crm_report_calls));
    note("\n  SAVE_FILE-->  " . join("\n  SAVE_FILE-->  ", @save_file_calls));
    note("\n  LOG_FILES-->  " . join("\n  LOG_FILES-->  ", @logfile_calls));
    ok((any { /crm status/ } @ansible_calls), 'expected command executed remotely');
    ok((any { /.*hana0-crm_status\.txt/ } @logfile_calls), 'qesap_ansible_script_output_file called with the expected vmhana01 log file');
    ok((any { /.*hana1-crm_status\.txt/ } @logfile_calls), 'qesap_ansible_script_output_file called with the expected vmhana02 log file');
    ok((any { /.*BOUBLE.*/ } @save_file_calls), 'upload_logs is called with whatever filename returned by qesap_ansible_script_output_file');
    ok((any { /hana\[[0-1]\]/ } @crm_report_calls), 'upload_logs properly calls qesap_upload_crm_report with hostnames');
};

subtest '[qesap_cluster_logs] multi log command' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    $qesap->redefine(qesap_save_y2logs => sub { return 0; });
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    ok((any { /.*\/var\/log\/SALT\-crm_report/ } @calls), 'crm report file has the node name in it');
};

subtest '[qesap_upload_crm_report] ansible host query' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my @fetch_filename;

    $qesap->redefine(is_sle => sub { return 0; });
    $qesap->redefine(qesap_ansible_cmd => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0; });
    $qesap->redefine(qesap_ansible_fetch_file => sub {
            my (%args) = @_;
            push @fetch_filename, $args{file};
            return 0; });
    $qesap->redefine(upload_logs => sub { return 0; });

    qesap_upload_crm_report(provider => 'SAND', host => 'hana[0]');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  FETCH_FILENAME-->  " . join("\n  FETCH_FILENAME-->  ", @fetch_filename));
    ok((any { /.*\/var\/log\/vmhana01\-crm_report/ } @calls), 'crm report file has the node name in it');
    ok((any { /vmhana01\-crm_report\.tar/ } @fetch_filename), 'crm report fetch file is properly formatted');
};

subtest '[qesap_supportconfig_logs]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my $upload_log_called = 0;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(qesap_ansible_cmd => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0; });
    $qesap->redefine(qesap_ansible_fetch_file => sub { return 0; });
    $qesap->redefine(upload_logs => sub { $upload_log_called = 1; return 0; });

    qesap_supportconfig_logs(provider => 'SAND');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /.*supportconfig \-R.*/ } @calls), 'supportconfig is called');
    ok((any { /.*\/var\/tmp.*vmhana01.*supportconfig/ } @calls), 'supportconfig log file has the vmhana01 node name in it');
    ok((any { /.*\/var\/tmp.*vmhana02.*supportconfig/ } @calls), 'supportconfig log file has the vmhana02 node name in it');
    ok($upload_log_called eq 1), 'upload_log called';
};

subtest '[qesap_save_y2logs]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my $upload_log_called = 0;

    $qesap->redefine(qesap_ansible_cmd => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0; });
    $qesap->redefine(qesap_ansible_fetch_file => sub { return 0; });
    $qesap->redefine(upload_logs => sub { $upload_log_called = 1; return 0; });

    qesap_save_y2logs(provider => 'SAND', host => 'boo');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /.*save_y2logs \/tmp\/boo-y2logs.*/ } @calls), 'save_y2logs is called');
    ok((any { /.*chmod/ } @calls), 'chmod is called');
    ok($upload_log_called eq 1, 'upload_log called');
};

subtest '[qesap_calculate_deployment_name]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return 42; });

    my $result = qesap_calculate_deployment_name();

    ok($result eq '42', 'function return is proper deployment_name');
};

subtest '[qesap_calculate_deployment_name] with postfix' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return 42; });

    my $result = qesap_calculate_deployment_name('AUSTRALIA');

    ok($result eq 'AUSTRALIA42', 'function return is proper deployment_name');
};

subtest '[qesap_prepare_env] die for missing argument' => sub {
    dies_ok { qesap_prepare_env(); } "Expected die if called without provider arguments";
};

subtest '[qesap_prepare_env] integration test' => sub {
    # As less mock as possible
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);

    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_src} = '/REEF';
            $paths{qesap_conf_trgt} = '/SYDNEY.YAML';
            $paths{terraform_dir} = '/SPLASH';
            $paths{deployment_dir} = '/WAVE';
            $paths{roles_dir} = '/BRUCE';
            return (%paths);
    });
    $qesap->redefine(qesap_get_variables => sub { return; });
    $qesap->redefine(qesap_upload_logs => sub { return; });
    my @calls;
    my @retries;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(script_retry => sub { my ($cmd, %args) = @_; push @retries, $args{retry}; return 0; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'DENTIST'; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    qesap_prepare_env(provider => 'DONALDUCK');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /3/ } @retries), 'default retry times is 3 for qesap_pip_install and qesap_galaxy_install');
};

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

subtest '[qesap_prepare_env] qesap_yaml_replace' => sub {
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

subtest '[qesap_prepare_env] qesap_create_folder_tree/qesap_get_file_paths default' => sub {
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
    $qesap->redefine(script_retry => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return ""; });

    qesap_prepare_env(provider => 'DONALDUCK');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    is $calls[0], 'mkdir -p /root/qe-sap-deployment', "Default deployment_dir is /root/qe-sap-deployment";
    ok((any { qr/curl.*\/TORNADO -o \/root\/qe-sap-deployment\/scripts\/qesap\/MARLIN/ } @calls), 'Default location for the openQA conf.yaml templates');
};

subtest '[qesap_prepare_env] qesap_create_folder_tree/qesap_get_file_paths user specified deployment_dir' => sub {
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
    $qesap->redefine(script_retry => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_upload_logs => sub { return; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return ""; });

    set_var('QESAP_DEPLOYMENT_DIR', '/SUN');
    qesap_prepare_env(provider => 'DONALDUCK');
    set_var('QESAP_DEPLOYMENT_DIR', undef);

    note("\n  -->  " . join("\n  -->  ", @calls));
    is $calls[0], "mkdir -p /SUN", "Custom deploy location is /SUN";
};

sub create_qesap_prepare_env_mocks() {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
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
    $qesap->redefine(qesap_aws_create_config => sub { $qesap_create_aws_config_called = 1; });
    my $qesap_create_aws_credentials_called = 0;
    $qesap->redefine(qesap_aws_create_credentials => sub { $qesap_create_aws_credentials_called = 1; });

    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });

    qesap_prepare_env(provider => 'EC2', region => 'SOMEWHERE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok($qesap_create_aws_config_called, '$qesap_create_aws_config called');
    ok($qesap_create_aws_credentials_called, '$qesap_create_aws_credentials called');
};

subtest '[qesap_get_nodes_names]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
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

    my @hosts = qesap_get_nodes_names(provider => 'NEMO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  H-->  " . join("\n  H-->  ", @hosts));
    ok((scalar @hosts == 3), 'Exactly 3 hosts in the example inventory');
};

subtest '[qesap_add_server_to_hosts]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_ansible_cmd => sub { my (%args) = @_; push @calls, $args{cmd}; });
    set_var('PUBLIC_CLOUD_PROVIDER', 'NEMO');

    qesap_add_server_to_hosts(
        name => 'ISLAND.SEA',
        ip => '1.2.3.4');

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { qr/sed.*\/etc\/hosts/ } @calls), 'AWS Region matches');
};

subtest '[qesap_terraform_ansible_deploy_retry] no or unknown Ansible failures, no retry, error' => sub {
    # Simulate to call the qesap_terraform_ansible_deploy_retry but
    # error_detection does not find and known error in the log. It is something could
    # happen if this function is called after a failure of some kind error_detection
    # does not know, or if calling this function after a successful deployment.
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my $qesap_execute_calls = 0;

    # 0: unable to detect errors
    $qesap->redefine(qesap_ansible_error_detection => sub { return 0; });
    $qesap->redefine(qesap_execute => sub { $qesap_execute_calls++; return; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_terraform_ansible_deploy_retry(error_log => 'CORAL', provider => 'NEMO');

    ok $ret eq 1, "Return of qesap_terraform_ansible_deploy_retry '$ret' is expected 1";
    ok $qesap_execute_calls eq 0, "qesap_execute() never called (qesap_execute_calls: $qesap_execute_calls expected 0)";
};

subtest '[qesap_terraform_ansible_deploy_retry] no or unknown Ansible failures, no retry, error. More layers' => sub {
    # Like previous test but only mock testapi
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my $qesap_execute_calls = 0;
    my @calls;

    # Simulate we never find the string in the Ansible log file
    # Simulate grep within qesap_file_find_strings, within qesap_ansible_error_detection.
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 1; });

    $qesap->redefine(script_output => sub {
            push @calls, shift;
            return ''; });

    $qesap->redefine(qesap_execute => sub { $qesap_execute_calls++; return; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_terraform_ansible_deploy_retry(error_log => 'CORAL', provider => 'NEMO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $ret eq 1, "Return of qesap_terraform_ansible_deploy_retry '$ret' is expected 1";
    ok $qesap_execute_calls eq 0, "qesap_execute() never called (qesap_execute_calls: $qesap_execute_calls expected 0)";
};

subtest '[qesap_terraform_ansible_deploy_retry] generic Ansible failures, no retry' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my $qesap_execute_calls = 0;

    # 1 means a generic Ansible error
    $qesap->redefine(qesap_ansible_error_detection => sub { return 1; });
    $qesap->redefine(qesap_execute => sub { $qesap_execute_calls++; return; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_terraform_ansible_deploy_retry(error_log => 'CORAL', provider => 'NEMO');

    ok $ret == 1, "Return of qesap_terraform_ansible_deploy_retry '$ret' is expected 1";
    ok $qesap_execute_calls eq 0, "qesap_execute() never called (qesap_execute_calls: $qesap_execute_calls expected 0)";
};

subtest '[qesap_terraform_ansible_deploy_retry] no sudo password Ansible failures' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my $qesap_execute_calls = 0;

    # 3 means "no sudo password" error
    $qesap->redefine(qesap_ansible_error_detection => sub { return 3; });
    $qesap->redefine(qesap_execute => sub {
            $qesap_execute_calls++;
            # Simulate that the Ansible retry is just fine
            my @results = (0, 0);
            return @results;
    });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_terraform_ansible_deploy_retry(error_log => 'CORAL', provider => 'NEMO');

    ok $ret == 0, "Return of qesap_terraform_ansible_deploy_retry '$ret' is expected 0";
    ok $qesap_execute_calls eq 1, "qesap_execute() called once (qesap_execute_calls: $qesap_execute_calls expected 1)";
};

subtest '[qesap_terraform_ansible_deploy_retry] reboot timeout Ansible failures' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my $qesap_execute_calls = 0;

    # 2 means "reboot timeout" error
    $qesap->redefine(qesap_ansible_error_detection => sub { return 2; });
    $qesap->redefine(qesap_execute => sub {
            $qesap_execute_calls++;
            # Simulate that all other qesap.py calls are fine
            my @results = (0, 0);
            return @results;
    });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_terraform_ansible_deploy_retry(error_log => 'CORAL', provider => 'NEMO');

    ok $ret == 0, "Return of qesap_terraform_ansible_deploy_retry '$ret' is expected 0";
    # 3 = "terraform -d" + "terraform" + "ansible"
    ok $qesap_execute_calls eq 3, "qesap_execute() never called (qesap_execute_calls: $qesap_execute_calls expected 3)";
};

subtest '[qesap_create_cidr_from_ip]' => sub {
    my $ret;
    # ipv4 => /32
    $ret = qesap_create_cidr_from_ip(ip => '195.0.0.10');
    note("ipv4 result: $ret");
    ok($ret eq '195.0.0.10/32', 'IPv4 mask');

    # ipv6 => /128
    $ret = qesap_create_cidr_from_ip(ip => '2001:db8::1');
    my $exp = NetAddr::IP->new('2001:db8::1')->cidr;
    note("ipv6 result: $ret");
    like($ret, qr/\Q$exp\E/i, 'IPv6 mask');

    # replace existing mask
    $ret = qesap_create_cidr_from_ip(ip => '195.0.0.10/24');
    note("Strip old mask result: $ret");
    ok($ret eq '195.0.0.10/32', 'Existing mask is removed');

    # invalid ip with proceed_on_failure => undef
    $ret = qesap_create_cidr_from_ip(ip => 'not_an_ip', proceed_on_failure => 1);
    ok(!defined $ret, 'Invalid IP returns undef when proceed_on_failure is true');

    # invalid IP without proceed_on_failure => dies
    dies_ok { qesap_create_cidr_from_ip(ip => 'still_not_an_ip') } 'Dies on invalid IP without proceed_on_failure';
};

subtest '[qesap_ssh_intrusion_detection]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    my @calls;
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; return 0; });

    $qesap->redefine(script_output => sub {
            push @calls, $_[0];
            return <<'LOG';
2025-09-02T11:59:20.291296+0000 vmhana02 sshd[143121]: Connection closed by authenticating user root 1.2.3.4 port 42 [preauth]
2025-09-02T12:04:21.002220+0000 vmhana02 sshd[160619]: Connection closed by invalid user debian 1.2.3.4 port 42 [preauth]
2025-09-02T12:04:23.503717+0000 vmhana02 sshd[160801]: Connection closed by invalid user debian 1.2.3.4 port 42 [preauth]
LOG
    });

    $qesap->redefine(upload_logs => sub { note("UPLOAD_LOGS:$_[0]") });
    $qesap->redefine(qesap_ansible_script_output_file => sub {
            my (%args) = @_;
            push @calls, "ANSIBLE:" . $args{cmd};
            note("\n ###--> out_path : $args{out_path}");
            note("\n ###--> file : $args{file}");
            return 'BOUBLE_FILE.txt'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    qesap_ssh_intrusion_detection(provider => 'NEMO');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok 1;
};

done_testing;
