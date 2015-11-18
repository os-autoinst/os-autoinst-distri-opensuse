use base "console_yasttest";
use testapi;

sub run() {
    my $self = shift;

    become_root();
    # Install test requirement
    assert_script_run 'zypper -n in rpm-build';

    # Enable source repo
    assert_script_run 'zypper mr -e repo-source';

    # Run YaST CLI tests
    $self->run_yast_cli_test('yast2-network');
    $self->run_yast_cli_test('yast2-dns-server');

    # Exit from root
    script_run 'exit';
}

1;
# vim: set sw=4 et:
