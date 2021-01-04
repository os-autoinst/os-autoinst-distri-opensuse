# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package reboot_and_wait_up;
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use testapi;
use login_console;
use ipmi_backend_utils;
use base "proxymode";
use power_action_utils 'power_action';
use ipmi_backend_utils;
use Utils::Architectures;
use virt_autotest::utils;

sub reboot_and_wait_up {
    my $self           = shift;
    my $reboot_timeout = shift;

    if (check_var('ARCH', 's390x')) {
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

        my ($package_name, $file_name, $line_num) = caller;
        diag("The package $package_name defined from file $file_name called me at line $line_num");
        my $host_installed_version = get_var('VERSION_TO_INSTALL', get_var('VERSION'));
        my ($host_installed_rel)   = $host_installed_version =~ /^(\d+)/im;
        my ($host_installed_sp)    = $host_installed_version =~ /sp(\d+)$/im;
        my $host_upgrade_version   = get_var('UPGRADE_PRODUCT', '');
        my ($host_upgrade_rel)     = $host_upgrade_version =~ /sles-(\d+)-sp/i;
        my ($host_upgrade_sp)      = $host_upgrade_version =~ /sp(\d+)$/im;
        if ($package_name eq 'reboot_and_wait_up_upgrade' and is_kvm_host and is_x86_64 and ($host_installed_rel eq '15' and $host_installed_sp eq '2') and ($host_upgrade_rel eq '15' and $host_upgrade_sp eq '3')) {
            record_soft_failure("bsc#1156315 irqbalance warning messages prevent needles being asserted in sol console");
            diag("bsc#1156315 irqbalance warning messages prevent needles being asserted in sol console. Reboot host by using ipmitool directly.");
            ipmi_backend_utils::ipmitool 'chassis power reset';
        }
        else {
            #login
            #The timeout can't be too small since autoyast installation
            assert_screen "text-login", 600;
            type_string "root\n";
            assert_screen "password-prompt";
            type_password;
            send_key('ret');
            assert_screen "text-logged-in-root";

            #type reboot
            type_string("reboot\n");
        }
        #switch to sut console
        reset_consoles;

        #wait boot finish and relogin
        login_console::login_to_console($self, $reboot_timeout);
    }
}

1;

