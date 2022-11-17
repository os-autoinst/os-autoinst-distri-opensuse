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
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            return (%paths);
    });

    my $inventory_path = qesap_get_inventory('NEMO');
    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/BRUCE/terraform/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_get_inventory] lower case' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            return (%paths);
    });

    my $inventory_path = qesap_get_inventory('nemo');
    note('inventory_path --> ' . $inventory_path);
    is $inventory_path, '/BRUCE/terraform/nemo/inventory.yaml', "inventory_path:$inventory_path is the expected one";
};

subtest '[qesap_create_folder_tree/qesap_get_file_paths] default' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return; });    # needed by qesap_get_file_paths

    qesap_create_folder_tree();

    note("\n  -->  " . join("\n  -->  ", @calls));
    is $calls[0], 'mkdir -p /root/qe-sap-deployment', "Default deploy location is /root/qe-sap-deployment";
};

subtest '[qesap_create_folder_tree/qesap_get_file_paths] user specified deployment_dir' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return; });    # needed by qesap_get_file_paths

    my $custom_dir = '/DORY';
    set_var('QESAP_DEPLOYMENT_DIR', $custom_dir);
    qesap_create_folder_tree();
    note("\n  -->  " . join("\n  -->  ", @calls));
    set_var('QESAP_DEPLOYMENT_DIR', undef);
    is $calls[0], "mkdir -p $custom_dir", "Custom deploy location is $custom_dir";
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

subtest '[qesap_ansible_cmd]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });

    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN');

    note("\n  -->  " . join("\n  -->  ", @calls));
    like $calls[0], qr/ansible.*all.*-i.*SIDNEY.*-u.*cloudadmin.*-b.*--become-user=root.*-a.*"FINDING"/, "Expected ansible command format";
};

subtest '[qesap_ansible_cmd] filter and user' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });
    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN', filter => 'NEMO', user => 'DARLA');
    note("\n  -->  " . join("\n  -->  ", @calls));

    like $calls[0], qr/.*NEMO.*-u.*DARLA/, "Expected filter and user in the ansible command format";
};

subtest '[qesap_ansible_cmd] no cmd' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    dies_ok { qesap_ansible_cmd(provider => 'OCEAN') } "Expected die for missing cmd";
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
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });

    $qesap->redefine(script_run => sub { push @calls, $_[0]; return $expected_res });
    my $res = qesap_execute(cmd => $cmd);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*qesap.py.*-c.*-b.*$cmd\s+.*tee.*$expected_log_name/ } @calls), 'qesap.py and log redirection are fine');
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
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return $expected_res });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{deployment_dir} = '/BRUCE';
            $paths{qesap_conf_trgt} = '/BRUCE/MARIANATRENCH';
            return (%paths);
    });

    my $res = qesap_execute(cmd => 'GILL');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res == $expected_res;
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

subtest '[qesap_ansible_script_output]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    my $cmr_status = qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*REEF.*"cmd='SWIM'"/ } @calls), 'proper ansible-playbooks command');
};


subtest '[qesap_ansible_script_output] cmd with spaces' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    my $cmr_status = qesap_ansible_script_output(cmd => 'SWIM SWIM SWIM', provider => 'NEMO', host => 'REEF');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*REEF.*"cmd='SWIM SWIM SWIM'"/ } @calls), 'proper ansible-playbooks command');
};


subtest '[qesap_ansible_script_output] download the playbook' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub {
            push @calls, $_[0];
            if ($_[0] =~ /test.*-e/) {
                return 1;
            }
            return 0;
    });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    my $cmr_status = qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /curl.*BRUCE/ } @calls), 'Playbook download with culr');
};

subtest '[qesap_ansible_script_output] custom user' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    my $cmr_status = qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF', user => 'GERALD');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-u GERALD/ } @calls), 'Custom ansible with user');
};

subtest '[qesap_ansible_script_output] root' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    my $cmr_status = qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF', root => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-b --become-user root/ } @calls), 'Ansible as root');
};

done_testing;
