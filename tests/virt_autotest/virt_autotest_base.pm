# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package virt_autotest_base;
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;
use Data::Dumper;
use XML::Writer;
use IO::File;
use virt_utils;
use Utils::Architectures;
use virt_autotest::utils;
use upload_system_log;
use virt_autotest::utils qw(upload_virt_logs);

sub analyzeResult {
    die "You need to overload analyzeResult in your class";
}

sub get_script_run {
    die "You need to overload this func in your class";
}

sub generateXML {
    my ($self, $data) = @_;
    print Dumper($data);
    my %my_hash = %$data;
    my $pass_nums = 0;
    my $fail_nums = 0;
    my $skip_nums = 0;
    my $test_time_hours = 0;
    my $test_time_mins = 0;
    my $time_hours = 0;
    my $time_mins = 0;
    foreach my $item (keys(%my_hash)) {
        if ($my_hash{$item}->{status} =~ m/PASSED/) {
            $pass_nums += 1;
            push @{$self->{success_guest_list}}, $item;
        }
        elsif ($my_hash{$item}->{status} =~ m/SKIPPED/ && $item =~ m/iso/) {
            $skip_nums += 1;
        }
        else {
            $fail_nums += 1;
        }
        my $test_time = eval { $my_hash{$item}->{test_time} ? $my_hash{$item}->{test_time} : '' };
        if ($test_time ne '') {
            $time_hours = $test_time =~ /^(\d+)m.*s$/i;
            $time_mins = $test_time =~ /^.*m(\d+)s$/i;
            $test_time_hours += $time_hours;
            $test_time_mins += $time_mins;
        }
    }
    $self->{pass_nums} = $pass_nums;
    $self->{fail_nums} = $fail_nums;
    $self->{skip_nums} = $skip_nums;
    $self->{test_time} = $test_time_hours . 'm' . $test_time_mins . 's';

    diag '@{$self->{success_guest_list}} content is: ' . Dumper(@{$self->{success_guest_list}});
    ###Load instance attributes into %xmldata
    my %xmldata;
    foreach (keys %{$self}) {
        if (defined($self->{$_})) {
            if (ref($self->{$_}) eq 'HASH') {
                %{$xmldata{$_}} = %{$self->{$_}};
            }
            elsif (ref($self->{$_}) eq 'ARRAY') {
                @{$xmldata{$_}} = @{$self->{$_}};
            }
            else {
                $xmldata{$_} = $self->{$_};
            }
        }
        else {
            next;
        }
    }
    print "The data to be used for xml generation:", Dumper(\%xmldata);
    generateXML_from_data($data, \%xmldata);
}

sub save_test_configuration {
    my ($self, $assert_pattern, $add_junit_log_flag, $upload_virt_log_flag, $log_dir, $compressed_log_name, $upload_guest_assets_flag) = @_;

    $self->{assert_pattern} = $assert_pattern;
    $self->{add_junit_log_flag} = $add_junit_log_flag;
    $self->{upload_virt_log_flag} = $upload_virt_log_flag;
    $self->{log_dir} = $log_dir;
    $self->{compressed_log_name} = $compressed_log_name;
    $self->{upload_guest_assets_flag} = $upload_guest_assets_flag;
}

#This is the subroutine called inside post_execute_script_run. It aims to do configurations have to be done after script
#execution but before test assertion, for example, modifying boot options, communicating to peer with lock/unlcok and many other
#things as long as they should be done and need to be done right after test execution or the following test steps may malfunction
#without them. post_execute_script_configuration should be overriden in individual test modules.
sub post_execute_script_configuration {
    diag("You need to override this function post_execute_script_config in your test module");
}

#This is the subroutine called inside post_execute_script_run. This is introduced to faciliate tests that do not have or not convenient
#to use assert pattern,  can not use directly returned output from execute_script_run or needs more customized way to manipuluate results.
#So individual test modules can also have more control over how their test results should be extracted out, intead of just relying on a
#singel assert pattern. post_execute_script_assertion needs to be overriden in individual test modules.
sub post_execute_script_assertion {
    diag("You need to override this function post_execute_script_assertion in your test module");
}

#This subroutine incorporates operations needs to be done after finishing executing script. It is further dividied into three parts,
#including post_execute_script_configuration, upload_virt_logs and do test assertion. Test assertion can be done in two ways by using
#assert pattern or newly introduced post_execute_script_assertion subroutine, the latter is only used when $assert_pattern is not provided
#by individual test module to run_test
sub post_execute_script_run {
    my $self = shift;

    $self->post_execute_script_configuration;

    if ($self->{upload_virt_log_flag} eq "yes") {
        upload_virt_logs($self->{log_dir}, $self->{compressed_log_name});
    }
    save_screenshot;

    my $output = $self->{script_output};
    if ($self->{assert_pattern}) {
        diag("Going to do assertion after test. Use assert pattern: $self->{assert_pattern} provided by test module.");
        unless ($output =~ /$self->{assert_pattern}/m) {
            assert_script_run("grep -E \"$self->{assert_pattern}\" $self->{log_dir} -r || zcat /tmp/$self->{compressed_log_name}.tar.gz | grep -aE \"$self->{assert_pattern}\"");
        }
    }
    else {
        diag("Going to do assertion after test. Call post_execute_script_assertion because assert pattern is not available.");
        $self->post_execute_script_assertion;
    }
    save_screenshot;
}

#Adding junit log and uploading guest assets are wrapped up here in newly introduced subroutine post_run_test.
#This is called after post_execute_script_run in run_test if test passes or in post_fail_hook if test fails.
sub post_run_test {
    my $self = shift;

    if ($self->{add_junit_log_flag} eq "yes") {
        $self->add_junit_log($self->{script_output});
    }

    if ($self->{upload_guest_assets_flag} eq "yes") {
        record_info('Check UPLOAD_GUEST_ASSETS flag', 'This test should upload guest assets!');
        $self->upload_guest_assets;
    }
}

sub execute_script_run {
    my ($self, $cmd, $timeout) = @_;
    my $pattern = "CMD_FINISHED-" . int(rand(999999));
    if (!$timeout) {
        $timeout = 10;
    }

    enter_cmd "(" . $cmd . "; echo $pattern) 2>&1 | tee -a /dev/$serialdev";
    $self->{script_output} = wait_serial($pattern, $timeout);
    save_screenshot;

    if (!$self->{script_output} or !defined $self->{script_output}) {
        save_screenshot;
        die "Timeout due to cmd run :[" . $cmd . "]\n";
    }
    else {
        save_screenshot;
        $self->{script_output} =~ s/[\r\n]+$pattern[\r\n]+//g;
    }
}

sub push_junit_log {
    my ($self, $junit_content) = @_;

    script_run "echo \'$junit_content\' > /tmp/output.xml";
    save_screenshot;
    parse_junit_log("/tmp/output.xml");
}

sub run_test {
    my ($self, $timeout, $assert_pattern, $add_junit_log_flag, $upload_virt_log_flag, $log_dir, $compressed_log_name, $upload_guest_assets_flag) = @_;
    if (!$timeout) {
        $timeout = 300;
    }
    $add_junit_log_flag //= 'no';
    $upload_virt_log_flag //= 'no';
    $upload_guest_assets_flag //= 'no';

    check_host_health;

    my $test_cmd = $self->get_script_run();
    #FOR S390X LPAR
    if (is_s390x) {
        virt_utils::lpar_cmd("$test_cmd");
        return;
    }

    $self->save_test_configuration($assert_pattern, $add_junit_log_flag, $upload_virt_log_flag, $log_dir, $compressed_log_name, $upload_guest_assets_flag);
    $self->execute_script_run($test_cmd, $timeout);
    $self->post_execute_script_run;
    $self->post_run_test;
    save_screenshot;
}

sub add_junit_log {
    my ($self, $job_output) = @_;

    # Parse test result and generate junit file
    my $tc_result = $self->analyzeResult($job_output);
    my $xml_result = $self->generateXML($tc_result);
    # Upload and parse junit file.
    $self->push_junit_log($xml_result);

}

sub upload_guest_assets {
    my $self = shift;

    record_info('Skip upload guest asset.', 'No successful guest, skip upload assets.') unless @{$self->{success_guest_list}};

    foreach my $guest (@{$self->{success_guest_list}}) {
        # Generate upload guest asset name
        my $guest_upload_asset_name = generate_guest_asset_name($guest);
        # Upload guest xml
        my $guest_xml_name = $guest_upload_asset_name . '.xml';
        # TODO: on host sle11sp4, the guest name has random string at the end of GUEST_PATTERN
        # eg sles-15-sp1-64-fv-def-net-77b-a43, so need to add special handle here for guest name
        assert_script_run("virsh dumpxml $guest > /tmp/$guest_xml_name");
        upload_asset("/tmp/$guest_xml_name", 1, 1);
        assert_script_run("rm /tmp/$guest_xml_name");
        record_info('Guest xml upload done', "Guest $guest xml uploaded as $guest_xml_name.");
        # Upload guest disk
        # Uploaded guest disk name is different from original disk name in guest xml.
        # This is to differentiate guest disk on different host, hypervisor and product build.
        # Need to recover the disk name when recovering guests from openqa assets.
        my $guest_disk_name_real = get_guest_disk_name_from_guest_xml($guest);
        my $guest_disk_name_to_upload = $guest_upload_asset_name . '.disk';
        if ($guest_disk_name_real =~ /qcow2/) {
            # Disk compression only for qcow2
            compress_single_qcow2_disk($guest_disk_name_real, $guest_disk_name_to_upload);
        }
        else {
            # Link real disk to uploaded disk name to be with needed name after upload
            assert_script_run("ln -s $guest_disk_name_real $guest_disk_name_to_upload");
        }
        upload_asset("$guest_disk_name_to_upload", 1, 0);
        assert_script_run("rm $guest_disk_name_to_upload");
        record_info('Guest disk upload done', "Guest $guest disk uploaded as $guest_disk_name_to_upload.");
    }
}

sub post_fail_hook {
    my ($self) = shift;

    #FOR S390X LPAR
    if (is_s390x) {
        #collect and upload supportconfig log from S390X LPAR
        upload_system_log::upload_supportconfig_log();
        script_run "rm -rf scc_*";
        return;
    }

    $self->post_run_test;
    save_screenshot;

    check_host_health;

    if (get_var('VIRT_PRJ1_GUEST_INSTALL')) {
        #collect and upload guest autoyast control files
        assert_script_run "cp -r /srv/www/htdocs/install/autoyast /guest_autoyast_files";
        virt_utils::collect_host_and_guest_logs('', '/guest_autoyast_files', '');
        assert_script_run "rm -rf /guest_autoyast_files";
    }
    elsif (get_var("VIRT_PRJ2_HOST_UPGRADE")) {
        virt_utils::collect_host_and_guest_logs('', '/root/autoupg.xml', '');
    }
    else {
        virt_utils::collect_host_and_guest_logs;
    }
    save_screenshot;

    $self->upload_coredumps;
    save_screenshot;
}
1;

