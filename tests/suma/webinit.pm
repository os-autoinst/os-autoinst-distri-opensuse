# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Web configuration of SUSE Manager Server
# Maintainer: Ondrej Holecek <oholecek@suse.com>

use base "sumatest";
use 5.018;
use testapi;
use lockapi;

use utils 'zypper_call', 'pkcon_quit';

use selenium;

sub run {
    my $self = shift;
    $self->register_barriers('suma_master_ready');
    select_console('root-console');
    type_string "chown $username /dev/$serialdev\n";

    my $master = get_var('HOSTNAME');
    die "Error: variable HOSTNAME not defined." unless defined $master;

    pkcon_quit();
    add_chromium_repos;
    install_chromium;
    enable_selenium_port;

    select_console('x11');

    my $driver = selenium_driver();
    #$driver->debug_on;
    #$driver->set_implicit_wait_timeout(1);

    $driver->get('https://' . $master . '.openqa.suse.de');


    #  if (check_screen('suma_ff_unknown_cert')) {
    #    record_soft_failure('SUMA certificate not know to browser');
    #    assert_and_click('suma_ff_advanced');
    #    assert_and_click('suma_ff_add_exception');
    #    assert_and_click('suma_ff_configm_exception');
    #  }

    if ($driver->get_page_source() =~ "Create SUSE Manager Administrator") {
        $driver->mouse_move_to_location(element => wait_for_xpath("//input[\@id='orgName']"));
        $driver->double_click();

        $driver->send_keys_to_active_element('openQA');
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element('admin');
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element($password);
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element($password);
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element('susemanager@' . $master . '.openqa.suse.de');
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element('Mr');
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element('openQA');
        $driver->send_keys_to_active_element("\t");
        $driver->send_keys_to_active_element('TestManager');
        $driver->send_keys_to_active_element("\t");

        wait_for_xpath("//input[\@value='Create Organization']")->click();
        wait_for_page_to_load;
        die "SUMA setup failed" unless wait_for_text("You have just created", -tries => 10, -wait => 15);

        if (get_var('SUMA_IMAGE_BUILD')) {
            return 1;
        }
    }


    if ($driver->get_title() =~ /Sign In/) {
        wait_for_xpath("//input[\@id='username-field']")->send_keys("admin");
        wait_for_xpath("//input[\@id='password-field']")->send_keys($password);
        $driver->find_element("login", "id")->click();
    }


    # turn off screensaver
    x11_start_program('xterm');
    assert_screen('xterm');
    script_run('gsettings set org.gnome.desktop.session idle-delay 0');
    send_key('ctrl-d');

    # allow minion to continue
    $self->registered_barrier_wait('suma_master_ready');
}

sub test_flags {
    return {fatal => 1};
}

1;
