# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Run yast2 system_settings module, attempt to add a non existing
# driver in the PCI ID setup and validate the error message. Disable the sysrq
# keys at the kernel settings and validate the change in the system configuration.
# Enable sysrq and validate again.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use YuiRestClient;
use YaST::Module;
use y2lan_restart_common 'close_xterm';
use utils 'zypper_call';
use x11utils 'start_root_shell_in_xterm';

my $system_settings;

sub pre_run_hook {
    $system_settings = $testapi::distri->get_system_settings();
    install_package_via_xterm("yast2-tune");
}

sub validate_sysrq_config {
    my $expected_status = shift;
    record_info("Validate sysrq", "Validate that sysrq is $expected_status in configuration files");
    my %config_value = (disabled => 0, enabled => 1);
    x11_start_program('xterm -geometry 160x45+5+5', target_match => 'xterm');
    my $is_enabled = script_output("cat /proc/sys/kernel/sysrq");
    $is_enabled = substr($is_enabled, 0, 1);
    die "/proc/sys/kernel/sysrq has value $is_enabled , but sysrq should be $expected_status"
      unless ($is_enabled eq $config_value{$expected_status});
    $is_enabled = script_output("cat /etc/sysctl.d/70-yast.conf | grep sysrq");
    $is_enabled = substr($is_enabled, -1, 1);
    die "sysrq.kernel=$is_enabled in /etc/sysctl.d/70-yast.conf , but sysrq should be $expected_status"
      unless ($is_enabled eq $config_value{$expected_status});
    close_xterm();
}

sub install_package_via_xterm {
    my $package = shift;
    start_root_shell_in_xterm();
    zypper_call("in $package");
    close_xterm();
}

sub sysrq_config {
    my $action = shift;
    record_info("$action sysrq", "$action sysrq using yast");
    YaST::Module::open(module => 'system_settings', ui => 'qt');
    $system_settings->setup_kernel_settings_sysrq($action);
    YaST::Module::close(module => 'system_settings');
}

sub add_invalid_pci_id {
    record_info("PCI ID Setup", "Add an invalid PCI ID and handle the expected error message");
    YaST::Module::open(module => 'system_settings', ui => 'qt');
    $system_settings->add_pci_id_from_list({driver => 'random', sysdir => 'random'});
    $system_settings->get_error_dialog()->confirm();
    YaST::Module::close(module => 'system_settings');
}

sub remove_pci_id {
    record_info("Remove PCI ID", "Remove the first PCI ID in the table");
    YaST::Module::open(module => 'system_settings', ui => 'qt');
    $system_settings->remove_pci_id();
    YaST::Module::close(module => 'system_settings');
}

sub run {
    select_console 'x11';
    add_invalid_pci_id();
    remove_pci_id();
    sysrq_config("disable");
    validate_sysrq_config("disabled");
    sysrq_config("enable");
    validate_sysrq_config("enabled");
}

1;
