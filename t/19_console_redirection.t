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
    my @variables = qw(REDIRECT_DESTINATION_IP REDIRECT_DESTINATION_USER QEMUPORT
      AUTOINST_URL_HOSTNAME_ORIGINAL AUTOINST_URL_HOSTNAME REDIRECTION_CONFIGURED);
    set_var($_, undef) foreach @variables;
}

subtest '[connect_target_to_serial] Test exceptions' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->noop(qw(enter_cmd handle_login_prompt record_info));
    $redirect->redefine(check_serial_redirection => sub { return 0; });
    set_var('QEMUPORT', '1988');

    dies_ok { connect_target_to_serial(target_ip => '192.168.1.1') } 'Fail with missing ssh user';
    dies_ok { connect_target_to_serial(ssh_user => 'Totoro') } 'Fail with missing ip address';
    dies_ok { connect_target_to_serial(ssh_user => 'Totoro', target_ip => 'Satsuki') }
    'Fail invalid IP';

    $redirect->redefine(check_serial_redirection => sub { return 1; });
    dies_ok { connect_target_to_serial(ssh_user => 'Totoro', target_ip => '192.168.1.1') }
    'Fail if function attempts redirect console second time';

    dies_ok { connect_target_to_serial(ssh_user => ' ', target_ip => '192.168.1.1') } 'Fail with user defined as empty space';
    unset_vars();
};

subtest '[connect_target_to_serial] Connect with unprivileged user' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->noop(qw(script_output record_info assert_script_run));
    my @ssh_cmd;
    my $redirection_status;
    $redirect->redefine(enter_cmd => sub { @ssh_cmd = @_; return 1; });
    # At this point Redirection is expected to work, therefore change $redirection_status to 1, so next check passed
    $redirect->redefine(handle_login_prompt => sub { $redirection_status = 1; return; });
    $redirect->redefine(check_serial_redirection => sub { return $redirection_status; });
    set_var('QEMUPORT', '1988');

    connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'Totoro');
    note('CMD:', join(' ', @ssh_cmd));
    ok(grep(/ssh/, @ssh_cmd), 'Execute main command');
    ok(grep(/-t/, @ssh_cmd), 'Force pseudo terminal');
    ok(grep(/-o StrictHostKeyChecking=no/, @ssh_cmd), 'Disable strict host key checking');
    ok(grep(/-o ServerAliveInterval=60/, @ssh_cmd), 'Set option: "ServerAliveInterval"');
    ok(grep(/-o ServerAliveCountMax=120/, @ssh_cmd), 'Set option: "ServerAliveCountMax"');
    ok(grep(/-o ConnectionAttempts=3/, @ssh_cmd), 'Set option: "ConnectionAttempts"');
    ok(grep(/Totoro\@192.168.1.1/, @ssh_cmd), 'Host login');
    ok(grep(/2>&1 | tee -a \/dev\/ttyS0/, @ssh_cmd), 'Redirect output to serial device');
    is get_var('AUTOINST_URL_HOSTNAME'), 'localhost', 'Function must set "AUTOINST_URL_HOSTNAME" to "localhost"';
    unset_vars();
};

subtest '[connect_target_to_serial] Switch root option' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->noop(qw(script_output record_info assert_script_run));
    my @ssh_cmd;
    my $redirection_status;
    $redirect->redefine(enter_cmd => sub { @ssh_cmd = @_; return 1; });
    # At this point Redirection is expected to work, therefore change $redirection_status to 1, so next check passed
    $redirect->redefine(handle_login_prompt => sub { $redirection_status = 1; return; });
    $redirect->redefine(check_serial_redirection => sub { return $redirection_status; });
    set_var('QEMUPORT', '1988');

    connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'Totoro', switch_root => 'yes');
    note('CMD:', join(' ', @ssh_cmd));
    ok(grep(/sudo su \-/, @ssh_cmd), 'Check root switching command');
    unset_vars();
};

subtest '[connect_target_to_serial] Scenario: console already redirected' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->noop(qw(script_output assert_script_run));
    # Simulate redirection is already active
    $redirect->redefine(check_serial_redirection => sub { return 1; });
    # monitor enter_cmd
    my @calls;
    $redirect->redefine(enter_cmd => sub { push @calls, $_[0]; });
    $redirect->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    set_var('QEMUPORT', '1988');

    connect_target_to_serial(destination_ip => '192.168.1.1', ssh_user => 'Totoro');
    ok(!grep(/ssh/, @calls), 'Skip if redirection already active');
    unset_vars();
};

subtest '[disconnect_target_from_serial]' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->noop(qw(script_output));
    my $redirection_status = 1;
    $redirect->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $redirect->redefine(wait_serial => sub { return 1; });
    # simulate redirection inactive after typing exit
    $redirect->redefine(enter_cmd => sub { $redirection_status = 0; return; });
    $redirect->redefine(check_serial_redirection => sub { return $redirection_status; });
    $redirect->redefine(set_serial_term_prompt => sub { return '#'; });

    set_var('QEMUPORT', '1988');
    set_var('AUTOINST_URL_HOSTNAME_ORIGINAL', 'Porco');
    disconnect_target_from_serial();
    is get_var('AUTOINST_URL_HOSTNAME'), 'Porco', 'Restore "AUTOINST_URL_HOSTNAME" to original value';
    unset_vars();
};

subtest '[check_serial_redirection]' => sub {
    my $redirect = Test::MockModule->new('sles4sap::console_redirection', no_auto => 1);
    $redirect->noop(qw(is_serial_terminal select_serial_terminal set_serial_term_prompt));

    $redirect->redefine(script_run => sub { return 1; });
    ok !check_serial_redirection(), 'Pass with redirection being inactive';

    $redirect->redefine(script_run => sub { return 0 if grep(/test/, @_); return 1; });
    ok check_serial_redirection(), 'Pass with redirection being active';
};

done_testing;
