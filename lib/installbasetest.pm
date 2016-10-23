package installbasetest;
use base "opensusebasetest";
use strict;
use testapi;

# All steps in the installation are 'fatal'.

sub test_flags() {
    return {fatal => 1};
}

sub save_satsolver_logs() {
    select_console 'log-console';
    assert_script_run 'tar -capf /tmp/satsolver.tar.xz /var/log/zypper.solverTestCase';
    upload_logs '/tmp/satsolver.tar.xz';
}

1;
# vim: set sw=4 et:
