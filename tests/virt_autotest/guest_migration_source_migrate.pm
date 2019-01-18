# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: virt_autotest: Virtualization multi-machine job : Guest Migration
# Maintainer: jerry <jtang@suse.com>

use base multi_machine_job_base;
use strict;
use warnings;
use testapi;
use guest_migration_base;

sub analyzeResult {
    my ($self, $text) = @_;
    my $result;
    if ($text =~ /----------\s+reason(.*----------\s+\S+)/s) {
        my $rough_result = $1;
        foreach (split("\n", $rough_result)) {
            if ($_ =~ /(.*)\s+----------\s+(pass|fail)/) {
                my ($case_name, $case_result) = ($1, $2);
                $result->{$case_name}{status} = "PASSED" if ($case_result =~ /pass/);
                $result->{$case_name}{status} = "FAILED" if ($case_result =~ /fail/);
                $result->{$case_name}{time}   = 1;
            }
        }
    }
    return $result;
}

sub upload_tar_log {
    my ($self, $log_dir, $log_tar_name) = @_;
    my $full_log_tar_name = "/tmp/$log_tar_name.tar.gz";
    script_run("tar zcf $full_log_tar_name $log_dir", 60);
    upload_logs "$full_log_tar_name";
}

sub run {
    my ($self) = @_;

    my $target_ip = $self->get_var_from_parent('MY_IP');

    my $cmd_output = $self->execute_script_run("/usr/share/qa/virtautolib/lib/guest_migrate.sh -s -d $target_ip -v $hyper_visor -u root -p novell", 3600);

    #Upload logs
    $self->upload_tar_log("/tmp/prj3_migrate_admin_log",                        "prj3_migrate_admin_log");
    $self->upload_tar_log("/var/log/libvirt",                                   "libvirt");
    $self->upload_tar_log("/tmp/prj3_guest_migration/vm_backup/vm-config-xmls", "vm-config-xmls");

    #Parser result
    $self->{product_name} = "Guest_Migration";
    $self->{package_name} = "Guest Migration Result";
    $self->add_junit_log($cmd_output);
}



1;
