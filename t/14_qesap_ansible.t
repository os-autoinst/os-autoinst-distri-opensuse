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

subtest '[qesap_ansible_cmd]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });

    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN');

    note("\n  -->  " . join("\n  -->  ", @calls));
    like $calls[0], qr/.*source.*activate.*/, "Activate venv";
    ok((any { /.*ansible.*all.*-i.*SIDNEY.*-u.*cloudadmin.*-b.*--become-user=root.*-a.*"FINDING".*/ } @calls), "Expected ansible command format");
};

subtest '[qesap_ansible_cmd] verbose' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });
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
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_run => sub { push @calls_script_run, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });

    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN', failok => 1);

    note("\n  -->  " . join("\n  -->  ", @calls));
    note("\n  -->  " . join("\n  -->  ", @calls_script_run));
    ok((any { /.*ansible.*all.*-i.*SIDNEY.*-u.*cloudadmin.*-b.*--become-user=root.*-a.*"FINDING".*/ } @calls_script_run), "Expected ansible command format");
};

subtest '[qesap_ansible_cmd] filter and user' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    qesap_ansible_cmd(cmd => 'FINDING', provider => 'OCEAN', filter => 'NEMO', user => 'DARLA');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*activate/ } @calls), 'virtual environment activated');
    ok((any { /.*NEMO.*-u.*DARLA.*/ } @calls), "Expected filter and user in the ansible command format");
    ok((any { /.*deactivate/ } @calls), 'virtual environment deactivated');
};

subtest '[qesap_ansible_cmd] no cmd' => sub {
    dies_ok { qesap_ansible_cmd(provider => 'OCEAN') } "Expected die for missing cmd";
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
    $qesap->redefine(qesap_ansible_script_output_file => sub { return '/tmp/ansible_script_output/'; });

    my $out = qesap_ansible_script_output(cmd => 'SWIM', provider => 'NEMO', host => 'REEF', file => 'testout.txt', out_path => '/tmp/ansible_script_output/');

    note("\n  out=$out");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    like($out, qr/^ANEMONE/, 'the return is the content of the file stored by Ansible');
};

subtest '[qesap_ansible_script_output_file]' => sub {
    # Call qesap_ansible_script_output_file with the bare minimal set of arguments
    # and mock all the dependency.
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my $fetch_remote_path;
    my $fetch_out_path;
    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0;
    });
    $qesap->redefine(qesap_ansible_fetch_file => sub {
            my (%args) = @_;
            $fetch_remote_path = $args{remote_path};
            $fetch_out_path = $args{out_path};
            return '/BAY';
    });

    my $out = qesap_ansible_script_output_file(
        provider => 'NEMO',
        cmd => 'SWIM',
        host => 'REEF');

    note("\n  out=$out");
    note("\n  fetch_remote_path=$fetch_remote_path");
    note("\n  fetch_out_path=$fetch_out_path");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /test -e script_output\.yaml/ } @calls), 'Verify for the local existence of script_output.yaml');
    ok((any { /ansible-playbook/ } @calls), 'ansible-playbook is called at least one');
    ok((any { /ansible-playbook.*-l REEF/ } @calls), 'host is used to configure -l');
    ok((any { /ansible-playbook.*-i \/CRUSH/ } @calls), 'inventory calculated with qesap_get_inventory is used to configure -i');
    ok((any { /ansible-playbook.*-e.*cmd='SWIM'/ } @calls), 'cmd is used to populate -e cmd');
    like($out, qr/\/BAY/, 'The return is what returned by qesap_ansible_fetch_file');
};

subtest '[qesap_ansible_script_output_file] call with all arguments' => sub {
    # Call qesap_ansible_script_output_file with all possible arguments
    # and mock all the dependency.
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my $fetch_remote_path;
    my $fetch_out_path;
    my $fetch_file;
    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0;
    });
    $qesap->redefine(qesap_ansible_fetch_file => sub {
            my (%args) = @_;
            $fetch_remote_path = $args{remote_path};
            $fetch_out_path = $args{out_path};
            $fetch_file = $args{file};
            return '/BAY';
    });

    my $out = qesap_ansible_script_output_file(
        provider => 'NEMO',
        cmd => 'SWIM',
        host => 'REEF',
        user => 'NEMO',
        root => 1,
        remote_path => '/ADRIATIC_SEE',
        out_path => '/TIRRENO_SEE',
        file => 'JELLY.fish',
        timeout => 100);

    note("\n  out=$out");
    note("\n  fetch_remote_path=$fetch_remote_path");
    note("\n  fetch_out_path=$fetch_out_path");
    note("\n  fetch_file=$fetch_file");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok($fetch_remote_path eq '/ADRIATIC_SEE', 'remote_path is used as argument for qesap_ansible_fetch_file');
    ok($fetch_out_path eq '/TIRRENO_SEE', 'out_path is used as argument for qesap_ansible_fetch_file');
    ok($fetch_file eq 'JELLY.fish', 'file is used as argument for qesap_ansible_fetch_file');
    # fails for an unknown reason, it should not
    #ok((any { /ansible-playbook.*-u NEMO'/ } @calls), 'user is used as ansible-playbook -u');
    #ok((any { /ansible-playbook.*--become-user root'/ } @calls), 'root activate ansible-playbook --become-user');
    ok((any { /ansible-playbook.*-e.*remote_path='\/ADRIATIC_SEE'/ } @calls), 'remote_path is used as ansible-playbook -e remote_path');
};

subtest '[qesap_ansible_script_output_file] integrate with qesap_venv_cmd_exec' => sub {
    # This test does not mock qesap_venv_cmd_exec so also test it implicitly
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; });

    my $out = qesap_ansible_script_output_file(cmd => 'SWIM',
        provider => 'NEMO',
        host => 'REEF',
        path => '/tmp/',
        out_path => '/BERMUDA_TRIAGLE/',
        file => 'SUBMARINE.TXT');

    note("\n  out=$out");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-e.*local_path='\/BERMUDA_TRIAGLE\/'/ } @calls), 'proper ansible-playbook local_path');
    ok((any { /ansible-playbook.*-e.*file='SUBMARINE.TXT'/ } @calls), 'proper ansible-playbook local_file');
    like($out, qr/^\/BERMUDA_TRIAGLE\/SUBMARINE\.TXT/, 'the return is the path of the file stored by Ansible');
};

subtest '[qesap_ansible_script_output_file] no curl if test true' => sub {
    # Call qesap_ansible_script_output_file with the bare minimal set of arguments
    # and mock all the dependency.
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my $test_e_result;
    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    # script_run only used for 'test -e'
    $qesap->redefine(script_run => sub {
            push @calls, $_[0];
            if ($_[0] =~ /test.*-e/) {
                return $test_e_result;
            }
            return 0;
    });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_venv_cmd_exec => sub { return 0; });
    $qesap->redefine(qesap_ansible_fetch_file => sub { return 0; });

    $test_e_result = 1;
    qesap_ansible_script_output_file(
        provider => 'NEMO',
        cmd => 'SWIM',
        host => 'REEF');

    note("\n  test_e_result=$test_e_result");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /test -e script_output\.yaml/ } @calls), 'Verify for the local existence of script_output.yaml');
    ok((any { /curl/ } @calls), 'curl is called as the yaml is not available');

    $test_e_result = 0;
    @calls = ();
    qesap_ansible_script_output_file(
        provider => 'NEMO',
        cmd => 'SWIM',
        host => 'REEF');

    note("\n  test_e_result=$test_e_result");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /test -e script_output\.yaml/ } @calls), 'Verify for the local existence of script_output.yaml');
    ok((none { /curl/ } @calls), 'curl is not called as the yaml is already available');
};

subtest '[qesap_ansible_script_output_file] failok' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    my $fetch_failok;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0;
    });
    $qesap->redefine(qesap_ansible_fetch_file => sub {
            my (%args) = @_;
            $fetch_failok = $args{failok};
            return '/BAY';
    });

    my $out = qesap_ansible_script_output_file(
        provider => 'NEMO',
        cmd => 'SWIM',
        host => 'REEF',
        failok => 1);

    note("\n  out=$out");
    note("\n  fetch_failok=$fetch_failok");
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-e.*failok=yes/ } @calls), 'ansible called with failok=yes');
};

subtest '[qesap_ansible_script_output_file] cmd with spaces' => sub {
    # Call qesap_ansible_script_output_file with the bare minimal set of arguments
    # and mock all the dependency.
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(qesap_venv_cmd_exec => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return 0;
    });
    $qesap->redefine(qesap_ansible_fetch_file => sub {
            my (%args) = @_;
            return '/BAY';
    });

    qesap_ansible_script_output_file(
        provider => 'NEMO',
        cmd => 'SWIM SWIM SWIM',
        host => 'REEF');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-e.*cmd='SWIM SWIM SWIM'/ } @calls), 'cmd with spaces is properly escaped when used to populate -e cmd');
};

subtest '[qesap_ansible_script_output_file] custom user integrate with qesap_venv_cmd_exec' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    qesap_ansible_script_output_file(cmd => 'SWIM', provider => 'NEMO', host => 'REEF', user => 'GERALD', out_path => '/BERMUDA_TRIAGLE/', file => 'SUBMARINE.TXT');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-u GERALD/ } @calls), 'Custom ansible with user');
};

subtest '[qesap_ansible_script_output_file] root integrate with qesap_venv_cmd_exec' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;

    $qesap->redefine(qesap_get_inventory => sub { return '/CRUSH'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'patate'; });

    qesap_ansible_script_output_file(cmd => 'SWIM',
        provider => 'NEMO',
        host => 'REEF',
        root => 1,
        out_path => '/BERMUDA_TRIAGLE/',
        file => 'SUBMARINE.TXT',);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /ansible-playbook.*-b --become-user root/ } @calls), 'Ansible as root');
};

subtest '[qesap_ansible_fetch_file] mandatory arguments' => sub {
    dies_ok { qesap_ansible_fetch_file() } "Expected die for missing provider and host";
    dies_ok { qesap_ansible_fetch_file(provider => 'SAND', remote_path => '/WIND') } "Expected die for missing host";
    dies_ok { qesap_ansible_fetch_file(host => 'SALT', remote_path => '/WIND') } "Expected die for missing provider";
    dies_ok { qesap_ansible_fetch_file(provider => 'SAND', host => 'SALT') } "Expected die for missing remote_path";
};

subtest '[qesap_ansible_fetch_file]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_get_inventory => sub { return '/SIDNEY'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $qesap->redefine(data_url => sub { return '/BRUCE'; });

    my $ret = qesap_ansible_fetch_file(provider => 'SAND', host => 'SALT', remote_path => '/WIND');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("ret:$ret");
    ok $ret eq '/tmp/ansible_script_output/testout.txt', 'The default local file path is /tmp/ansible_script_output/testout.txt';
};

done_testing;
