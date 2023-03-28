# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: docker MozillaFirefox
# Summary: check HAWK GUI with the a python+selenium script and firefox
# Maintainer: QE-SAP <qe-sap@suse.de>, Alvaro Carvajal <acarvajal@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use x11test;
use x11utils;
use version_utils 'is_desktop_installed';

sub install_docker {
    my $docker_url = "https://download.docker.com/linux/static/stable/x86_64/docker-19.03.5.tgz";

    assert_script_run "curl -s $docker_url | tar zxf - --strip-components 1 -C /usr/bin", 120;
    # Allow the user to run docker. We can't add him to the docker group without restarting X.
    # The final colon is to avoid a bash syntax error when assert_script_run() appends a semicolon
    assert_script_run "/usr/bin/dockerd -G users --insecure-registry registry.suse.de >/dev/null 2>&1 & :";
}


sub run {
    my ($self) = @_;
    my $cluster_name = get_cluster_name;

    # For facilitating the QEM process, the hawk client system will always be a 15-SP3 version
    # That means we need to change the version and reload the needles
    if (get_var('CLIENT_VERSION')) {
        set_var('VERSION', get_var('CLIENT_VERSION'), reload_needles => 1);
        record_info('Version switch', 'New version = ' . get_var('VERSION'));
    }

    # Wait for each cluster node to check for its hawk service
    barrier_wait("HAWK_GUI_INIT_$cluster_name");

    unless (is_desktop_installed()) {
        record_info "HAWK GUI test", "HAWK GUI test requires GUI desktop installed";
        return;
    }

    select_console 'root-console';
    install_docker;

    # TODO: Use another namespace using team group name
    # Docker image source in https://github.com/ricardobranco777/hawk_test
    # It will be eventually moved to https://github.com/ClusterLabs/hawk/e2e_test
    my $docker_image = "registry.opensuse.org/devel/openqa/ci/tooling/containers_15_4/hawk_test:latest";

    assert_script_run("docker pull $docker_image", 240);

    # Rest of the test needs to be performed on the x11 console, but with the
    # HA_CLUSTER setting that console is not yet activated; newer versions of gdm
    # expect the console on tty2 which can lead to false positives as there is no
    # session there yet, so instead this goes through the displaymanager console to
    # login into the x11 session.
    select_console 'displaymanager';
    $self->handle_displaymanager_login();
    x11_start_program('xterm');
    turn_off_gnome_screensaver;

    my $pyscr = 'hawk_test';
    my $path = 'test';

    # Run test
    my $browser = 'firefox';
    my $node1 = choose_node(1);
    my $node2 = choose_node(2);
    my $results = "$path/$pyscr.results";
    my $retcode = "$path/$pyscr.ret";
    my $logs = "$path/$pyscr.log";
    my $virtual_ip = "10.0.2.222/24";

    add_to_known_hosts($node1);
    add_to_known_hosts($node2);
    assert_script_run "mkdir -m 1777 $path";
    assert_script_run "xhost +";
    barrier_wait("HAWK_GUI_CPU_TEST_START_$cluster_name");
    my $docker_cmd = "docker run --rm --name test --ipc=host -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=\$DISPLAY -v \$PWD/$path:/$path ";
    $docker_cmd .= "$docker_image -b $browser -H $node1 -S $node2 -s $testapi::password -r /$results --virtual-ip $virtual_ip";
    enter_cmd "$docker_cmd 2>&1 | tee $logs; echo $pyscr-\$PIPESTATUS > $retcode";
    assert_screen "hawk-$browser", 60;

    my $loop_count = 360;    # 30 minutes (360*5)
    while (1) {
        $loop_count--;
        last if ($loop_count < 0);
        if (check_screen('generic-desktop', 0, no_wait => 1)) {
            # We may reach generic-desktop in two scenarios: (1) the python script
            # finishes, or (2) it has finished an individual test and closed the
            # browser but it's in the process of opening a new browser instance.
            # The following check_screen tries to catch scenario 2, if it doesn't
            # then we assume we're in scenario 1
            next if (check_screen("hawk-$browser", 60));    # python script still running
            last;
        }
        sleep 5;
    }
    if ($loop_count < 0) {
        record_info("$browser failed", "Test with browser [$browser] could not be completed in 30 minutes", result => 'softfail');
        script_run "docker container kill test";
    }

    save_screenshot;

    assert_screen "generic-desktop";
    barrier_wait("HAWK_GUI_CPU_TEST_FINISH_$cluster_name");

    # Error, log and results handling
    select_console 'user-console';

    # Upload output of python/selenium scripts
    my $output = script_output "cat $retcode";
    if ($output =~ m/$pyscr-(\d+)/) {
        my $ret = $1;
        record_info("$browser retcode", "Test [$pyscr] on browser [$browser] failed with code: [$ret]. Check log files for details", result => 'softfail')
          if ($ret != 0);
    }
    else {
        record_info("$browser unknown error", "Test [$pyscr] failed on browser [$browser]. Unknow error: [$output]. Check log files for details", result => 'softfail');
    }
    script_run "tar zcf logs.tgz $path";
    upload_logs "logs.tgz";

    # Upload results
    my $are_results = script_run("ls $results");
    # Fail test if results file does not exist, otherwise parse it
    die "Selenium test [$pyscr] aborted. Check logs" if ($are_results or !defined $are_results);
    parse_extra_log(IPA => $results);

    # Synchronize with the nodes
    barrier_wait("HAWK_GUI_CHECKED_$cluster_name");

    # Wait for master node to reboot
    barrier_wait("HAWK_FENCE_$cluster_name");
}

1;
