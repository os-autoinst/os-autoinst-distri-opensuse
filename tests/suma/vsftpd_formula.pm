# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager vsftpd salt formula
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use mmapi;
use selenium;

sub run {
    my ($self) = @_;

    my $testip = '192.168.1.1';           #TODO: get from common module / branch network test to ensure compatibility
    my $srvdir = get_var('SERVER_DIR');

    if (check_var('SUMA_SALT_MINION', 'branch')) {
        $self->register_barriers('vsftpd_formula', 'vsftpd_ready', 'vsftpd_formula_finish');
        my $bn = keys get_children();
        barrier_create('vsftpd_ready', $bn + 1);

        # configure second interface for vsftpd
        $self->registered_barrier_wait('vsftpd_formula');

        #FIXME: workaround for server directory ownership tbd in branch network formula
        script_run('chmod 755 ' . $srvdir);

        # minion test
        script_run('systemctl status vsftpd.service');
        assert_script_run('systemctl is-active vsftpd.service');

        script_run('cat /etc/vsftpd.conf | grep -P -v \'^(\s*$|^#)\'');
        assert_script_run('cat /etc/vsftpd.conf | grep \'listen_address=' . $testip . '\'');

        #test vsftpd listening on tcp port 21
        script_run('netstat -pluten');
        script_run('netstat -plutn | grep \'' . $testip . ':21\s\' | grep -P \'/vsftpd\s*$\' ');

        #download test:
        script_run('ls -l ' . $srvdir . '/..');
        script_run('echo "vsftpd_test" > ' . $srvdir . '/vsftpd_test');
        script_run('ls -l ' . $srvdir);
        assert_script_run('curl ftp://' . $testip . '/vsftpd_test > vsftpd_test_dwl');
        assert_script_run('diff ' . $srvdir . '/vsftpd_test vsftpd_test_dwl');

        save_screenshot;

        $self->registered_barrier_wait('vsftpd_ready');
        $self->registered_barrier_wait('vsftpd_formula_finish');
    }
    elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
        $self->register_barriers('vsftpd_formula', 'vsftpd_ready', 'vsftpd_formula_finish');
        $self->registered_barrier_wait('vsftpd_formula');
        $self->registered_barrier_wait('vsftpd_ready');

        #download test:
        script_run('echo "vsftpd_test" > ./vsftpd_test2cmp');
        assert_script_run('curl ftp://' . $testip . '/vsftpd_test > vsftpd_test_terminal_dwl');
        assert_script_run('diff vsftpd_test2cmp vsftpd_test_terminal_dwl');

        $self->registered_barrier_wait('vsftpd_formula_finish');
    }
    else {
        $self->register_barriers('vsftpd_formula', 'vsftpd_formula_finish');
        $self->install_formula('vsftpd-formula');
        $self->select_formula('vsftpd', 'Vsftpd');

        my $driver = selenium_driver();
        $driver->mouse_move_to_location(element => wait_for_xpath("//form[\@id='editFormulaForm']/div/div"));
        $driver->click();
        $driver->send_keys_to_active_element("\t");
        save_screenshot;

        # dir
        $driver->send_keys_to_active_element($srvdir);
        $driver->send_keys_to_active_element("\t");
        save_screenshot;

        # ip
        $driver->send_keys_to_active_element($testip);
        $driver->send_keys_to_active_element("\t");
        save_screenshot;
        sleep(5);
        wait_for_xpath("//button[\@id='save-btn']")->click();

        $self->apply_highstate();

        # signal minion to check configuration
        $self->registered_barrier_wait('vsftpd_formula');
        $self->registered_barrier_wait('vsftpd_formula_finish');
    }
}

sub test_flags() {
    return {milestone => 1};
}

1;
