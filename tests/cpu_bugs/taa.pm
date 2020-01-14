# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>

package taa;
use strict;
use warnings;
use base "Mitigation";
use bootloader_setup;
use ipmi_backend_utils;
use testapi;
use utils;

my $mitigations_list =
  {
    name       => "taa",
    parameter  => 'tsx_async_abort',
    sysfs_name => "tsx_async_abort",
    sysfs      => {
        off          => "Vulnerable",
        full         => "Mitigation: Clear CPU buffers; SMT vulnerable",
        "full,nosmt" => "Mitigation: Clear CPU buffers; SMT disable",
        default      => "Mitigation: Clear CPU buffers; SMT vulnerable",
    },
    dmesg => {
        full         => "TAA: Mitigation: Clear CPU buffers",
        off          => "Vulnerable",
        "full,nosmt" => "TAA: Mitigation: Clear CPU buffers",
    },
    cmdline => [
        "full",
        "full,nosmt",
        "off",
    ],
  };

sub new {
    my ($class, $args) = @_;
    #Help constructor distinguishing is our own test object or openQA call
    if ($args eq $mitigations_list) {
        return bless $args, $class;
    }
    my $self = $class->SUPER::new($args);
    return $self;
}

sub run {
    my ($self) = shift;
    my $obj = taa->new($mitigations_list);
    #run base function testing
    $obj->do_test();
}

sub update_grub_and_reboot {
    my ($self, $timeout) = @_;
    grub_mkconfig;
    Mitigation::reboot_and_wait($self, $timeout);
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    assert_script_run(
"md /tmp/upload_mitigations; cp " . $Mitigation::syspath . "* /tmp/upload_mitigations; cp /proc/cmdline /tmp/upload_mitigations; lscpu >/tmp/upload_mitigations/cpuinfo; tar -jcvf /tmp/upload_mitigations.tar.bz2 /tmp/upload_mitigations"
    );
    remove_grub_cmdline_settings('tsx=[a-z,]*');
    remove_grub_cmdline_settings("tsx_async_abort=[a-z,]*");
    grub_mkconfig;
    upload_logs '/tmp/upload_mitigations.tar.bz2';
}

1;
