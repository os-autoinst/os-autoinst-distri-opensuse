# SUSE's SLES4SAP openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: hsqldb crmsh
# Summary: Configure HANA-SR cluster
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use network_utils qw(iface);
use hacluster;
use utils qw(write_sut_file systemctl file_content_replace);

sub hanasr_angi_hadr_providers_setup {
    # Setup SAPHanaSR-angi HA/DR providers and
    # add permissions to SAPHanaSR-angi scripts by SUDO
    my ($sid, $instance_id, $sapadm) = @_;
    assert_script_run "su - $sapadm -c 'sapcontrol -nr $instance_id -function StopSystem'";
    my $hadr_template = 'angi_susHanaHADR_AIO.template';
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/sles4sap/$hadr_template -o /tmp/$hadr_template";
    assert_script_run "su - $sapadm -c 'SAPHanaSR-manageProvider --sid $sid --add /tmp/$hadr_template'";
    my $sudo_saphanasr = "# SAPHanaSR-ScaleUp entries for writing srHook cluster attribute and SAPHanaSR-hookHelper\n" .
      "$sapadm ALL=(ALL) NOPASSWD: /usr/sbin/crm_attribute -n hana_" . lc("$sid") . "_*\n" .
      "$sapadm ALL=(ALL) NOPASSWD: /usr/bin/SAPHanaSR-hookHelper --sid=" . uc("$sid") . " *\n";
    write_sut_file("/tmp/etc_sudoers_SAPHanaSR_$sid", "$sudo_saphanasr");
    assert_script_run "cp /tmp/etc_sudoers_SAPHanaSR_$sid /etc/sudoers.d/SAPHanaSR_$sid";
    assert_script_run "su - $sapadm -c 'sapcontrol -nr $instance_id -function StartSystem HDB'";
}

sub run {
    my ($self) = @_;
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $cluster_name = get_cluster_name;
    my ($virtual_ip, $virtual_netmask) = split '/', get_required_var('INSTANCE_IP_CIDR');

    # Set SAP variables
    my $pscmd = $self->set_ps_cmd("HDB");
    my $sapadm = $self->set_sap_info($sid, $instance_id);

    # Synchronize the nodes
    barrier_wait "HANA_CLUSTER_INSTALL_$cluster_name";

    select_serial_terminal;

    my $node1 = choose_node(1);
    my $node2 = choose_node(2);

    if (is_node(1)) {
        # Create the resource configuration
        # hana_cluster_msl.conf is used in 15-SP3, 15-SP2, 12-SP5 becuase these version don't support promote role.
        # hana_cluster_cln.conf is used in 15-SP4 and above version.
        # angi_hana_cluster.conf is used for angi testing.
        my $cluster_conf = get_var('USE_SAP_HANA_SR_ANGI') ? 'angi_hana_cluster.conf' : "hana_cluster_$sles4sap::resource_alias.conf";
        assert_script_run 'curl -f -v ' . autoinst_url . "/data/sles4sap/$cluster_conf -o /tmp/$cluster_conf";
        $cluster_conf = '/tmp/' . $cluster_conf;
        my $iface = get_var('SUT_NETDEVICE', iface());

        # Initiate the template
        file_content_replace($cluster_conf, '--sed-modifier' => 'g',
            '%SID%' => $sid,
            '%HDB_INSTANCE%' => $instance_id,
            '%AUTOMATED_REGISTER%' => get_required_var('AUTOMATED_REGISTER'),
            '%VIRTUAL_IP_ADDRESS%' => $virtual_ip,
            '%VIRTUAL_IP_NETMASK%' => $virtual_netmask,
            '%NIC%' => $iface);

        foreach ($node1, $node2) {
            add_to_known_hosts($_);
        }
        assert_script_run "scp -qr /usr/sap/${sid}/SYS/global/security/rsecssfs/* root\@${node2}:/usr/sap/${sid}/SYS/global/security/rsecssfs/";
        assert_script_run qq(su - $sapadm -c "hdbsql -u system -p $sles4sap::instance_password -i $instance_id -d SYSTEMDB \\"BACKUP DATA FOR FULL SYSTEM USING FILE ('backup')\\""), 900;
        assert_script_run "su - $sapadm -c 'hdbnsutil -sr_enable --name=$node1'";

        # Synchronize the nodes
        barrier_wait "HANA_INIT_CONF_$cluster_name";
        barrier_wait "HANA_CREATED_CONF_$cluster_name";

        hanasr_angi_hadr_providers_setup($sid, $instance_id, $sapadm) if get_var('USE_SAP_HANA_SR_ANGI');

        # Commits configuration changes into the cluster
        my $resource = $sles4sap::resource_alias . "_SAPHanaCtl_${sid}_HDB$instance_id";
        my @crm_cmds = ("crm configure load update $cluster_conf",
            "crm resource refresh $resource",
            "crm resource maintenance $resource off");
        foreach my $cmd (@crm_cmds) {
            wait_for_idle_cluster;
            assert_script_run $cmd;
        }
    }
    else {
        # Synchronize the nodes
        barrier_wait "HANA_INIT_CONF_$cluster_name";

        assert_script_run "su - $sapadm -c 'sapcontrol -nr $instance_id -function StopSystem HDB'";
        assert_script_run "until su - $sapadm -c 'hdbnsutil -sr_state' | grep -q 'online: false' ; do sleep 1 ; done", 120;
        sleep bmwqemu::scale_timeout(30);
        $self->do_hana_sr_register(node => $node1);
        sleep bmwqemu::scale_timeout(10);
        if (get_var('USE_SAP_HANA_SR_ANGI')) {
            hanasr_angi_hadr_providers_setup($sid, $instance_id, $sapadm);
        }
        else {
            assert_script_run "su - $sapadm -c 'sapcontrol -nr $instance_id -function StartSystem HDB'";
        }
        my $looptime = 90;
        while (script_run "su - $sapadm -c 'hdbnsutil -sr_state' | grep -q 'online: true'", timeout => 120) {
            sleep bmwqemu::scale_timeout(1);
            --$looptime;
            last if ($looptime <= 0);
        }
        if ($looptime <= 0) {
            # sr_state is not online after 90 seconds. Start system again and retry
            assert_script_run "su - $sapadm -c 'sapcontrol -nr $instance_id -function StartSystem HDB'";
            sleep bmwqemu::scale_timeout(10);
            assert_script_run "until su - $sapadm -c 'hdbnsutil -sr_state' | grep -q 'online: true' ; do sleep 1 ; done";
        }

        # Synchronize the nodes
        barrier_wait "HANA_CREATED_CONF_$cluster_name";
    }

    # Synchronize the nodes
    barrier_wait "HANA_LOADED_CONF_$cluster_name";
    save_state;

    # Wait for resources to be started
    wait_until_resources_started(timeout => 300);

    # And check for the state of the whole cluster
    check_cluster_state;
    $self->check_replication_state;
    $self->check_hanasr_attr;
    $self->check_landscape;
    assert_script_run 'cs_clusterstate';

    # Check getting crm configuration by <sid>adm
    check_crm_nonroot($sapadm);
}

1;
