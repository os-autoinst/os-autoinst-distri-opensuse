# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Setup Netweaver WebGUI access

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

package ensa2_setup_Netweaver_WebGUI_access;
use testapi;
use sles4sap::console_redirection;
use sles4sap::console_redirection::redirection_data_tools;
use sles4sap::sap_host_agent qw(saphostctrl_list_instances);
use sles4sap::sapcontrol qw(sapcontrol);

=head1 NAME

sles4sap/redirection_tests/ensa2_setup_Netweaver_WebGUI_access.pm.pm - Setup Netweaver WebGUI access on PAS for netweaver instances.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Module setup Netweaver WebGUI access for netweaver instances.

B<The key tasks performed by this module include:>

=over

=item * Setup ICM http port on PAS instance via cmdline

=item * Restart NW instance

=item * Configure WebGUI services (via SQL statement)

=item * Activate WebGUI services (via SQL statement)

=item * Restart NW instance again

=item * Check URL is accessible on NW hosts

=back

=head1 OPENQA SETTINGS

=over

=item * B<SAP_SID> : SAP system ID

=item * B<SAP_ENABLE_WEBUI> : SAP Enable WebUI flag

=back
=cut

sub run {
    my ($self, $run_args) = @_;
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});

    # Get PAS host
    my %pas_host = %{$redirection_data->get_pas_host};
    if (!%pas_host) {
        die 'Netweaver deployment not detected despite "SAP_ENABLE_WEBUI" being set' if get_var('SAP_ENABLE_WEBUI');
        return;
    }

    # Everything is now executed on SUT, not worker VM
    my $host = (keys %pas_host)[0];
    my $ip_addr = $pas_host{$host}{ip_address};
    my $user = $pas_host{$host}{ssh_user};
    die "Redirection data missing. Got:\nIP: $ip_addr\nUSER: $user\n" unless $ip_addr and $user;
    record_info("Host: $host");
    connect_target_to_serial(destination_ip => $ip_addr, ssh_user => $user, switch_root => 'yes');

    # Setup ICM http port via cmdline
    my $profile = '';
    my $profile_dir = '/' . join('/', 'sapmnt', get_required_var('SAP_SID'), 'profile') . '/';
    my $host_fqdn = script_output('hostname -f');
    my $ls_output = script_output("ls -1 $profile_dir | grep -v ':'");
    my @all_files = split /\n/, $ls_output;
    my @matching_files = grep { /$host/ && !/\./ } @all_files;
    if (scalar(@matching_files) == 1) {
        $profile = "$profile_dir" . "$matching_files[0]";
    }
    else {
        die "Get profile failed: @matching_files";
        return;
    }

    record_info("profile: $profile");
    assert_script_run("cp $profile $profile.bk");
    assert_script_run("echo 'icm/server_port_0 = PROT=HTTP,PORT=8080' >> $profile");
    assert_script_run("echo icm/host_name_full = $host_fqdn >> $profile");

    # Restart NW instance
    my $instance_data = saphostctrl_list_instances(as_root => 'yes', running => 'yes');
    my $output = sapcontrol(
        webmethod => 'RestartInstance',
        instance_id => $instance_data->[0]{instance_id},
        sidadm => $instance_data->[0]{sap_sid},
        return_output => 'yes');

    # Configure WebGUI services (via SQL statement)
    # Userstore key check
    assert_script_run('su - qesadm -c "hdbuserstore list"');
    assert_script_run('su - qesadm -c "hdbsql -U DEFAULT \'select * from m_services\'" | tee');

    # Activate WebGUI services (via SQL statement)
    my @hdbsql = (
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'MIMES\\' and ICFPARGUID = \\'0CMVCTDU211SGUZWM853S6A3S\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'MIMES\\' and ICFPARGUID = \\'1390BKBVEPQAYPVZ8O7GLZOJ9\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'UR\\' and ICFPARGUID = \\'0SLDKWIWJT0Y8UZ66DNUEDGQD\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'WEBGUI\\' and ICFPARGUID = \\'BO11PUMK7J2UU0LPKQWG0KGS7\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'SAP\\' and ICFPARGUID = \\'0000000000000000000000000\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'SAP\\' and ICFPARGUID = \\'9ROEQ0LR7N1DUVIJPWT3THCDZ\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'ITS\\' and ICFPARGUID = \\'0SLDKWIWJT0Y8UZ66DNUEDGQD\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'ITS\\' and ICFPARGUID = \\'7AEANJ9KQ34VA5EPCKEL8Z27R\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'BC\\' and ICFPARGUID = \\'0V000YHIHJTMAQZ31MI9AONBR\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'BC\\' and ICFPARGUID = \\'DFFAEATGKMFLCDXQ04F0J7FXK\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'GUI\\' and ICFPARGUID = \\'EEPI2GLFNOLHN7IW9R54I61RZ\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'PUBLIC\\' and ICFPARGUID = \\'DFFAEATGKMFLCDXQ04F0J7FXK\\'",
        "hdbsql -U DEFAULT update ICFSERVLOC SET ICFACTIVE = \\'X\\' where ICF_NAME = \\'DEFAULT_HOST\\' and ICFPARGUID = \\'FFFFFFFFFFFFFFFFFFFFFFFFF\\'");

    foreach my $sql (@hdbsql) {
        assert_script_run("sudo su - qesadm -c \"$sql\"");
    }

    # Restart NW instance again
    $output = sapcontrol(
        webmethod => 'RestartInstance',
        instance_id => $instance_data->[0]{instance_id},
        sidadm => $instance_data->[0]{sap_sid},
        return_output => 'yes');

    disconnect_target_from_serial();

    # Check URL is accessible from NW hosts (locally + remotely)
    my %nw_hosts = %{$redirection_data->get_nw_hosts};
    if (!%nw_hosts) {
        die 'Netweaver deployment not detected despite "SAP_ENABLE_WEBUI" being set' if get_var('SAP_ENABLE_WEBUI');
        return;
    }
    for my $host (keys(%nw_hosts)) {
        # Everything is now executed on SUT, not worker VM
        my $ip_addr_client = $nw_hosts{$host}{ip_address};
        my $user = $nw_hosts{$host}{ssh_user};
        my %instance_results;
        die "Redirection data missing. Got:\nIP: $ip_addr_client\nUSER: $user\n" unless $ip_addr_client and $user;

        connect_target_to_serial(destination_ip => $ip_addr_client, ssh_user => $user, switch_root => 'yes');
        my $count = 60;
        for my $i (1 .. $count) {
            my $output = script_output("curl --connect-timeout 1 --max-time 300 -I http://$ip_addr:8080/sap/bc/gui/sap/its/webgui", proceed_on_failure => 1, timeout => 320);
            if ($output =~ /HTTP.* OK/) {
                record_info("WebGUI access succeeded on $host");
                last;
            }
            if ($i == $count) {
                die("WebGUI access failed on $host");
            }
            # Wait and retry if failed
            sleep 5;
            record_info("Retry $i\nCommand curl returns:\n$output");
        }
        disconnect_target_from_serial();
    }
}

1;
