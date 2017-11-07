# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Installation and configuration of SUSE Manager atftpd salt formula
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;
use mmapi;
use selenium;

sub run {
    my ($self) = @_;

    my $testip = '192.168.1.1';
    my $srvdir = get_var('SERVER_DIR');

    if (check_var('SUMA_SALT_MINION', 'branch')) {
        $self->register_barriers('atftpd_formula', 'atftpd_ready', 'atftpd_formula_finish');
        #need to create after atftpd_formula barrier is breached, or creation will be too early
        my $bn = keys get_children();
        barrier_create('atftpd_ready', $bn + 1);

        # configure second interface for atftpd
        $self->registered_barrier_wait('atftpd_formula');

        # minion test
        script_run('systemctl status atftpd.service');
        assert_script_run('systemctl is-active atftpd.service');

        script_run('cat /etc/sysconfig/atftpd | grep -P -v \'^(\s*$|^#)\'');
        assert_script_run('cat /etc/sysconfig/atftpd | grep \'ATFTPD_BIND_ADDRESSES="' . $testip . '"\'');

        #test atftpd listening on udp port 69
        script_run('netstat -uplne');
        if (script_run('netstat -ulnp | grep \'' . $testip . ':69\s\' | grep -P \'/atftpd\s*$\' ')) {
            record_soft_failure('atftpd listens everywhere: bsc#1049832');
        }

        script_run('echo "test" > ' . $srvdir . '/test');
        type_string('atftp ' . $testip);
        send_key('ret');
        type_string('get test');
        send_key('ret');
        type_string('quit');
        send_key('ret');
        assert_script_run('diff test ' . $srvdir . '/test');

        save_screenshot;

        $self->registered_barrier_wait('atftpd_ready');
        $self->registered_barrier_wait('atftpd_formula_finish');
    }
    elsif (check_var('SUMA_SALT_MINION', 'terminal')) {
        $self->register_barriers('atftpd_formula', 'atftpd_ready', 'atftpd_formula_finish');
        $self->registered_barrier_wait('atftpd_formula');
        $self->registered_barrier_wait('atftpd_ready');

        script_run('rcSuSEfirewall2 status');
        script_run('rcSuSEfirewall2 stop');
        save_screenshot;

        script_run('echo "test" > /tmp/test2cmp');
        type_string('atftp ' . $testip);
        send_key('ret');
        type_string('get test');
        send_key('ret');
        type_string('quit');
        send_key('ret');
        assert_script_run('diff test /tmp/test2cmp');

        $self->registered_barrier_wait('atftpd_formula_finish');
    }
    else {
        $self->register_barriers('atftpd_formula', 'atftpd_formula_finish');
        $self->install_formula('atftpd-formula');
        $self->select_formula('atftpd', 'Atftpd');

        my $driver = selenium_driver();
        #select all text in first form entry
        $driver->mouse_move_to_location(element => wait_for_xpath("//form[\@id='editFormulaForm']/div/div"));
        $driver->click();
        $driver->send_keys_to_active_element("\t");
        save_screenshot;

        # ip
        $driver->send_keys_to_active_element($testip);
        $driver->send_keys_to_active_element("\t");
        save_screenshot;

        # dir
        $driver->send_keys_to_active_element($srvdir);
        $driver->send_keys_to_active_element("\t");
        save_screenshot;
        wait_for_xpath("//button[\@id='save-btn']")->click();

        $self->apply_highstate();

        # signal minion to check configuration
        $self->registered_barrier_wait('atftpd_formula');
        $self->registered_barrier_wait('atftpd_formula_finish');
    }
}

sub test_flags() {
    return {milestone => 1};
}

1;
