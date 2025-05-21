# SUSE's openQA tests
#
# Copyright 2022-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test the kubectl utility
#
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils;
use publiccloud::utils;
use containers::k8s;

my $is_local_k3s = 0;

sub run {
    select_serial_terminal;

    install_kubectl();
    # Record kubectl version and check if the tool itself is healthy
    record_info("kubectl", script_output("kubectl version --client --output=json"));

    # Configure CSP/k3s. Only one CSP at a time is possible due to the conflicting configuration in .kube/config
    assert_script_run('mkdir -p ~/.kube');
    if (get_var("KUBECTL_CLUSTER", "k3s") eq 'k3s') {
        if (my $kubeconf = get_var('KUBE_CONFIG')) {
            $kubeconf =~ s/\n//g;
            script_run("echo -en $kubeconf | base64 -d | gzip -d > /tmp/k3s-qa.yaml", 0);
            assert_script_run('export KUBECONFIG=/tmp/k3s-qa.yaml');
            sleep;
        } else {
            # Install k3s locally in SUT
            $is_local_k3s = 1;
            install_k3s();
        }

        # Ensure k3s has not installed its own kubectl
        assert_script_run("! stat /usr/local/bin/kubectl");
        validate_script_output("whereis kubectl", sub { $_ !~ m/\/usr\/local\/bin/ });
    } else {
        die "Invalid or unsupported KUBECTL_CLUSTER";
    }

    # Function to check if the output either has no resources or has at least two lines
    # Two lines because one line is the header and the following lines are the data rows
    validate_script_output("kubectl cluster-info", qr/Kubernetes .* is running at /);
    record_info('Testing: get/smoketest', 'State tests (get commands)');
    # Check for default namespaces to be present
    validate_script_output("kubectl get namespaces", qr/default/);
    validate_script_output("kubectl get namespaces", qr/system/);
    # Check service output
    validate_script_output("kubectl get service --all-namespaces", sub { $_ =~ m/No resources found/ || split(/\n/, $_) > 1; });
    # At least the coredns pod must be present
    validate_script_output_retry("kubectl get pods --all-namespaces", sub { $_ =~ m/coredns/ });
    # There must be at least one endpoint present
    validate_script_output("kubectl get endpoints", sub { split(/\n/, $_) > 1; });
    # There must be at least the coredns deployment present
    validate_script_output("kubectl get deployments --all-namespaces", sub { $_ =~ m/coredns/ });
    # Check if more than 1 replicasets are present
    validate_script_output("kubectl get replicasets --all-namespaces --no-headers", sub { split(/\n/, $_) > 1; });
    # Check ingresses, those are empty by default
    validate_script_output("kubectl get ingresses --all-namespaces --no-headers", sub { $_ =~ m/No resources found/ });

    ## Test the configuration
    record_info('Testing: config', 'Configugration tests');
    assert_script_run("kubectl config view");
    validate_script_output("kubectl config view -o jsonpath={.clusters[].name}", qr/default/);
    validate_script_output("kubectl config view -o jsonpath={.contexts[].name}", qr/default/);

    ## Test the context configuration
    assert_script_run("kubectl config get-contexts");
    validate_script_output("kubectl config get-contexts", sub { $_ =~ m/default/ });
    validate_script_output("kubectl config current-context", sub { $_ =~ m/default/ });
    assert_script_run("kubectl config use-context default");
    assert_script_run("kubectl config set-context --current --namespace=default");
    assert_script_run("kubectl config set-context localhost --user=root --namespace=default");
    assert_script_run("kubectl config use-context localhost");
    assert_script_run("kubectl config use-context default");
    assert_script_run("kubectl config unset contexts.localhost");

    ## Test jobs
    record_info('Testing: jobs and pods', 'job and pod test runs');
    # The testing.registry must be registered in k8s as private registry and point to REGISTRY variable.
    assert_script_run("kubectl create job sayhello --image=registry.opensuse.org/opensuse/busybox -- echo 'Hello World'");
    validate_script_output("kubectl get jobs --no-headers", qr/sayhello/);
    assert_script_run('kubectl wait jobs/sayhello --for=condition=complete --timeout=300s', timeout => 330);
    # Check job output. First get the pod name
    my $pod = script_output('kubectl get pods -o name --no-headers=true | grep sayhello');
    script_retry("kubectl logs $pod | grep 'Hello World'", retry => 5, delay => 10);    # collection of the log can sometime take some time
    assert_script_run("kubectl delete job sayhello");

    assert_script_run("kubectl create job gimme-date --image=registry.opensuse.org/opensuse/busybox -- date");
    validate_script_output("kubectl get jobs --no-headers", qr/gimme-date/);
    assert_script_run('kubectl wait jobs/gimme-date --for=condition=complete --timeout=300s', timeout => 330);
    assert_script_run("kubectl delete job gimme-date");

    ## Apply a custom Deployment, test scaling
    record_info('Testing: deployment', 'deployment test');
    assert_script_run('curl -o deployment.yml ' . data_url('containers/kubectl/deployment.yml'));
    assert_script_run('kubectl apply -f deployment.yml');
    assert_script_run('kubectl wait deployment nginx-deployment --for condition=available --timeout=300s', timeout => 330);
    validate_script_output('kubectl describe deployments/nginx-deployment | grep Replicas', sub { $_ =~ m/2 desired.*2 total/ });
    assert_script_run('kubectl describe deployments/nginx-deployment');
    # Scale out
    assert_script_run('kubectl scale --replicas=5 deployments/nginx-deployment');
    assert_script_run('kubectl wait deployment nginx-deployment --for condition=available --timeout=300s', timeout => 330);
    validate_script_output('kubectl describe deployments/nginx-deployment | grep Replicas', sub { $_ =~ m/5 desired.*5 total/ });
    # Scale in
    assert_script_run('kubectl scale --replicas=2 deployments/nginx-deployment');
    # When scaling healthy cluster in the deployment condition is always available even when more than specified amount of replicas still exist
    validate_script_output_retry('kubectl get events | grep ScalingReplicaSet | tail -n1', qr/Scaled down replica set nginx-deployment-.*to 2/, retry => 6, delay => 20, timeout => 10);
    assert_script_run('kubectl wait deployment nginx-deployment --for condition=available --timeout=300s', timeout => 330);
    validate_script_output('kubectl describe deployments/nginx-deployment | grep Replicas', sub { $_ =~ m/2 desired.*2 total/ });
    # Test the port-forwarding and the webserver
    my $pid = background_script_run('kubectl port-forward deploy/nginx-deployment 8008:80');
    validate_script_output_retry("curl http://localhost:8008/index.html", qr/I am Groot/, retry => 6, delay => 20, timeout => 10);
    assert_script_run("kill $pid");    # terminate port-forwarding

    ## Test service
    # Create predefined service, and check if it appears as desired
    record_info('Testing: services', 'service test');
    assert_script_run('curl -o service.yml ' . data_url('containers/kubectl/service.yml'));
    assert_script_run('kubectl apply -f service.yml');
    validate_script_output('kubectl get services', qr/web-load-balancer/);
    validate_script_output('kubectl describe services/web-load-balancer', sub { $_ =~ m/.*Name:.*web-load-balancer.*/ });
    validate_script_output('kubectl describe services/web-load-balancer', sub { $_ =~ m/.*Port:.*8080\/TCP.*/ });
    validate_script_output('kubectl describe services/web-load-balancer', sub { $_ =~ m/.*TargetPort:.*80\/TCP.*/ });
    validate_script_output('kubectl describe services/web-load-balancer', sub { $_ =~ m/.*Endpoints:.*10.*/ });
    # test need to wait for event: Updated LoadBalancer with new IPs
    my ($ip, $c) = 5;
    do {
        sleep 5;
        $ip = script_output('kubectl get services -l app=nginx -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}"');
    } while (!$ip || --$c == 0);
    record_info('Balancer IP', $ip);
    validate_script_output_retry("curl http://$ip:8080/index.html", qr/I am Groot/, retry => 6, delay => 20, timeout => 10);
}

sub _cleanup {
    script_run('kubectl delete -f service.yml --force');
    script_run('kubectl delete -f deployment.yml --force');
    script_run('kubectl delete jobs --all --force');

    if ($is_local_k3s) {
        script_run('systemctl --no-pager disable --now k3s');
    }
}

sub post_run_hook {
    _cleanup;
}

sub post_fail_hook {
    # Try to collect as much information about kubernetes as possible
    script_run('kubectl describe deployments');
    script_run('kubectl describe services');
    script_run('kubectl describe pods');

    _cleanup;
}

1;
