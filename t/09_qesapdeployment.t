use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
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
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });

    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN');

    note("\n  -->  " . join("\n  -->  ", @calls));
    like $calls[0], qr/.*source.*activate.*/, "Activate venv";
    ok((any { /.*ansible.*all.*-i.*SIDNEY.*-u.*cloudadmin.*-b.*--become-user=root.*-a.*"FINDING".*/ } @calls), "Expected ansible command format");
};

subtest '[qesap_ansible_cmd] verbose' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });

    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN', verbose => 1);

    note("\n  -->  " . join("\n  -->  ", @calls));
    like $calls[0], qr/.*source.*activate.*/, "Activate venv";
    ok((any { /.*ansible.*-vvvv.*/ } @calls), "Expected verbosity in ansible command");
};

subtest '[qesap_ansible_cmd] failok' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @calls_script_run;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_run => sub { push @calls_script_run, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });

    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN', failok => 1);

    note("\n  -->  " . join("\n  -->  ", @calls));
    note("\n  -->  " . join("\n  -->  ", @calls_script_run));

    ok((any { /.*ansible.*all.*-i.*SIDNEY.*-u.*cloudadmin.*-b.*--become-user=root.*-a.*"FINDING".*/ } @calls_script_run), "Expected ansible command format");
};

subtest '[qesap_ansible_cmd] filter and user' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN', filter => 'NEMO', user => 'DARLA');
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /.*activate/ } @calls), 'virtual environment activated');
    ok((any { /.*NEMO.*-u.*DARLA.*/ } @calls), "Expected filter and user in the ansible command format");
    ok((any { /.*deactivate/ } @calls), 'virtual environment deactivated');
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
    ok((any { /.*activate/ } @calls), 'virtual environment activated');
    ok((any { /.*deactivate/ } @calls), 'virtual environment deactivated');
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
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return 'ANEMONE' if ($_[0] =~ /cat.*/); });

    my $out = qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF');

    note("\n  out=$out");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*REEF.*"cmd='SWIM'"/ } @calls), 'proper ansible-playbooks command');
    like($out, qr/^ANEMONE/, 'the return is the content of the file stored by Ansible');
};

subtest '[qesap_ansible_script_output] output file' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return 'ANEMONE' if ($_[0] =~ /cat.*/); });

    my $out = qesap_ansible_script_output(cmd => 'SWIM',
        provider => 'NEMO',
        host => 'REEF',
        local_path => '/BERMUDA_TRIAGLE/',
        local_file => 'SUBMARINE.TXT');

    note("\n  out=$out");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-e.*out_path='\/BERMUDA_TRIAGLE\/'/ } @calls), 'proper ansible-playbooks local_path');
    ok((any { /ansible-playbook.*-e.*out_file='SUBMARINE.TXT'/ } @calls), 'proper ansible-playbooks local_file');
    like($out, qr/^\/BERMUDA_TRIAGLE\/SUBMARINE\.TXT/, 'the return is the path of the file stored by Ansible');
};

subtest '[qesap_ansible_script_output] failok' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @calls_scriptrun;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls_scriptrun, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    my $cmr_status = qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF', failok => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  C-->  " . join("\n  C-->  ", @calls_scriptrun));
    ok((any { /ansible-playbook.*failok=yes.*/ } @calls_scriptrun), 'ansible-playbooks executed with script_run');
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

    qesap_ansible_script_output(cmd => 'SWIM SWIM SWIM', provider => 'NEMO', host => 'REEF');

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

    qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF');

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

    qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF', user => 'GERALD');

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

    qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF', root => 1);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-b --become-user root/ } @calls), 'Ansible as root');
};

subtest '[qesap_create_aws_credentials]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @contents;

    $qesap->redefine(script_output => sub { return '/path/to/aws/credentials/file'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'http://10.0.2.2/tests/'; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_trgt} = '/BRUCE';
            return (%paths);
    });

    qesap_create_aws_credentials('MY_KEY', 'MY_SECRET');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  C-->  " . join("\n  C-->  ", @contents));
    ok((any { qr|mkdir -p ~/\.aws| } @calls), '.aws directory initialized');
    ok((any { qr|curl.+/files/credentials.+/path/to/aws/credentials/file| } @calls), 'AWS Credentials file downloaded');
    ok((any { qr|cp /path/to/aws/credentials/file ~/\.aws/credentials| } @calls), 'AWS Credentials copied to ~/.aws/credentials');
    is $contents[0], 'credentials', "AWS credentials file: credentials is the expected value and got $contents[0]";
    like $contents[1], qr/aws_access_key_id = MY_KEY/, "Expected key MY_KEY is in the credentials file";
    like $contents[1], qr/aws_secret_access_key = MY_SECRET/, "Expected secret MY_SECRET is in the credentials file";
};

subtest '[qesap_create_aws_config]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @contents;

    $qesap->redefine(script_output => sub { return 'eu-central-1'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'http://10.0.2.2/tests/'; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_trgt} = '/BRUCE';
            return (%paths);
    });

    set_var('PUBLIC_CLOUD_REGION', 'eu-south-2');
    qesap_create_aws_config();
    set_var('PUBLIC_CLOUD_REGION', undef);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  C-->  " . join("\n  C-->  ", @contents));
    ok((any { qr|mkdir -p ~/\.aws| } @calls), '.aws directory initialized');
    ok((any { qr|curl.+/files/config.+~/\.aws/config| } @calls), 'AWS Config file downloaded');
    ok((any { qr/eu-central-1/ } @calls), 'AWS Region matches');
    is $contents[0], 'config', "AWS config file: config is the expected value and got $contents[0]";
    like $contents[1], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_create_aws_config] fix quote' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @contents;

    $qesap->redefine(script_output => sub { return '"eu-central-1"'; });
    $qesap->redefine(assert_script_run => sub { return; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'http://10.0.2.2/tests/'; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_trgt} = '/BRUCE';
            return (%paths);
    });

    qesap_create_aws_config();

    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    like $contents[1], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_create_aws_config] not solved template' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @contents;

    $qesap->redefine(script_output => sub { return '%REGION%'; });
    $qesap->redefine(assert_script_run => sub { return; });
    $qesap->redefine(save_tmp_file => sub { push @contents, $_[1]; });
    $qesap->redefine(autoinst_url => sub { return ''; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_trgt} = '/BRUCE';
            return (%paths);
    });

    set_var('PUBLIC_CLOUD_REGION', 'eu-central-1');
    qesap_create_aws_config();
    set_var('PUBLIC_CLOUD_REGION', undef);

    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    like $contents[0], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_create_aws_config] not solved template with quote' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @contents;

    $qesap->redefine(script_output => sub { return '"%REGION%"'; });
    $qesap->redefine(assert_script_run => sub { return; });
    $qesap->redefine(save_tmp_file => sub { push @contents, $_[1]; });
    $qesap->redefine(autoinst_url => sub { return ''; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_trgt} = '/BRUCE';
            return (%paths);
    });

    set_var('PUBLIC_CLOUD_REGION', 'eu-central-1');
    qesap_create_aws_config();
    set_var('PUBLIC_CLOUD_REGION', undef);

    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    like $contents[0], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
};

subtest '[qesap_create_aws_config] not solved template and variable with quote' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @contents;

    $qesap->redefine(script_output => sub { return '%REGION%'; });
    $qesap->redefine(assert_script_run => sub { return; });
    $qesap->redefine(save_tmp_file => sub { push @contents, $_[1]; });
    $qesap->redefine(autoinst_url => sub { return ''; });
    $qesap->redefine(qesap_get_file_paths => sub {
            my %paths;
            $paths{qesap_conf_trgt} = '/BRUCE';
            return (%paths);
    });

    set_var('PUBLIC_CLOUD_REGION', '"eu-central-1"');
    qesap_create_aws_config();
    set_var('PUBLIC_CLOUD_REGION', undef);

    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    like $contents[0], qr/region = eu-central-1/, "Expected region eu-central-1 is in the config file";
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

    $qesap->redefine(qesap_ansible_script_output => sub {
            my (%args) = @_;
            push @ansible_calls, $args{cmd};
            push @logfile_calls, $args{local_file};
            note("\n ###--> local_path : $args{local_path}");
            note("\n ###--> local_file : $args{local_file}");
            return 'BOUBLE BOUBLE BOUBLE'; });
    $qesap->redefine(qesap_get_inventory => sub { return '/BERMUDAS/TRIANGLE'; });
    $qesap->redefine(script_run => sub { return 0; });
    $qesap->redefine(upload_logs => sub { push @save_file_calls, $_[0]; return; });
    $qesap->redefine(qesap_cluster_log_cmds => sub { return ({Cmd => 'crm status', Output => 'crm_status.txt'}); });

    my $cloud_provider = 'NEMO';
    set_var('PUBLIC_CLOUD_PROVIDER', $cloud_provider);
    qesap_cluster_logs();
    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  ANSIBLE_CMD-->  " . join("\n  ANSIBLE_CMD-->  ", @ansible_calls));
    note("\n  SAVE_FILE-->  " . join("\n  SAVE_FILE-->  ", @save_file_calls));
    note("\n  LOG_FILES-->  " . join("\n  LOG_FILES-->  ", @logfile_calls));
    ok((any { /crm status/ } @ansible_calls), 'expected command executed remotely');
    ok((any { /.*vmhana01-crm_status\.txt/ } @logfile_calls), 'qesap_ansible_script_output called with the expected vmhana01 log file');
    ok((any { /.*vmhana02-crm_status\.txt/ } @logfile_calls), 'qesap_ansible_script_output called with the expected vmhana02 log file');
    ok((any { /.*BOUBLE.*/ } @save_file_calls), 'upload_logs is called with whatever filename returned by qesap_ansible_script_output');
};

subtest '[qesap_cluster_logs] multi log command' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @ansible_calls;
    my @logfile_calls;

    $qesap->redefine(qesap_ansible_script_output => sub {
            my (%args) = @_;
            push @ansible_calls, $args{cmd};
            push @logfile_calls, $args{local_file};
            note("\n ###--> local_path : $args{local_path}");
            note("\n ###--> local_file : $args{local_file}");
            return 'BOUBLE BOUBLE BOUBLE'; });
    $qesap->redefine(qesap_get_inventory => sub { return '/BERMUDAS/TRIANGLE'; });
    $qesap->redefine(script_run => sub { return 0; });
    $qesap->redefine(upload_logs => sub { return; });
    $qesap->redefine(qesap_cluster_log_cmds => sub { return ({Cmd => 'crm status', Output => 'crm_status.txt', Logs => ['ignore_me.txt', 'ignore_me_too.txt']}); });

    my $cloud_provider = 'NEMO';
    set_var('PUBLIC_CLOUD_PROVIDER', $cloud_provider);
    qesap_cluster_logs();
    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  ANSIBLE_CMD-->  " . join("\n  ANSIBLE_CMD-->  ", @ansible_calls));
    note("\n  LOG_FILES-->  " . join("\n  LOG_FILES-->  ", @logfile_calls));

    ok((none { /.*ignore_me\.txt/ } @logfile_calls), 'ignore_me.txt is expected to be ignored');
    ok((none { /.*ignore_me_too\.txt/ } @logfile_calls), 'ignore_me_too.txt is expected to be ignored');
};

subtest '[qesap_az_get_resource_group]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'GYROS' });
    $qesap->redefine(get_current_job_id => sub { return 'FETA'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $result = qesap_az_get_resource_group();

    ok((any { /az group list.*/ } @calls), 'az command properly composed');
    ok((any { /.*FETA.*/ } @calls), 'az filtered by jobId');
    ok($result eq "GYROS", 'function return is equal to the script_output return');
};

subtest '[qesap_calculate_az_address_range]' => sub {
    my %result_1 = qesap_calculate_az_address_range(slot => 1);
    my %result_2 = qesap_calculate_az_address_range(slot => 2);
    my %result_64 = qesap_calculate_az_address_range(slot => 64);
    my %result_65 = qesap_calculate_az_address_range(slot => 65);

    is($result_1{vnet_address_range}, "10.0.0.0/21", 'result_1 vnet_address_range is correct');
    is($result_1{subnet_address_range}, "10.0.0.0/24", 'result_1 subnet_address_range is correct');
    is($result_2{vnet_address_range}, "10.0.8.0/21", 'result_2 vnet_address_range is correct');
    is($result_2{subnet_address_range}, "10.0.8.0/24", 'result_2 subnet_address_range is correct');
    is($result_64{vnet_address_range}, "10.1.248.0/21", 'result_64 vnet_address_range is correct');
    is($result_64{subnet_address_range}, "10.1.248.0/24", 'result_64 subnet_address_range is correct');
    is($result_65{vnet_address_range}, "10.2.0.0/21", 'result_65 vnet_address_range is correct');
    is($result_65{subnet_address_range}, "10.2.0.0/24", 'result_65 subnet_address_range is correct');
    dies_ok { qesap_calculate_az_address_range(slot => 0); } "Expected die for slot < 1";
    dies_ok { qesap_calculate_az_address_range(slot => 8193); } "Expected die for slot > 8192";
};

subtest '[qesap_az_get_vnet]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'GYROS'; });
    my $result = qesap_az_get_vnet('TZATZIKI');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az network vnet list.*/ } @calls), 'az command properly composed');
    ok($result eq 'GYROS', 'function return is equal to the script_output return');
};

subtest '[qesap_az_get_vnet] no resource_group' => sub {
    dies_ok { qesap_az_get_vnet() } "Expected die for missing resource_group";
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
    my $result = qesap_calculate_deployment_name('TZATZIKI');
    ok($result eq 'TZATZIKI42', 'function return is proper deployment_name');
};

subtest '[qesap_az_vnet_peering] missing group arguments' => sub {
    dies_ok { qesap_az_vnet_peering() } "Expected die for missing arguments";
    dies_ok { qesap_az_vnet_peering(source_group => 'STINCO') } "Expected die for missing target_group";
    dies_ok { qesap_az_vnet_peering(target_group => 'BRACIOLA') } "Expected die for missing source_group";
};

subtest '[qesap_az_vnet_peering]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_az_get_vnet => sub {
            return 'VNET_STINCO' if ($_[0] =~ /STINCO/);
            return 'VNET_BRACIOLA' if ($_[0] =~ /BRACIOLA/);
            return 'VNET_UNKNOWN';
    });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return 'ID_STINCO' if ($_[0] =~ /VNET_STINCO/);
            return 'ID_BRACIOLA' if ($_[0] =~ /VNET_BRACIOLA/);
            return 'ID_UNKNOWN';
    });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });

    qesap_az_vnet_peering(source_group => 'STINCO', target_group => 'BRACIOLA');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az network vnet show.*STINCO/ } @calls), 'az network vnet show command properly composed for the source_group');
    ok((any { /az network vnet show.*BRACIOLA/ } @calls), 'az network vnet show command properly composed for the target_group');
    ok((any { /az network vnet peering create.*STINCO/ } @calls), 'az network vnet peering create command properly composed for the source_group');
    ok((any { /az network vnet peering create.*BRACIOLA/ } @calls), 'az network vnet peering create command properly composed for the target_group');
};

subtest '[qesap_az_vnet_peering_delete] missing target_group arguments' => sub {
    dies_ok { qesap_az_vnet_peering_delete() } "Expected die for missing arguments";
};

subtest '[qesap_az_get_peering_name] missing resource_group arguments' => sub {
    dies_ok { qesap_az_get_peering_name() } "Expected die for missing arguments";
};

subtest '[qesap_az_vnet_peering_delete]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(get_current_job_id => sub { return 42; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'GYROS'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(record_soft_failure => sub { note(join(' ', 'RECORD_SOFT_FAILURE -->', @_)); });
    $qesap->redefine(qesap_az_get_vnet => sub {
            return 'VNET_TZATZIKI' if ($_[0] =~ /TZATZIKI/);
            return;
    });

    qesap_az_vnet_peering_delete(target_group => 'TZATZIKI');
    note("\n  C-->  " . join("\n  C-->  ", @calls));

    # qesap_az_get_peering_name
    ok((any { /az network vnet peering list.*grep 42/ } @calls), 'az command properly composed');
};

subtest '[qesap_az_vnet_peering_delete] delete failure' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my @soft_failure;
    $qesap->redefine(get_current_job_id => sub { return 42; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'GYROS'; });

    # Simulate a failure in the delete
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 1; });

    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(record_soft_failure => sub {
            push @soft_failure, $_[0];
            note(join(' ', 'RECORD_SOFT_FAILURE -->', @_)); });
    $qesap->redefine(qesap_az_get_vnet => sub {
            return 'VNET_TZATZIKI' if ($_[0] =~ /TZATZIKI/);
            return;
    });

    qesap_az_vnet_peering_delete(target_group => 'TZATZIKI');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  SF-->  " . join("\n  SF-->  ", @soft_failure));

    # qesap_az_get_peering_name
    ok((any { /jira#7487/ } @soft_failure), 'soft failure');
};

done_testing;
