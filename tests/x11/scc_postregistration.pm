use base "x11test";
use testapi;
use registration;

sub run() {
    my $self = shift;

    x11_start_program('xterm -geometry 160x45+5+5');
    become_root;
    assert_script_run 'mv /etc/zypp/credentials.d /etc/zypp/repos.d /etc/zypp/services.d /tmp';  # move existing registration data to /tmp
    yast_scc_registration;
    assert_script_run 'cp -nrp /tmp/credentials.d /tmp/repos.d /tmp/services.d /etc/zypp/';  # copy previous repo to /etc/zypp/
    send_key 'alt-f4';  # exit xterm
}

1;

# vim: set sw=4 et:
