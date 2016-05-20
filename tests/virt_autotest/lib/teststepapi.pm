# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package teststepapi;
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

use Data::Dumper;
use XML::Writer;
use IO::File;

our $PRODUCT_TESTED_ON = "SLES-12-SP2";
our $PROJECT_NAME = "GuestInstallation";
our $PACKAGE_NAME = "Guest Installation Test";

sub get_guest_pattern() {
    my $self = shift;
    my $guest_pattern = get_var("GUEST_PATTERN", "");
    if ( $guest_pattern eq "") {
        #$guest_pattern = "sles-11-sp[34]|sles-12";
        $guest_pattern = "sles-12-sp1";
    }
    return $guest_pattern
}

sub get_parallel_num() {
    my $self = shift;
    my $parallel_num = get_var("PARALLEL_NUM", "");
    if ( $parallel_num eq "") {
        $parallel_num = "3";
    }

    return $parallel_num;
}


sub analyzeResult($) {
    my ($self, $text) =  @_;
    my $result;
    $text =~ /Test in progress(.*)Test run complete/s;
    my $rough_result = $1;
    foreach (split("\n", $rough_result)) {
        if ($_ =~ /(\S+)\s+\.{3}\s+\.{3}\s+(PASSED|FAILED)\s+\((\S+)\)/g) {
            $result->{$1}{"status"} = $2;
            $result->{$1}{"time"} = $3;
        }
    }
    print Dumper($result);
    return $result;
}

sub generateXML($) {
    my ($self, $data) = @_;

    #my $output = new IO::File(">ou");
    print Dumper($data);
    my %my_hash = %$data;

    my $case_num = scalar(keys %my_hash);
    my $case_status;
    my $xml_result;
    my $pass_nums = 0;
    my $fail_nums = 0;
    my $writer = new XML::Writer(DATA_MODE => 'true', DATA_INDENT => 2, OUTPUT=>'self');

    foreach my $item ( keys (%my_hash) ) {
        if ($my_hash{$item}->{"status"} =~ m/PASSED/) {
            $pass_nums += 1;
        } else {
            $fail_nums += 1;
        }
    }
    my $count = $pass_nums + $fail_nums;
    $writer->startTag('testsuites', "error"=>"0", "failures"=>"$fail_nums", "name"=>$PROJECT_NAME, "skipped"=>"0", "tests"=>"$count", "time"=>"");
    $writer->startTag('testsuite', "error"=>"0", "failures"=>"$fail_nums", "hostname"=>"Donau", "id"=>"0", "name"=>$PRODUCT_TESTED_ON, "package"=>$PACKAGE_NAME, "skipped"=>"0", "tests"=>$case_num, "time"=>"", "timestamp"=>"2016-02-16T02:50:00");

    foreach my $item ( keys (%my_hash) ) {

        if ($my_hash{$item}->{"status"} =~ m/PASSED/) {
            $case_status = "success";
        } else {
            $case_status = "failure";
        }

        $writer->startTag('testcase', 'classname'=>$item, 'name'=>$item, "status"=>$case_status, 'time'=>$my_hash{$item}->{"time"});
        $writer->startTag('system-err');
        $writer->characters("None");
        $writer->endTag('system-err');

        $writer->startTag('system-out');
        $writer->characters($my_hash{$item}->{"time"});
        $writer->endTag('system-out');

        $writer->endTag('testcase');
    }

    $writer->endTag('testsuite');
    $writer->endTag('testsuites');

    $writer->end();
    $writer->to_string();
    #system("echo -e \'$writer\' > /tmp/output1.xml");
    #$output->close();
}

sub local_string_output($$) {

	my ($self, $cmd, $timeout) = @_;
	my $pattern   = "CMD_FINISHED-" . int(rand(999999));
	
	if (!$timeout) {
		$timeout = 10;
	}

	#type_string "(bash -c " . $cmd . "; echo $pattern) | tee -a /dev/$serialdev\n";
	type_string "(" . $cmd . "; echo $pattern) | tee -a /dev/$serialdev\n";
	my $ret = wait_serial($pattern, $timeout);

	if ($ret) {
		$ret =~ s/$pattern//g;
        	return $ret;
	}else {
		return 1;
	}

}


sub get_scrip_run() {
	my $self = shift;
	my $prd_version = script_output("cat /etc/issue");
	my $pre_test_cmd;
	if ($prd_version =~ m/SUSE Linux Enterprise Server 12/) {
		$pre_test_cmd = "/usr/share/qa/tools/test_virtualization-virt_install_withopt-run";
	} else {
                $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-standalone-run";
        }

	return $pre_test_cmd;
}

sub execute_script_run($$) {
	my ($self, $cmd, $timeout) = @_;

	my $guest_pattern = $self->get_guest_pattern();
	my $parallel_num  = $self->get_parallel_num();

	my $full_cmd  = $cmd . " -f " . $guest_pattern . " -n " . $parallel_num . " -r ";
	print "full command is : \n" . $full_cmd ."\n";
	#$full_cmd = "/tmp/test.sh";

	my $ret = $self->local_string_output($full_cmd, $timeout);

	if ($ret == 1 ) {
		die "Timeout due to cmd run :[" . $full_cmd . "]\n";
	}
	return $ret

}

sub push_junit_log($) {
	my ($self, $junit_content) = @_;

	type_string "echo \'$junit_content\' > /tmp/output.xml\n";
	parse_junit_log("/tmp/output.xml");
}

sub run() { 
	my $self = shift;
	# Got script run according to different kind of system
	my $pre_test_cmd = $self->get_scrip_run();

	# Execute script run
	my $ret = $self->execute_script_run($pre_test_cmd, 100);

	# Parse test result and generate junit file
	my $tc_result = $self->analyzeResult($ret);
	my $xml_result = $self->generateXML($tc_result);

	# Upload and parse junit file.
	$self->push_junit_log($xml_result);

}

sub test_flags {
    return {important => 1};
}

1;

