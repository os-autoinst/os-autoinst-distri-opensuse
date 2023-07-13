# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package reboot_and_wait_up;
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use testapi;
use ipmi_backend_utils;
use base "proxymode";
use power_action_utils 'power_action';
use Utils::Architectures;
use virt_autotest::utils;

sub reboot_and_wait_up {
    my $self = shift;
    my $reboot_timeout = shift;

    if (is_s390x) {
        record_info('INFO', 'Reboot LPAR');
        #Reboot s390x lpar
        power_action('reboot', observe => 1, keepconsole => 1);
        my $svirt = select_console('svirt', await_console => 0);
        return;
    }

    if (get_var("PROXY_MODE")) {
        select_console('root-console');
        my $test_machine = get_var("TEST_MACHINE");
        $self->reboot($test_machine, $reboot_timeout);
    }
    else {
        #leave ssh console and switch to sol console
        switch_from_ssh_to_sol_console(reset_console_flag => 'off');
        #on some SUTs, fg. a HP machine in Beijing lab, screen of sol console is cleared at the second reboot.
        #and the 'return' key must be typed then 'login' prompt appears in sol console
        send_key 'ret' if check_screen('sol-console-wait-typing-ret');

        my ($package_name, $file_name, $line_num) = caller;
        diag("The package $package_name defined from file $file_name called me at line $line_num");
        my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION'));
        my ($host_installed_rel) = $host_installed_version =~ /^(\d+)/im;
        my ($host_installed_sp) = $host_installed_version =~ /sp(\d+)$/im;
        my $host_upgrade_version = get_var('UPGRADE_PRODUCT', '');
        my ($host_upgrade_rel) = $host_upgrade_version =~ /sles-(\d+)-sp/i;
        my ($host_upgrade_sp) = $host_upgrade_version =~ /sp(\d+)$/im;
        if ($package_name eq 'reboot_and_wait_up_upgrade' and is_kvm_host and is_x86_64 and ($host_installed_rel eq '15' and $host_installed_sp eq '2') and ($host_upgrade_rel eq '15' and $host_upgrade_sp eq '3')) {
            record_soft_failure("Workaround is preserved to avoid needle assertion on sol console and prevent potential unnecessary failures due to bsc#1185374.");
            diag("Workaround is preserved to avoid needle assertion on sol console and prevent potential unnecessary failures due to bsc#1185374..Reboot host by using ipmitool directly.");
            ipmi_backend_utils::ipmitool 'chassis power reset';
        }
        else {
            #login is required when sol console is used for the first time
            unless (check_screen('text-logged-in-root')) {
                #The timeout can't be too small since autoyast installation
                #Xen console may output additional messages about vm on sol whose output is disrupted.
                #So in order to get login prompt back on screen, 'ret' key should be fired up. But the
                #os name banner might not be available anymore, only 'linux-login' needle can be matched.
                if (is_xen_host) {
                    send_key 'ret' for (0 .. 2);
                    assert_screen [qw(text-login linux-login)], 600;
                }
                else {
                    assert_screen "text-login", 600;
                }
                enter_cmd "root";
                assert_screen "password-prompt";
                type_password;
                send_key('ret');
                assert_screen "text-logged-in-root";
            }

            #type reboot
            enter_cmd("reboot");
        }
        #switch to sut console
        reset_consoles;

        #wait boot finish and relogin
        login_console::login_to_console($self, $reboot_timeout);
    }
}

1;

