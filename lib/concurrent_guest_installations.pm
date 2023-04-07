# CONCURRENT VIRTUAL MACHINE INSTALLATIONS MODULE
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This module supports concurrent multiple virtual machine
# installations with vm names and profiles obtained from %_store_of_guests
# which maintains the mapping between vm names and their profiles.
# It is then passed to instantiate_guests_and_profiles to instantiate
# guests. For example, if %_store_of_guests = ( "vm_name_1" => "vm_profile_1",
# "vm_name_2" => "vm_profile_2", "vm_name_3" => "vm_profile_3")
# is passed to instantiate_guests_and_profiles, then vm_name_1 will be
# created and installed using vm_profile_1 and so on. Any vm profile names
# can be given as long as there are corresponding profile files in
# data/virt_autotest/guest_params_xml_files folder, for example, there
# should be profile file called vm_profile_1.xml, vm_profile_2.xml and
# vm_profile_3.xml in the folder in this example. Installation progress
# monitoring,result validation, junit log provision,environment cleanup
# and failure handling are also included and supported. Subroutine
# concurrent_guest_installations_run is the convenient one to be called
# to perform all the above operations if necessary.
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
use version_utils;
use virt_autotest_base;
use alp_workloads::kvm_workload_utils;
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

#Get guest names from hash argument passed in, for example: foreach my $_element (keys(%_store_of_guests))
#There is no restriction on the form or format of guest instance name.
#Get guest profiles names also from hash argument passed in, for example, $_store_of_guests{$_element}
#These names should be the file name without extension in data/virt_autotest/guest_params_xml_files folder.
#Guest profile xml file will be guest profile name + '.xml' extension and fetched using HTTP::Request and
#parsed using XML::Simple.
sub instantiate_guests_and_profiles {
    my $self = shift;
    my $_guests_to_be_instantiated = shift;
    my %_store_of_guests = %$_guests_to_be_instantiated;

    $self->reveal_myself;
    foreach my $_element (keys(%_store_of_guests)) {
        $guest_instances{$_element} = bless({%$self}, ref($self));
        diag "Guest $_element is blessed";
        my $_ua = LWP::UserAgent->new;
        my $_geturl = data_url("virt_autotest/guest_params_xml_files/$_store_of_guests{$_element}{PROFILE}.xml");
        my $_req = HTTP::Request->new(GET => "$_geturl");
        my $_res = $_ua->request($_req);
        my $_guest_profile = (XML::Simple->new)->XMLin($_res->content, SuppressEmpty => '');
        $_guest_profile->{guest_name} = $_element;
        $_guest_profile->{guest_registration_code} = $_store_of_guests{$_element}{REG_CODE};
        $_guest_profile->{guest_registration_extensions_codes} = $_store_of_guests{$_element}{REG_EXTS_CODES};
        $guest_instances_profiles{$_element} = $_guest_profile;
        $self->edit_guest_profile_with_template($_element) if ($_store_of_guests{$_element}{USE_TEMPLATE} eq '1');
        diag "Guest $_element is going to use profile" . Dumper($guest_instances_profiles{$_element});
    }

    return $self;
}

# Motivation of the function:
#   When multiple vms' profiles have great similarity and have some rules
#   to follow to generate different profiles from a template, such a function
#   will save a lot of static profile files in data/virt_autotest/guest_params_xml_files.
# Usage:
#   In testsuite settings, var UNIFIED_GUEST_PROFILE_TEMPLATE_FLAGS copes
#   with var UNIFIED_GUEST_PROFILES. Both have values separated with comma.
#   If at a position of UNIFIED_GUEST_PROFILE_TEMPLATE_FLAGS the value is '1',
#   the UNIFIED_GUEST_PROFILES value at the same position will be the template profile for the vm.
#   It's supported that some vms use template while some do not.
sub edit_guest_profile_with_template {
    # To be overloaded in child classes with customized needs.
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
        if ($guest_instances{$_}->has_noautoconsole_for_sure) {
            assert_screen('text-logged-in-root');
            $guest_instances{$_}->do_attach_guest_installation_screen_without_session;
        }
        $guest_instances{$_}->{guest_installation_attached} = 'true';
        save_screenshot;
        if (!(check_screen([qw(guest-installation-yast2-started guest-installation-anaconda-started linux-login)], timeout => 180 / get_var('TIMEOUT_SCALE', 1)))) {
            record_info("Failed to detect or guest $guest_instances{$_}->{guest_name} does not have installation window opened", "This might be caused by improper console settings or reboot after installaton finishes. Will continue to monitor its installation progess, so this is not treated as fatal error at the moment.");
        }
        else {
            record_info("Guest $guest_instances{$_}->{guest_name} has installation window opened", "Will continue to monitor its installation progess");
        }
        save_screenshot;
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
    my $_guest_installations_left = scalar(keys %guest_instances) - scalar(@guest_installations_done);
    my $_guest_installations_not_the_last = 1;
    my $_monitor_start_time = time();
    while (time() - $_monitor_start_time <= 7200) {
        foreach (keys %guest_instances) {
            if ($guest_instances{$_}->{guest_installation_result} eq '') {
                $guest_instances{$_}->attach_guest_installation_screen if (($_guest_installations_not_the_last ne 0) or ($guest_instances{$_}->{guest_installation_attached} ne 'true'));
                $guest_instances{$_}->monitor_guest_installation;
                if ($guest_instances{$_}->{guest_installation_result} eq '') {
                    $_guest_installations_not_the_last = 0 if ($_guest_installations_left eq 1);
                    $guest_instances{$_}->detach_guest_installation_screen if ($_guest_installations_not_the_last ne 0);
                }
            }
            my $_current_guest_instance = $_;
            if ((!(grep { $_ eq $_current_guest_instance } @guest_installations_done)) and ($guest_instances{$_}->{guest_installation_result} ne '')) {
                push(@guest_installations_done, $_);
                $_guest_installations_left = scalar(keys %guest_instances) - scalar(@guest_installations_done);
                $guest_instances{$_}->collect_guest_installation_logs_via_ssh if ($guest_instances{$_}->{guest_installation_result} ne 'PASSED');
                last if ($_guest_installations_left eq 0);
            }
        }
        last if ($_guest_installations_left eq 0);
        sleep 60;
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
            push(@guest_installations_done, $_);
            $guest_instances{$_}->collect_guest_installation_logs_via_ssh;
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
    $self->detach_all_nfs_mounts;
    return $self;
}

#Generate junit log
sub junit_log_provision {
    my ($self, $runsub) = @_;

    $self->reveal_myself;
    my $_guest_installations_results;
    foreach (keys %guest_instances) {
        $_guest_installations_results->{$_}{status} = $guest_instances{$_}->{guest_installation_result};
        $_guest_installations_results->{$_}{start_run} = $guest_instances{$_}->{start_run};
        $_guest_installations_results->{$_}{stop_run} = ($guest_instances{$_}->{stop_run} eq '' ? time() : $guest_instances{$_}->{stop_run});
        $_guest_installations_results->{$_}{test_time} = strftime("\%Hh\%Mm\%Ss", gmtime($_guest_installations_results->{$_}{stop_run} - $_guest_installations_results->{$_}{start_run}));
    }
    if (!version_utils::is_alp) {
        $self->{"product_tested_on"} = script_output("cat /etc/issue | grep -io -e \"SUSE.*\$(arch))\" -e \"openSUSE.*[0-9]\"");
    } else {
        alp_workloads::kvm_workload_utils::exit_kvm_container;
        $self->{"product_tested_on"} = script_output(q@cat /etc/os-release |grep PRETTY_NAME | sed 's/PRETTY_NAME=//'@);
        alp_workloads::kvm_workload_utils::enter_kvm_container_sh;
    }
    $self->{"product_name"} = ref($self);
    $self->{"package_name"} = ref($self);
    my $_guest_installation_xml_results = virt_autotest_base::generateXML($self, $_guest_installations_results);
    script_run("echo \'$_guest_installation_xml_results\' > /tmp/output.xml");
    save_screenshot;
    upload_logs("/tmp/output.xml");
    parse_junit_log("/tmp/output.xml");
    return $self;
}

#Check whether current console is root-ssh console of the hypervisor and re-connect if relevant needle can not be detected.
sub check_root_ssh_console {
    my $self = shift;

    $self->reveal_myself;
    script_run("clear");
    save_screenshot;
    if ((version_utils::is_alp && !check_screen('in-libvirtd-container-bash')) or (!version_utils::is_alp and !(check_screen('text-logged-in-root')))) {
        reset_consoles;
        select_console('root-ssh');
        alp_workloads::kvm_workload_utils::enter_kvm_container_sh if (version_utils::is_alp);
    }

    return $self;
}

#Perform concurrent guest installations by calling instantiate_guests_and_profiles,install_guest_instances,monitor_concurrent_guest_installations,
#validate_guest_installations_results,clean_up_guest_installations and junit_log_provision.Argument $_guest_names_list is a reference to array that
#holds all guest names to be created and $_guest_profiles_list is a reference to array that holds all guest profiles to be used for guest configurations
#and installations.
sub concurrent_guest_installations_run {
    my $self = shift;
    my $_store_of_guests = shift;

    $self->reveal_myself;
    croak("Guest names and profile must be given to create, configure and install guests.") if ((scalar(keys(%$_store_of_guests)) eq 0) or (scalar(values(%$_store_of_guests)) eq 0));
    $self->instantiate_guests_and_profiles($_store_of_guests);
    $self->install_guest_instances;
    $self->monitor_concurrent_guest_installations;
    $self->clean_up_guest_installations;
    $self->validate_guest_installations_results;
    $self->junit_log_provision((caller(0))[3]);
    $self->save_guest_installations_assets;
    return $self;

}

#Call virt_autotest_base::upload_guest_assets to upload guest assets if it is successfully installed.
sub save_guest_installations_assets {
    my $self = shift;

    $self->reveal_myself;
    return $self if (!get_var('UPLOAD_GUEST_ASSETS'));
    while (my ($_index, $_element) = each(@guest_installations_done)) {
        delete $guest_installations_done[$_index] if ($guest_instances{$_element}->{guest_installation_result} ne 'PASSED');
    }
    @guest_installations_done = grep { defined $_ } @guest_installations_done;
    $self->{success_guest_list} = \@guest_installations_done;
    $self->virt_autotest_base::upload_guest_assets;
    return $self;
}

sub post_fail_hook {
    my $self = shift;

    $self->reveal_myself;
    $self->check_root_ssh_console;
    $self->junit_log_provision((caller(0))[3]);
    $self->SUPER::post_fail_hook;
    $self->save_guest_installations_assets;
    alp_workloads::kvm_workload_utils::collect_kvm_container_setup_logs if (version_utils::is_alp);
    return $self;
}

1;
