# CONCURRENT VIRTUAL MACHINE INSTALLATIONS MODULE
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: This module supports concurrent multiple virtual machine
# installations with vm names and profiles obtained from @_guest_lists
# passed to generate_guest_instances and @_guest_profiles passed to
# generate_guest_profiles respectively. For example, if guest lists
# "vm_name_1,vm_name_2,vm_name_3" and "vm_profile_1,vm_profile_2,vm_profile_3"
# are passed to generate_guest_instances and generate_guest_profiles,
# then vm_name_1 will be created and installed using vm_profile_1 and
# so on. Any vm profile names can be given as long as there are corresponding
# profile files in data/virt_autotest/guest_params_xml_files folder,
# for example, there should be profile file called vm_profile_1.xml,
# vm_profile_2.xml and vm_profile_3.xml in the folder in this example.
# Installation progress monitoring,result validation, junit log provision,
# environment cleanup and failure handling are also included and supported.
# Subroutine concurrent_guest_installations_run is the convenient one
# to be called to perform all the above operations if necessary.
#
# Please refer to lib/guest_installation_and_configuration_base for
# detailed information about subroutines in base module being called.
#
# Maintainer: Wayne Chen <wchen@suse.com>
package concurrent_guest_installations;

use base 'guest_installation_and_configuration_base';
use strict;
use warnings;
use POSIX 'strftime';
use File::Basename;
use testapi;
use IPC::Run;
use virt_utils;
use virt_autotest_base;
use XML::Simple;
use Data::Dumper;
use LWP;
use Carp;

#%guest_instances stores mapping from guest instances names to guest instance objects
our %guest_instances = ();
#%guest_instances_profiles stores mapping from guest instances names to guest parameters profiles
our %guest_instances_profiles = ();
#@guest_installations_done stores guest instances names that finish installations
our @guest_installations_done = ();

#Get guest names from array argument passed in, for example:
#my @testarray = ('vm1','vm2','vm3'),$self->generate_guest_instances(@testarray)
#There is no restriction on the form or format of guest instance name.
sub generate_guest_instances {
    my $self         = shift;
    my @_guest_lists = @_;

    $self->reveal_myself;
    while (my ($_index, $_element) = each(@_guest_lists)) {
        $guest_instances{$_element} = bless({%$self}, ref($self));
        diag "Guest $_element is blessed";
    }
    return $self;
}

#Get guest profiles names from array argument passed in, for example:
#my @testarray = ('vm_profile1','vm_profile2','vm_profile3'),$self->generate_guest_profiles(@testarray)
#These names should be the file name without extension in data/virt_autotest/guest_params_xml_files folder.
#Guest profile xml file will be fetched using HTTP::Request and parsed using XML::Simple.
sub generate_guest_profiles {
    my $self            = shift;
    my @_guest_profiles = @_;

    $self->reveal_myself;
    my @_guest_lists = (keys %guest_instances);
    while (my ($_index, $_element) = each(@_guest_lists)) {
        my $_ua            = LWP::UserAgent->new;
        my $_geturl        = data_url("virt_autotest/guest_params_xml_files/$_guest_profiles[$_index].xml");
        my $_req           = HTTP::Request->new(GET => "$_geturl");
        my $_res           = $_ua->request($_req);
        my $_guest_profile = (XML::Simple->new)->XMLin($_res->content, SuppressEmpty => '');
        $_guest_profile->{guest_name} = $_element;
        $guest_instances_profiles{$_element} = $_guest_profile;
        diag "Guest $_element is going to use profile" . Dumper($guest_instances_profiles{$_element});
    }
    return $self;
}

#Create guest instance using $guest_instances{$_}->create(%{$guest_instances_profiles{$_}} and install it by calling $guest_instances{$_}->guest_installation_run.
#Guest installation screen will be attached anyway and first time needle match detection with 'guest_installation_yast2_started' will be performed.
#Detach guest installation screen anyway after first time attach and needle detection to obtain guest installation screen information.
#This subroutine also accepts hash/dictionary argument to be passed to guest_installation_run to further customize guest instance.
sub install_guest_instances {
    my $self = shift;

    $self->reveal_myself;
    my $_num_of_guests = scalar(keys %guest_instances);
    record_info("There are $_num_of_guests guests in total to be dealt with", "Ready to go !");
    foreach (keys %guest_instances) {
        $guest_instances{$_}->create(%{$guest_instances_profiles{$_}});
        if ($guest_instances{$_}->{guest_installation_result} ne '') {
            next;
        }
        else {
            $guest_instances{$_}->guest_installation_run(@_);
        }
        if ($guest_instances{$_}->{guest_autoconsole} eq '') {
            assert_screen('text-logged-in-root');
            $guest_instances{$_}->do_attach_guest_installation_screen_without_session;
        }
        $guest_instances{$_}->{guest_installation_attached} = 'true';
        if (!(check_screen('guest-installation-yast2-started', timeout => 180 / get_var('TIMEOUT_SCALE', 1)))) {
            record_info("Failed to detect or guest $guest_instances{$_}->{guest_name} does not have installation window opened", "This might be caused by improper console settings or reboot after installaton finishes. Will continue to monitor its installation progess, so this is not treated as fatal error at the moment.");
        }
        else {
            record_info("Guest $guest_instances{$_}->{guest_name} has installation window opened", "Will continue to monitor its installation progess");
        }
        $guest_instances{$_}->detach_guest_installation_screen;
    }
    return $self;
}

#Mointor multiple guest installations at the same time:
#Attach guest installation screen if no [guest_installation_result].
#Call monitor_guest_installation to monitor its progress.monitor_guest_installation will record result,obtain guest ipaddr,detach screen and etc if there is final result.
#If [guest_installation_result] has final result,push it into @guest_installations_done,collect_guest_installation_logs_via_ssh if not PASSED and calculate how many guests are left.
#If no [guest_installation_result], detach current guest and move to next one,or keep curren guest screen if it is the last one left so there is no need to re-attach.
sub monitor_concurrent_guest_installations {
    my $self = shift;

    $self->reveal_myself;
    my $_installation_timeout             = 0;
    my $_guest_installations_left         = scalar(keys %guest_instances) - scalar(@guest_installations_done);
    my $_guest_installations_not_the_last = 1;
    while ($_installation_timeout < 1800) {
        foreach (keys %guest_instances) {
            if ($guest_instances{$_}->{guest_installation_result} eq '') {
                $guest_instances{$_}->attach_guest_installation_screen if (($_guest_installations_not_the_last ne 0) or ($guest_instances{$_}->{guest_installation_attached} ne 'true'));
                $guest_instances{$_}->monitor_guest_installation;
                if ($guest_instances{$_}->{guest_installation_result} eq '') {
                    $_guest_installations_not_the_last = 0                 if ($_guest_installations_left eq 1);
                    $guest_instances{$_}->detach_guest_installation_screen if ($_guest_installations_not_the_last ne 0);
                }
            }
            my $_current_guest_instance = $_;
            if ((!(grep { $_ eq $_current_guest_instance } @guest_installations_done)) and ($guest_instances{$_}->{guest_installation_result} ne '')) {
                push(@guest_installations_done, $_);
                $_guest_installations_left = scalar(keys %guest_instances) - scalar(@guest_installations_done);
                $guest_instances{$_}->collect_guest_installation_logs_via_ssh if ($guest_instances{$_}->{guest_installation_result} ne 'PASSED');
                last                                                          if ($_guest_installations_left eq 0);
            }
        }
        last if ($_guest_installations_left eq 0);
        sleep 60;
        $_installation_timeout += 60;
    }
    return $self;
}

#Mark guest installation as UNKNOWN if there is no [guest_installation_result].Fail test run if there is unsuccessful result.
sub validate_guest_installations_results {
    my $self = shift;

    $self->reveal_myself;
    my $_overall_test_result = '';
    foreach (keys %guest_instances) {
        if ($guest_instances{$_}->{guest_installation_result} eq '') {
            record_info("Guest $guest_instances{$_}->{guest_name} still has no installation result at the end.Makr it as UNKNOWN.", "It will be treated as a kind of failure !");
            $guest_instances{$_}->{guest_installation_result} = 'UNKNOWN';
        }
        $_overall_test_result = "$guest_instances{$_}->{guest_installation_result},$_overall_test_result";
    }
    croak("The overall result is FAILED because certain guest installation did not succeed.") if ($_overall_test_result =~ /FAILED|TIMEOUT|UNKNOWN/img);
    return $self;
}

#Do cleanup actions by calling detach_guest_installation_screen, terminate_guest_installation_session,get_guest_ipaddr and print_guest_params.
sub clean_up_guest_installations {
    my $self = shift;

    $self->reveal_myself;
    foreach (keys %guest_instances) {
        $guest_instances{$_}->detach_guest_installation_screen;
        $guest_instances{$_}->terminate_guest_installation_session;
        if ($guest_instances{$_}->{guest_ipaddr_static} ne 'true') {
            $guest_instances{$_}->get_guest_ipaddr;
        }
        $guest_instances{$_}->print_guest_params;
    }
    return $self;
}

#Generate junit log
sub junit_log_provision {
    my ($self, $runsub) = @_;

    $self->reveal_myself;
    my $_guest_installations_results;
    foreach (keys %guest_instances) {
        $_guest_installations_results->{$_}{status}    = $guest_instances{$_}->{guest_installation_result};
        $_guest_installations_results->{$_}{start_run} = $guest_instances{$_}->{start_run};
        $_guest_installations_results->{$_}{stop_run}  = ($guest_instances{$_}->{stop_run} eq '' ? time() : $guest_instances{$_}->{stop_run});
        $_guest_installations_results->{$_}{test_time} = strftime("\%Hh\%Mm\%Ss", gmtime($_guest_installations_results->{$_}{stop_run} - $_guest_installations_results->{$_}{start_run}));
    }
    $self->{"product_tested_on"} = script_output("cat /etc/issue | grep -io \"SUSE.*\$(arch))\"");
    $self->{"product_name"}      = ref($self);
    $self->{"package_name"}      = ref($self);
    my $_guest_installation_xml_results = virt_autotest_base::generateXML($self, $_guest_installations_results);
    script_run("echo \'$_guest_installation_xml_results\' > /tmp/output.xml");
    save_screenshot;
    upload_logs("/tmp/output.xml");
    parse_junit_log("/tmp/output.xml");
    return $self;
}

#Check whether current console is root-ssh console and re-connect if needle 'text-logged-in-root' can not be detected.
sub check_root_ssh_console {
    my $self = shift;

    $self->reveal_myself;
    save_screenshot;
    if (!(check_screen('text-logged-in-root'))) {
        reset_consoles;
        select_console('root-ssh');
    }
    return $self;
}

#Perform concurrent guest installations by calling generate_guest_instances,generate_guest_profiles,install_guest_instances,monitor_concurrent_guest_installations,
#validate_guest_installations_results,clean_up_guest_installations and junit_log_provision.Argument $_guest_names_list is a reference to array that holds all guest
#names to be created and $_guest_profiles_list is a reference to array that holds all guest profiles to be used for guest configurations and installations.
sub concurrent_guest_installations_run {
    my ($self, $_guest_names_list, $_guest_profiles_list) = @_;

    $self->reveal_myself;
    my @_guest_names    = @$_guest_names_list;
    my @_guest_profiles = @$_guest_profiles_list;
    croak("Guest names and profile must be given to create, configure and install guests.") if ((scalar(@_guest_names) eq 0) or (scalar(@_guest_profiles) eq 0));
    $self->generate_guest_instances(@_guest_names);
    $self->generate_guest_profiles(@_guest_profiles);
    $self->install_guest_instances;
    $self->monitor_concurrent_guest_installations;
    $self->validate_guest_installations_results;
    $self->clean_up_guest_installations;
    $self->junit_log_provision((caller(0))[3]);
    return $self;

}

sub post_fail_hook {
    my $self = shift;

    $self->reveal_myself;
    $self->check_root_ssh_console;
    $self->clean_up_guest_installations;
    $self->junit_log_provision((caller(0))[3]);
    $self->SUPER::post_fail_hook;
    return $self;
}

1;
