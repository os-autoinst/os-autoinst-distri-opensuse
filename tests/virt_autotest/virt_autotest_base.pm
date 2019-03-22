# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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

    my $case_num = scalar(keys %my_hash);
    my $case_status;
    my $xml_result;
    my $pass_nums = 0;
    my $fail_nums = 0;
    my $skip_nums = 0;
    my $writer    = XML::Writer->new(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT => 'self');

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
    }

    diag '@{$self->{success_guest_list}} content is: ' . Dumper(@{$self->{success_guest_list}});

    my $count = $pass_nums + $fail_nums + $skip_nums;
    $writer->startTag(
        'testsuites',
        error    => "0",
        failures => "$fail_nums",
        name     => $self->{product_name},
        skipped  => "0",
        tests    => "$count",
        time     => ""
    );
    $writer->startTag(
        'testsuite',
        error     => "0",
        failures  => "$fail_nums",
        hostname  => "`hostname`",
        id        => "0",
        name      => $self->{product_tested_on},
        package   => $self->{package_name},
        skipped   => "0",
        tests     => $case_num,
        time      => "",
        timestamp => "2016-02-16T02:50:00"
    );

    foreach my $item (keys(%my_hash)) {
        if ($my_hash{$item}->{status} =~ m/PASSED/) {
            $case_status = "success";
        }
        elsif ($my_hash{$item}->{status} =~ m/SKIPPED/ && $item =~ m/iso/) {
            $case_status = "skipped";
        }
        else {
            $case_status = "failure";
        }

        $writer->startTag(
            'testcase',
            classname => $item,
            name      => $item,
            status    => $case_status,
            time      => $my_hash{$item}->{time});
        $writer->startTag('system-err');
        my $system_err = ($my_hash{$item}->{error} ? $my_hash{$item}->{error} : 'None');
        $writer->characters("$system_err");
        $writer->endTag('system-err');

        $writer->startTag('system-out');
        $writer->characters($my_hash{$item}->{time});
        $writer->endTag('system-out');

        $writer->endTag('testcase');
    }

    $writer->endTag('testsuite');
    $writer->endTag('testsuites');

    $writer->end();
    $writer->to_string();
}

sub execute_script_run {
    my ($self, $cmd, $timeout) = @_;
    my $pattern = "CMD_FINISHED-" . int(rand(999999));

    if (!$timeout) {
        $timeout = 10;
    }

    type_string "(" . $cmd . "; echo $pattern) 2>&1 | tee -a /dev/$serialdev\n";
    my $ret = wait_serial($pattern, $timeout);

    save_screenshot;

    if ($ret) {
        save_screenshot;
        $ret =~ s/[\r\n]+$pattern[\r\n]+//g;
        return $ret;
    }
    else {
        save_screenshot;
        die "Timeout due to cmd run :[" . $cmd . "]\n";
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

    my $test_cmd = $self->get_script_run();
    #FOR S390X LPAR
    if (check_var('ARCH', 's390x')) {
        virt_utils::lpar_cmd("$test_cmd");
        return;
    }

    my $script_output = $self->execute_script_run($test_cmd, $timeout);

    if ($add_junit_log_flag eq "yes") {
        $self->add_junit_log($script_output);
    }

    if ($upload_virt_log_flag eq "yes") {
        upload_virt_logs($log_dir, $compressed_log_name);
    }

    if ($upload_guest_assets_flag eq "yes") {
        record_info('Check UPLOAD_GUEST_ASSETS flag', 'This test should upload guest assets!');
        $self->upload_guest_assets;
    }

    if ($assert_pattern) {
        unless ($script_output =~ /$assert_pattern/m) {
            assert_script_run("grep -E \"$assert_pattern\" $log_dir -r || zcat /tmp/$compressed_log_name.tar.gz | grep -aE \"$assert_pattern\"");
        }
    }

}

sub add_junit_log {
    my ($self, $job_output) = @_;

    # Parse test result and generate junit file
    my $tc_result  = $self->analyzeResult($job_output);
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
        my $guest_disk_name_real      = get_guest_disk_name_from_guest_xml($guest);
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

1;

