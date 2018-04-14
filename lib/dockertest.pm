package dockertest;
use base 'consoletest';

use strict;
use testapi;
use utils qw(zypper_call systemctl);
use version_utils;
use registration 'add_suseconnect_product';

sub install_docker_when_needed {
    if (is_caasp) {
        # Docker should be pre-installed in MicroOS
        die 'Docker is not pre-installed.' if zypper_call('se -x --provides -i docker | grep docker', allow_exit_codes => [0, 1]);
    }
    else {
        add_suseconnect_product('sle-module-containers') if is_sle('15+');
        # docker package can be installed
        zypper_call('in docker');
    }

    # docker daemon can be started
    systemctl('start docker');
    systemctl('status docker');
    assert_script_run('docker info');
}

1;
# vim: set sw=4 et:
