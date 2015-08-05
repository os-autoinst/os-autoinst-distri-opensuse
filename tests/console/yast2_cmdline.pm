use base "console_yasttest";
use testapi;

sub run() {
    my $self = shift;

    become_root();
    # Install git
    assert_script_run 'zypper -n install git-core';

    # Run all the existing YaST CLI tests
    $self->run_yast_cli_test('yast-network');
    assert_script_run 'zypper -n install bind yast2-dns-server';
    $self->run_yast_cli_test('yast-dns-server');

    # Exit from root
    script_run 'exit';
}

1;
# vim: set sw=4 et:
