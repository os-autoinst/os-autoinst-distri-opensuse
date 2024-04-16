use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::console_redirection;

our $serialdev = 'ttyS0';    # this is a global OpenQA variable

# make cleaning vars easier at the end of the unit test
sub unset_vars {
    my @variables = ('REDIRECT_DESTINATION_IP', 'REDIRECT_DESTINATION_USER', 'BASE_VM_ID', 'QEMUPORT');
    set_var($_, undef) foreach @variables;
}

subtest '[connect_target_to_serial] Expected failures' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->redefine(enter_cmd => sub { return 1; });
    $redirect->redefine(handle_login_prompt => sub { return 1; });
    $redirect->redefine(record_info => sub { return 1; });
    $redirect->redefine(script_output => sub { return 'castleinthesky'; });
    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    $redirect->redefine(check_serial_redirection => sub { return 0; });

    dies_ok { connect_target_to_serial(target_ip => '192.168.1.1') } 'Fail with missing ssh user';
    dies_ok { connect_target_to_serial(ssh_user => 'totoro') } 'Fail with missing ip address';
    $redirect->redefine(check_serial_redirection => sub { return 1; });
    dies_ok { connect_target_to_serial(ssh_user => 'totoro', target_ip => '192.168.1.1') } 'Fail with console already being redirected';
    unset_vars();
    dies_ok { connect_target_to_serial(ssh_user => ' ', target_ip => '192.168.1.1') } 'Fail with user defined as empty space';
};

subtest '[connect_target_to_serial] Test passing behavior' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    my $ssh_cmd;
    $redirect->redefine(enter_cmd => sub { $ssh_cmd = $_[0]; return 1; });
    $redirect->redefine(handle_login_prompt => sub { return 1; });
    $redirect->redefine(record_info => sub { return 1; });
    $redirect->redefine(check_serial_redirection => sub { return 0; });
    $redirect->redefine(script_output => sub { return 'castleinthesky'; });
    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'totoro');
    is $ssh_cmd, 'ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=120 totoro@192.168.1.1 2>&1 | tee -a /dev/ttyS0', 'Pass with corect command executed';
    unset_vars();
};

subtest '[handle_login_prompt] Test via "connect_to_serial"' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    my $type_pass_executed = 0;
    $redirect->redefine(enter_cmd => sub { return 1; });
    $redirect->redefine(type_password => sub { $type_pass_executed = 1; });
    $redirect->redefine(send_key => sub { return 1; });
    $redirect->redefine(set_serial_term_prompt => sub { return 1; });
    $redirect->redefine(record_info => sub { return 1; });
    $redirect->redefine(check_serial_redirection => sub { return 0; });
    $redirect->redefine(script_output => sub { return 'castleinthesky'; });
    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');

    my @command_prompts = ('laputa@castleinthesky:~>', 'castleinthesky:~ # ');
    foreach (@command_prompts) {
        $redirect->redefine(wait_serial => sub { return $_; });
        connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'totoro');
        is $type_pass_executed, 0, "Pass with command prompt detected: $_";
        $type_pass_executed = 0;    # reset flag
    }

    $redirect->redefine(wait_serial => sub { return '(laputa@castleinthesky) Password:'; });
    $redirect->redefine(croak => sub { return; });    # Need to disable croak since wait_serial won't return second response here.

    connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'totoro');
    is $type_pass_executed, 1, 'Pass with password prompt detected';
    unset_vars();
};

subtest '[disconnect_target_from_serial]' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    my $wait_serial_done = 0;    # Flag that code entered while loop
    $redirect->redefine(record_info => sub { return 1; });
    $redirect->redefine(wait_serial => sub { $wait_serial_done = 1; return ':~'; });
    $redirect->redefine(enter_cmd => sub { return 1; });
    $redirect->redefine(check_serial_redirection => sub { return $wait_serial_done; });
    $redirect->redefine(set_serial_term_prompt => sub { return 1; });
    $redirect->redefine(script_output => sub { return ''; });

    ok disconnect_target_from_serial(base_vm_machine_id => '7902847fcc554911993686a1d5eca2c8'), 'Pass with machine ID defined by positional argument';

    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    ok disconnect_target_from_serial(), 'Pass with machine ID defined by parameter BASE_VM_ID';
    unset_vars();

    dies_ok { disconnect_target_from_serial() } 'Fail without specifying machine ID and BASE_VM_ID undefined';
};

subtest '[check_serial_redirection]' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->redefine(script_output => sub { return '7902847fcc554911993686a1d5eca2c8'; });
    $redirect->redefine(record_info => sub { return; });

    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    is check_serial_redirection(), '0', 'Return 0 if machine IDs match';
    set_var('BASE_VM_ID', '999999999999999999999999');
    is check_serial_redirection(), '1', 'Return 1 if machine IDs do not match';

    unset_vars();

    is check_serial_redirection(base_vm_machine_id => '123456'), '1', 'Pass with specifying ID via positional argument';
    dies_ok { check_serial_redirection() } 'Fail with BASE_VM_ID being unset';
};

subtest '[redirection_init]' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->redefine(assert_script_run => sub { return 1; });
    $redirect->redefine(script_run => sub { return 0; });
    $redirect->redefine(connect_target_to_serial => sub { return 1; });
    $redirect->redefine(disconnect_target_from_serial => sub { return 1; });
    $redirect->redefine(remote_port_forward => sub { return 1; });
    $redirect->redefine(record_info => sub { return 1; });
    $redirect->redefine(script_output => sub {
            return '7902847fcc554911993686a1d5eca2c8' if grep(/machine-id/, @_);
            return 'ghibli' if grep(/whoami/, @_);
            return 'totoro';
    });

    set_var('REDIRECT_DESTINATION_IP', '192.168.1.5');
    set_var('REDIRECT_DESTINATION_USER', 'ghibli');
    set_var('QEMUPORT', '15685');

    ok redirection_init(), 'Pass with correct usage';
    is get_var('BASE_VM_ID'), '7902847fcc554911993686a1d5eca2c8', 'Pass with BASE_VM_ID being set correctly';

    $redirect->redefine(script_run => sub { return 1; });
    dies_ok { redirection_init() } 'Fail with autossh package not being installed';
    unset_vars();
};

subtest '[remote_port_forward] Test via redirection_init()' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    my @assert_script_run;
    my $as_root;
    $redirect->redefine(assert_script_run => sub { push(@assert_script_run, $_[0]) if grep /autossh/, $_[0]; return '1985'; });
    $redirect->redefine(script_run => sub { return 0; });
    $redirect->redefine(connect_target_to_serial => sub { return 1; });
    $redirect->redefine(disconnect_target_from_serial => sub { return 1; });
    $redirect->redefine(record_info => sub { return 1; });
    $redirect->redefine(script_output => sub { return 'root' if grep(/whoami/, @_) and $as_root; return 'ghibli'; });

    set_var('REDIRECT_DESTINATION_IP', '192.168.1.5');
    set_var('REDIRECT_DESTINATION_USER', 'ghibli');
    set_var('QEMUPORT', '15685');

    redirection_init();
    is $assert_script_run[0],
      'sudo autossh -M 20000 -f -N -R 22022:localhost:22022 ghibli@192.168.1.5',
      'Forward port 80 as normal user via sudo';
    is $assert_script_run[1],
      'sudo autossh -M 20001 -f -N -R 15686:10.0.2.2:15686 ghibli@192.168.1.5',
      'Forward qemu port as normal user via sudo';

    $as_root = 1;
    redirection_init();

    is $assert_script_run[2],
      'autossh -M 20000 -f -N -R 22022:localhost:22022 ghibli@192.168.1.5',
      'Forward port 80 as root without sudo';
    is $assert_script_run[3],
      'autossh -M 20001 -f -N -R 15686:10.0.2.2:15686 ghibli@192.168.1.5',
      'Forward qemu port as root without sudo';

    unset_vars();
};

done_testing;
