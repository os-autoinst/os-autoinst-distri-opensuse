#!/usr/bin/perl
# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

## Example: ./ziomon_basic.pl <fcp_adaptor> <wwpn> <lun>
use strict;
use warnings;
use lib 'lib/perl';
use Time::Local;
my $TESTCASE_NUMBER_OF_FAILED = 0;
my $TESTCASE_NUMBER_OF_PASS   = 0;
sub show_test_results {
    print "\n";
    print "===> Results:\n";
    print "\n";
    print "Failed tests     : $TESTCASE_NUMBER_OF_FAILED\n";
    print "Successful tests : $TESTCASE_NUMBER_OF_PASS\n";
    print "\n";
}
sub grep_output
{
    my $pattern = $_[0];
    open(my $fh, '<', "$_[1]") or die $!;
    while (my $LINE = $fh) {
        if ($LINE =~ m/\b$pattern\b/) {
            return 0;
        }
    }
    close($fh);
    return 1;
}
sub start_3270_logging
{

    print "INFO:start collecting 3270 logs from spool via reader";
    system "chccwdev -e c";
    system "modprobe vmur ";
    system "modprobe vmcp";
    print "INFO : purging all files from reader";
    system "vmur purge --force \/&& ";
    my $ret = system "vmcp sp cons start to \*";
    my $rc  = ($ret >> 8) & 0xff;
    return $rc;
}
sub filter_repeated
{
    open my $fh, '<', $_[0] or die $!;
    my $seen  = " ";
    my $count = 1;
    while (my $line = $fh)
    {
        my $flag = 1;
        if ($line eq $seen)
        {
            $count = $count + 1;
            $flag  = 0;
        }
        else
        {
            if ($count > 1)
            {
                print "==> repeated $count times\n";
                $count = 1;
            }
        }
        if ($flag == 1)
        {
            print $_[1] . $line;
            $seen = $line;
            $flag = 0;
        }
    }
    close($fh);
}
sub reset_and_show_dmesg
{
    open my $fh, '>', "temp" or die $!;
    print $fh `dmesg -c`;
    close($fh);
    &filter_repeated("temp", "<DMESG>|");
    unlink "temp";
}
sub assert_warn
{

    my $EXITCODE   = shift;
    my $ASSERTCODE = shift;
    my $MESSAGE    = shift;
    my $FAILED     = "[FAILED]";
    my $PASSED     = "[PASSED]";

    if ($EXITCODE != $ASSERTCODE)
    {
        print "$FAILED :: $MESSAGE :: $EXITCODE (expected $ASSERTCODE)\n";
        $TESTCASE_NUMBER_OF_FAILED = $TESTCASE_NUMBER_OF_FAILED + 1;
        return $EXITCODE;
    }
    else
    {
        print "$PASSED :: $MESSAGE :: $EXITCODE\n";
        $TESTCASE_NUMBER_OF_PASS = $TESTCASE_NUMBER_OF_PASS + 1;
        return $EXITCODE;
    }
}
sub assert_fail
{

    my $EXITCODE   = shift;
    my $ASSERTCODE = shift;
    my $MESSAGE    = shift;
    my $FAILED     = "[FAILED]";
    my $PASSED     = "[PASSED]";

    if ($EXITCODE != $ASSERTCODE)
    {
        print "$FAILED :: $MESSAGE :: $EXITCODE (expected $ASSERTCODE)\n";
        print "ATTENTION: THIS CAUSES A DIRECT STOP OF THE TESTCASE\n";


        $TESTCASE_NUMBER_OF_FAILED = $TESTCASE_NUMBER_OF_FAILED + 1;
        show_test_results();
        exit $EXITCODE;
        print "**END OF TESTCASE **\n";
    }
    else
    {
        print "$PASSED :: $MESSAGE :: $EXITCODE\n";
        $TESTCASE_NUMBER_OF_PASS = $TESTCASE_NUMBER_OF_PASS + 1;
        return $EXITCODE;
    }

}

sub isString {
    my $find = $_[0];
    my $file = $_[1];
    open $fh, '<', "$file";
    my @line = $fh;
    for (@line) {
        if ($_ =~ /$find/) {
            return 1;
        }
    }
    return 0;
}


sub loadHigherThan
{

    my $LOAD  = $_[0];
    my $CLOAD = substr(`uptime`, 45, 1);
    my $ILOAD = `uptime`;

    $ILOAD =~ s/load average/current load average/;
    print "LOAD: $ILOAD\n";

    if ($CLOAD >= $LOAD)
    {
        print "=> current load higher than $LOAD\n";
        return $CLOAD;
    }
    return 0;
}

sub checkEqualOrNewerKernel
{
    my $CRELEASE = substr(`uname -r`, 0, 6);
    my $RELEASE  = $_[0];

    my $CR1 = substr($CRELEASE, 0, 1);
    my $CR2 = substr($CRELEASE, 2, 1);
    my $CR3 = substr($CRELEASE, 4, 2);

    my $RR1 = substr($RELEASE, 0, 1);
    my $RR2 = substr($RELEASE, 2, 1);
    my $RR3 = substr($RELEASE, 4, 2);

    if (($CR1 > $RR1) ? return 1 : (($CR2 >= $RR2) && ($CR3 >= $RR3))) { return 1; }

    return 0;
}

sub MinimumCPUs
{

    my $MINIMUMCPUS = $_[0];
    my $CNUMBERCPUS = `cat /proc/cpuinfo |grep processors`;

    $CNUMBERCPUS =~ s/# processors    : //;

    if ($MINIMUMCPUS <= $CNUMBERCPUS)
    {
        return $CNUMBERCPUS;
    }

    return 0;
}
#
my $scsi_dump_adapter;
my $scsi_wwpn;
my $scsi_lun;
if (@ARGV == 3) {
    $scsi_dump_adapter = $ARGV[0];
    $scsi_wwpn         = $ARGV[1];
    $scsi_lun          = $ARGV[2];
    my $test = './scsi_setup.sh ' . " " . $scsi_dump_adapter . " " . $scsi_wwpn . " " . $scsi_lun;
    system($test);
    assert_warn($?, 0, "Scsci Dvices got attached");
} else {

    print "\n insuficent parameter please pass fcp adaptor wwpn and lun";
    print "\n\n";
    exit();

}
print "\nziomon tool test started";
################################### Basic Sanity  Testing #############################
print "\ncheck basic option of ziomon";

my @ziomonOption = ('-h', '-v', '--help', '--version');
for (my $i = 0; $i < 4; $i++)
{ print "on testing";
    my $basictest = 'ziomon ' . $ziomonOption[$i];    # only for code coverage purpose.
    system($basictest);
    assert_warn($?, 0, "Basic Sanity Test got passed");
}


################################### Basic Sanity  Testing #############################
print "\ncheck basic invalid  option of ziomon";
@ziomonOption = ('--H', '--v', '--Help', '--Version');
for (my $i = 0; $i < 4; $i++)
{
    my $basicinvalidtest = 'ziomon ' . $ziomonOption[$i];    # only for code coverage purpose.
    system($basicinvalidtest);
    assert_warn($?, 256, "Basic invalid Test got passed");
}


my $lszfcp = `lszfcp -D .$scsi_lun`;

my @device = split(" ", $lszfcp);


my $scsi_device = `lsscsi | grep $device[1]`;


print "\n basic test $scsi_device";
if ("$scsi_device" ne "") {
    my @scsi_device1 = split("/dev", $scsi_device);
    $scsi_device = '/dev' . $scsi_device1[1];
    print "\n SCSI device $scsi_device";
    print "\n";
    assert_fail(0, 0, "A valid SCSI device is present on system");
}
else {
    print "done";
    assert_fail(1, 0, "no valid SCSI device is present on system");
}

system('./debugfs_mount.sh');
assert_fail($?, 0, "Debugfs  got mounted");

print "\ncheck valid options for writing ziomon data ";
###valid optios regarding ziomon###########################################################

@ziomonOption = ('-V -d 4 -f  -o log -i 20 -l 1M', '--verbose --force  --duration 4 --outfile log --interval-length 60 --size-limit 1M');
for (my $i = 0; $i < 2; $i++)
{
    my $validziomonOption = 'ziomon ' . $ziomonOption[$i] . "  " . $scsi_device;    # only for code coverage purpose.
    system($validziomonOption);
    assert_warn($?, 0, "out put got recored on log.log file");
    sleep 10;
    print "\n\n\n";
}
sleep 2;

print "\ncheck invalid options for writing ziomon data ";
###invalid optios regarding ziomon##########################################################

@ziomonOption = ('--V -d 1 -o log -l 1k', '-V ---d 1 -i 6 -o log -l 1M', '-V -d 1 --O log -l 1M', '-V -d 1 -o log --L 1M', '-V -d 5 -o log -i 15 -l 1M');
for (my $i = 0; $i < 4; $i++)
{
    my $invalidoption = 'ziomon ' . $ziomonOption[$i] . "  " . $scsi_device;    # only for code coverage purpose.
    system($invalidoption);
    sleep 10;
    assert_warn($?, 256, "Negative testing looks like fine");
}

my $removeDevice = './scsi_remove.sh ' . " " . $scsi_dump_adapter . " " . $scsi_wwpn . " " . $scsi_lun;
system($removeDevice);
assert_warn($?, 0, "Scsci Dvices got Detached");

show_test_results();
