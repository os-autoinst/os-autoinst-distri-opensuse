# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Basic aistack test

# Summary: This test performs the following actions
#  - Create a VM in EC2 using SLE-Micro-BYOS later than 6.0 version
#  - Install the required dependencies to install the aistack helm chart
#  - Test access to OpenWebUI and run integration tests with Ollama and MilvusDB
# Maintainer: Yogalakshmi Arunachalam <yarunachalam@suse.com>
#

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal;
use publiccloud::utils;
use publiccloud::ssh_interactive;
use transactional;
use containers::k8s;
use strict;
use warnings;
use utils;
use publiccloud::utils;
use transactional qw(process_reboot trup_install trup_shell);
use File::Basename;
use version_utils;
use Data::Dumper;

sub install_dependency_package {
    my ($instance) = @_;
    my $rke2_url = get_var('RKE2_URL');
    my $kubectl_url = get_var('KUBECTL_URL');
    my $helm_url = get_var('HELM_URL');

    record_info('Dep pkg install');
    trup_call("pkg install curl git docker");

    # docker activation section
    process_reboot(trigger => 1);
    systemctl("enable docker");
    systemctl("start docker");
    systemctl("status docker");

    # rke2 activation section
    script_run("curl -sSL $rke2_url -o ./install_rke2.sh && chmod 775 ./install_rke2.sh");
    script_run("sh ./install_rke2.sh");
    script_run("echo 'export PATH=\$PATH:/opt/rke2/bin' >> ~/.bashrc");
    systemctl("enable rke2-server.service");
    systemctl("start rke2-server.service");
    systemctl("status rke2-server.service");
    script_run("rke2 --version");

    # helm activation section
    script_run("curl -sSL $helm_url -o ./install_helm.sh && chmod 775 ./install_helm.sh");
    script_run("sh ./install_helm.sh");
    script_run("helm version");

    # kubectl activation section
    script_run("curl -sSL $kubectl_url -o ./kubectl && chmod +x ./kubectl");
    script_run("sudo mv ./kubectl /usr/local/bin/");
    script_run("kubectl version --client");
}

sub install_dependency_components {
    my ($instance) = @_;
    my $cert_repo = get_var('HELM_CERTS');
    my $ingress_repo = get_var('HELM_INGRESS');
    my $ing_ver = get_var('ING_VERSION');

    # Add Ingress Controller to open-webui endpoint
    assert_script_run("helm repo add $ingress_repo");
    assert_script_run("helm repo update");
    assert_script_run("helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --set controller.service.type=ClusterIP --version $ing_ver --create-namespace", timeout => 120);

    # Add cert-manager repo,install
    assert_script_run("helm repo add $cert_repo");
    assert_script_run("helm repo update");
    assert_script_run("helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.15.2 --set crds.enabled=true", timeout => 120);
}

sub config_kubectl {
    my ($instance) = @_;

    # config kubectl
    record_info('CONFIG kubectl');
    assert_script_run("mkdir -p ~/.kube");
    assert_script_run("sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config");
    assert_script_run("kubectl config get-contexts");
    assert_script_run("kubectl config use-context default");
    assert_script_run("kubectl config view");
}

sub install_aistack_chart {
    my ($instance, $ai_chart_repo, $namespace, $vf_name) = @_;
    my $SECRET_application_collection = get_var('_SECRET_DOCKER');
    my $cert_repo = get_var('HELM_CERTS');
    my $ingress_repo = get_var('HELM_INGRESS');
    my $docker_user_name = get_var('USER_DOCKER');
    my $repo_url = get_var('HELM_CHARTS');
    my $git_token = get_var('_SECRET_SSH');
    my $ing_ver = get_var('ING_VERSION');
    my $local_storage_name = 'local_path_storage.yaml';

    record_info('AISTACK charts install');
    assert_script_run("helm list --all-namespaces");
    assert_script_run("kubectl get pods --all-namespaces");

    # Access to Application collection registery
    # Get docker username and password
    assert_script_run("kubectl create ns $namespace");
    assert_script_run("kubectl create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username='$docker_user_name' --docker-password='$SECRET_application_collection' -n $namespace", timeout => 120);

    # Install private-ai-stack
    my $gitlab_clone_url = 'https://git:' . $git_token . '@' . $repo_url;
    assert_script_run("git clone $gitlab_clone_url");
    assert_script_run("curl " . data_url("aistack/$vf_name") . " -o $vf_name", 60);
    assert_script_run("curl -o $vf_name $ai_chart_repo", timeout => 120);

    # local-path-storage.yaml is a copy off https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
    assert_script_run("curl " . data_url("aistack/$local_storage_name") . " -o $local_storage_name", 60);
    assert_script_run("kubectl apply -f $local_storage_name", timeout => 120);
    assert_script_run("helm upgrade --install suse-private-ai private-ai-charts --namespace $namespace --create-namespace --values $vf_name --set open-webui.ingress.class=nginx", timeout => 600);
    assert_script_run("kubectl get all --namespace $namespace");
    sleep 180;

    # Check pod status and log for successful
    # Loop thru each pod and pod status is running,error,failed,CrashLoopBackoff,ContainerStatusUnknown skip to next pod
    # any other pod status check the log for Failure,Error,Exception record the log and skip to next pod
    # if not loop thru till it reaches the max_retries to ensure the pod comes to running or failure state.
    # After reaching max_retries , record the pod details which does not run after reaching max_retries
    my $max_retries = 15;
    my $sleep_interval = 10;
    my @out = split(' ', script_output("kubectl get pods --namespace $namespace -o custom-columns=':metadata.name'"));
    record_info("Pod names", join(" ", @out));
  POD_LOOP: foreach my $pod (@out) {
        my $counter = 0;
        my $start_time = time();
        while ($counter++ < $max_retries) {
            my $status = script_output("kubectl get pod $pod -n $namespace -o=jsonpath='{.status.phase}'", proceed_on_failure => 1);
            my $logs = script_output("kubectl logs $pod -n $namespace", proceed_on_failure => 1);
            if ($status eq 'Running') {
                record_info("$pod is running. ");
                next POD_LOOP;
            } elsif ($status =~ /^(Error|Failed|CrashLoopBackOff|ContainerStatusUnknown)$/) {
                record_info("$pod failed due to error in log: $logs \n ");
                next POD_LOOP;
            } else {
                if ($logs =~ /ERROR|FAILURE|Exception|Failed/) {
                    record_info("$pod failed due to error in log: $logs \n ");
                    next POD_LOOP;
                }    # if log
                sleep $sleep_interval;
            }    # if status
        }    # while loop
        record_info("$pod is not running after $max_retries ");
    }    #pod loop

    assert_script_run("kubectl get all --namespace $namespace");
    record_info("Logs for the pods which is not in running or pending state");
    foreach my $pod (@out) {
        my $status = script_output("kubectl get pod $pod -n $namespace -o=jsonpath='{.status.phase}'", proceed_on_failure => 1);
        if ($status !~ /^(Running|Pending|Completed)$/) {
            my $logs = script_output("kubectl logs $pod -n $namespace", proceed_on_failure => 1);
            record_info("$pod is in $status state. Logs:\n$logs\n");
        }
    }    # pod loop
}

sub test_openwebui_service {
    my ($instance, $namespace) = @_;
    my $sr_name = 'open-webui';
    my $host_name = get_var('OPENWEBUI_HOSTNAME');

    # After successfull installation, Get open-webUI ipaddress and add in /etc/host and verify connectivity
    record_info('OpenWebUI service');
    assert_script_run("kubectl get ingress --namespace $namespace -o json");
    my $ipaddr = script_output("kubectl get ingress -n $namespace -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'");
    assert_script_run("echo \"$ipaddr $host_name\" | sudo tee -a /etc/hosts > /dev/null");
    set_var('OPENWEBUI_IP', "$ipaddr");
    record_info("Added $ipaddr to /etc/hosts with hostname $host_name");

    # connect open-webui service
    my $curl_cmd = "curl -v -k https://$host_name";
    my $curl_result = script_run($curl_cmd);
    if ($curl_result == 0) {
        record_info("Successfully connected to the open-webui service at $curl_cmd \n");
    } else {
        die "Unable to connect to the open-webui service at $curl_cmd\n";
    }

    # create Admin user
    my $signup_url = "https://$host_name/api/v1/auths/signup";
    my $login_url = "https://$host_name/api/v1/auths/signin";
    my $admin_email = get_var('OPENWEBUI_ADMIN_EMAIL');
    my $admin_username = get_var('OPENWEBUI_ADMIN');
    my $admin_password = get_var('OPENWEBUI_ADMIN_PWD');
    my $signup_json = '{"email": "' . $admin_email . '", "name": "' . $admin_username . '", "password": "' . $admin_password . '"}';
    my $signup_cmd = "curl -v -k $signup_url -H \"Content-Type: application/json\" -d \'$signup_json'";
    assert_script_run($signup_cmd, fail_message => "Unable to create admin user using $signup_cmd");
    record_info("Created admin user");

    # Login to open-webui using created Admin user
    my $login_json = '{"email": "' . $admin_email . '", "name": "' . $admin_username . '", "password": "' . $admin_password . '"}';
    my $login_cmd = "curl -v -k $login_url -H \"Content-Type: application/json\" -d '$login_json'";
    assert_script_run($login_cmd, fail_message => "Unable to login to open-webui using $login_cmd");
    record_info("Successfully connected to open-webui with admin credentials");
}


sub install_nvidia_drivers {
    my ($instance, $values_url, $file_name) = @_;
    my $easyinstall_url = 'https://gitlab.nue.suse.com/cloud-solutions-sys-eng/nvidia-drivers-easy-install/-/blob/main/nvidia_easy_install.sh';
    my $driver_version = '550.54.14';
    my $gpu_op_url = get_var('GPU_OPERATOR');



    record_info('Install nvidia drivers');
    script_run("curl -sSL $easyinstall_url -o ./nvidia_easy_install.sh && chmod +x ./nvidia_easy_install.sh");
    #script_run("sh ./nvidia_easy_install.sh");
    script_run("sudo zypper ar https://download.nvidia.com/suse/sle15sp6/ nvidia-sle15sp6-main");
    script_run("sudo zypper --gpg-auto-import-keys refresh");
    trup_call("pkg install -y --auto-agree-with-licenses nvidia-open-driver-G06-signed-kmp=$driver_version nvidia-compute-utils-G06=$driver_version");

    record_info('Install nvidia gpu operator');
    assert_script_run("curl -o $file_name $values_url", timeout => 120);
    #assert_script_run( "curl " . data_url("aistack/$file_name") . " -o $file_name", 60);
    assert_script_run("helm repo add $gpu_op_url", timeout => 600);
    assert_script_run("helm repo update", timeout => 600);
    assert_script_run("helm repo list", timeout => 600);
    assert_script_run("helm install gpu-operator -n gpu-operator --create-namespace nvidia/gpu-operator --set driver.enabled=false -f $file_name ", timeout => 600);

    #After reboot validate nvidia driver and gpu-operator installed
    process_reboot(trigger => 1);
    script_run("sudo nvidia-smi");
    script_run("kubectl get pods -n gpu-operator");
}

sub run {
    my ($self, $args) = @_;
    my $values_url = get_var('HELM_VALUES');
    my $ai_ns = 'suse-private-ai';
    my $value_file_name = '';

    my $instance = $self->{my_instance} = $args->{my_instance};
    my $provider = $self->{provider} = $args->{my_provider};

    # Install dependency package, config kubectl and depnedency components
    install_dependency_package($instance);
    config_kubectl($instance);
    install_dependency_components($instance);

    # choose the correct values.yaml based on the test flavor
    if (check_var('PUBLIC_CLOUD_NVIDIA_GPU_AISTACK', 1)) {
        my $gpu_values = 'nvidia_gpu_values.yaml';
        my $gpu_url = "$values_url";
        $gpu_url .= "$gpu_values";
        install_nvidia_drivers($instance, $gpu_url, $gpu_values);
        $value_file_name = 'aistack_gpu_values.yaml';
        $values_url .= "$value_file_name";
    } else {
        $values_url .= 'aistack_values.yaml';
        $value_file_name = 'aistack_values.yaml';
    }

    # Install private_ai_stack chart
    install_aistack_chart($instance, $values_url, $ai_ns, $value_file_name);

    # OpenWebUI service test
    test_openwebui_service($instance, $ai_ns);
    record_info('End of AISTACK_BASIC');
}

1;
