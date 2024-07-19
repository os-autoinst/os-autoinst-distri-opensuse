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
    my @variables = qw(REDIRECT_DESTINATION_IP REDIRECT_DESTINATION_USER BASE_VM_ID QEMUPORT
      AUTOINST_URL_HOSTNAME_ORIGINAL AUTOINST_URL_HOSTNAME REDIRECTION_CONFIGURED);
    set_var($_, undef) foreach @variables;
}

subtest '[connect_target_to_serial] Test exceptions' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->redefine(enter_cmd => sub { return; });
    $redirect->redefine(handle_login_prompt => sub { return; });
    $redirect->redefine(record_info => sub { return; });
    $redirect->redefine(check_serial_redirection => sub { return 0; });

    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    set_var('QEMUPORT', '1988');

    dies_ok { connect_target_to_serial(target_ip => '192.168.1.1') } 'Fail with missing ssh user';
    dies_ok { connect_target_to_serial(ssh_user => 'Totoro') } 'Fail with missing ip address';
    dies_ok { connect_target_to_serial(ssh_user => 'Totoro', target_ip => 'Satsuki') }
    'Fail invalid IP';

    $redirect->redefine(check_serial_redirection => sub { return 1; });
    dies_ok { connect_target_to_serial(ssh_user => 'Totoro', target_ip => '192.168.1.1') }
    'Fail if function attempts redirect console second time';
    set_var('BASE_VM_ID', undef);

    dies_ok { connect_target_to_serial(ssh_user => 'Totoro', target_ip => '192.168.1.1') }
    'Fail with "BASE_VM_ID" unset';

    dies_ok { connect_target_to_serial(ssh_user => ' ', target_ip => '192.168.1.1') } 'Fail with user defined as empty space';
    unset_vars();
};

subtest '[connect_target_to_serial] Check command composition' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    my @ssh_cmd;
    my $redirection_status;
    $redirect->redefine(enter_cmd => sub { @ssh_cmd = @_; return 1; });
    # At this point Redirection is expected to work, therefore change $redirection_status to 1, so next check passed
    $redirect->redefine(handle_login_prompt => sub { $redirection_status = 1; return; });
    $redirect->redefine(record_info => sub { return; });
    $redirect->redefine(check_serial_redirection => sub { return $redirection_status; });
    $redirect->redefine(script_output => sub { return 'castleinthesky'; });
    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    set_var('QEMUPORT', '1988');

    connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'Totoro');
    note('CMD:', join(' ', @ssh_cmd));
    ok(grep(/ssh/, @ssh_cmd), 'Execute main command');
    ok(grep(/-o StrictHostKeyChecking=no/, @ssh_cmd), 'Disable strict host key checking');
    ok(grep(/-o ServerAliveInterval=60/, @ssh_cmd), 'Set option: "ServerAliveInterval"');
    ok(grep(/-o ServerAliveCountMax=120/, @ssh_cmd), 'Set option: "ServerAliveCountMax"');
    ok(grep(/Totoro\@192.168.1.1/, @ssh_cmd), 'Host login');
    ok(grep(/2>&1 | tee -a \/dev\/ttyS0/, @ssh_cmd), 'Redirect output to serial device');
    unset_vars();
};

subtest '[connect_target_to_serial] Scenario: console already redirected' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->redefine(enter_cmd => sub { die; });    # Unit test should not reach this part - redirection is already set
    $redirect->redefine(record_info => sub { return; });
    $redirect->redefine(check_serial_redirection => sub { return 1; });
    $redirect->redefine(script_output => sub { return 'Castle in the sky'; });
    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    set_var('QEMUPORT', '1988');

    ok(connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'Totoro'), 'Skip if redirection already active');
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
    set_var('QEMUPORT', '1988');

    ok disconnect_target_from_serial(), 'Pass with machine ID defined by parameter BASE_VM_ID';
    unset_vars();

    dies_ok { disconnect_target_from_serial() } 'Fail without specifying machine ID and BASE_VM_ID undefined';
};

subtest '[check_serial_redirection]' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->redefine(script_output => sub { return '7902847fcc554911993686a1d5eca2c8'; });
    $redirect->redefine(record_info => sub { return; });
    set_var('QEMUPORT', '1988');
    set_var('BASE_VM_ID', '7902847fcc554911993686a1d5eca2c8');
    is check_serial_redirection(), '0', 'Return 0 if machine IDs match';
    set_var('BASE_VM_ID', '999999999999999999999999');
    is check_serial_redirection(), '1', 'Return 1 if machine IDs do not match';

    unset_vars();

    is check_serial_redirection(base_vm_machine_id => '123456'), '1', 'Pass with specifying ID via positional argument';
    dies_ok { check_serial_redirection() } 'Fail with BASE_VM_ID being unset';
};

done_testing;
