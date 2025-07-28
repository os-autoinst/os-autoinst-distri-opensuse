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
use utils;
use publiccloud::utils;
use transactional qw(process_reboot trup_install trup_shell);
use File::Basename;
use version_utils;
use Data::Dumper;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub install_dependency_package {
    my ($instance) = @_;
    my $rke2_url = get_var('RKE2_URL');
    my $kubectl_url = get_var('KUBECTL_URL');
    my $helm_url = get_var('HELM_URL');

    record_info('Dep pkg install');
    trup_call("pkg install curl git podman python311");

    # podman activation section
    process_reboot(trigger => 1);
    systemctl("enable podman");
    systemctl("start podman");
    systemctl("status podman");

    # rke2 activation section
    assert_script_run("curl -sSL $rke2_url -o ./install_rke2.sh && chmod 775 ./install_rke2.sh");
    assert_script_run("sh ./install_rke2.sh");
    assert_script_run("echo 'export PATH=\$PATH:/opt/rke2/bin' >> ~/.bashrc");
    assert_script_run("source ~/.bashrc");
    systemctl("enable rke2-server.service");
    systemctl("start rke2-server.service");
    systemctl("status rke2-server.service");
    assert_script_run("rke2 --version");

    # helm activation section
    assert_script_run("curl -sSL $helm_url -o ./install_helm.sh && chmod 775 ./install_helm.sh");
    assert_script_run("sh ./install_helm.sh");
    script_run("helm version");

    # kubectl activation section
    assert_script_run("curl -sSL $kubectl_url -o /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl");
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
    my ($instance, $namespace) = @_;
    my $SECRET_application_collection = get_var('_SECRET_DOCKER');
    my $SECRET_minio = get_var('_SECRET_MINIO');
    my $cert_repo = get_var('HELM_CERTS');
    my $ingress_repo = get_var('HELM_INGRESS');
    my $docker_user_name = get_var('USER_DOCKER');
    my $repo_url = get_var('HELM_CHARTS');
    my $ing_ver = get_var('ING_VERSION');
    my $local_storage_name = 'local_path_storage.yaml';
    #my $milvus_values = get_var('MILVUS_TOTEST');
    #my $ollama_values = get_var('OLLAMA_TOTEST');
    #my $openwebui_values = get_var('OPENWEBUI_TEST');
    #my $openwebui_gpu_values = get_var('OPENWEBUI_GPU_TEST');
    my $milvus_values = 'milvus_values.yaml';
    my $ollama_values = 'ollama_values.yaml';
    my $openwebui_values = 'open_webui_values.yaml';
    my $openwebui_gpu_values = 'open_webui_gpu_values.yaml';
    my $milvus_helm_repo = 'oci://dp.apps.rancher.io/charts/milvus';
    my $ollama_helm_repo = 'oci://dp.apps.rancher.io/charts/ollama';
    my $openwebui_helm_repo = 'oci://dp.apps.rancher.io/charts/open-webui';

    record_info('AISTACK charts install');
    assert_script_run("helm list --all-namespaces");
    assert_script_run("kubectl get pods --all-namespaces");

    # Access to Application collection registery
    # local-path-storage.yaml is a copy off https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
    assert_script_run("kubectl create ns $namespace");
    assert_script_run("kubectl create secret docker-registry application-collection --docker-server=dp.apps.rancher.io --docker-username='$docker_user_name' --docker-password='$SECRET_application_collection' -n $namespace", timeout => 120);
    assert_script_run("curl " . data_url("aistack/$local_storage_name") . " -o $local_storage_name", 60);
    assert_script_run("kubectl apply -f $local_storage_name", timeout => 120);

    # Install milvus
    assert_script_run("curl " . data_url("aistack/$milvus_values") . " -o $milvus_values", 60);
    assert_script_run("helm registry login dp.apps.rancher.io/charts -u $docker_user_name -p $SECRET_application_collection");
    assert_script_run("helm install milvus -f $milvus_values -n $namespace $milvus_helm_repo", timeout => 100);

    # Install Ollama
    assert_script_run("curl " . data_url("aistack/$ollama_values") . " -o $ollama_values", 60);
    assert_script_run("helm registry login dp.apps.rancher.io/charts -u $docker_user_name -p $SECRET_application_collection");
    assert_script_run("helm install ollama -f $ollama_values -n $namespace $ollama_helm_repo", timeout => 100);

    # Install open-webui
    assert_script_run("helm registry login dp.apps.rancher.io/charts -u $docker_user_name -p $SECRET_application_collection");
    if (check_var('PUBLIC_CLOUD_NVIDIA_GPU_AISTACK', 1)) {
        assert_script_run("curl " . data_url("aistack/$openwebui_gpu_values") . " -o $openwebui_gpu_values", 60);
        assert_script_run("helm install open-webui -f $openwebui_gpu_values -n $namespace $openwebui_helm_repo --set open-webui.ingress.class=nginx", timeout => 100);
    } else {
        assert_script_run("curl " . data_url("aistack/$openwebui_values") . " -o $openwebui_values", 60);
        assert_script_run("helm install open-webui -f $openwebui_values -n $namespace $openwebui_helm_repo --set open-webui.ingress.class=nginx", timeout => 100);
    }

    assert_script_run("kubectl get all --namespace $namespace");
    sleep 60;

    # Check pod status and log for successful
    # Loop thru each pod and pod status is running,error,failed,CrashLoopBackoff,ContainerStatusUnknown skip to next pod
    # any other pod status check the log for Failure,Error,Exception record the log and skip to next pod
    # if not loop thru till it reaches the max_retries to ensure the pod comes to running or failure state.
    # After reaching max_retries , record the pod details which does not run after reaching max_retries
    my $max_retries = 15;
    my @failed_pods;
    my $sleep_interval = 20;
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
                push @failed_pods, {name => $pod, status => $status};
                next POD_LOOP;
            } else {
                if ($logs =~ /ERROR|FAILURE|Exception|Failed/) {
                    record_info("$pod failed due to error in log: $logs \n ");
                    push @failed_pods, {name => $pod, status => $status};
                    next POD_LOOP;
                }    # if log
                sleep $sleep_interval;
            }    # if status
        }    # while loop
        record_info("$pod is not running after $max_retries ");
    }    # pod loop

    assert_script_run("kubectl get all --namespace $namespace");
    if (@failed_pods) {
        die "Failed pods:\n" . join("\n", map { "$_->{name}: $_->{status}" } @failed_pods) . "\n";
    }
}

sub totest_install {
    my ($instance, $namespace) = @_;

    # Get values.yaml
    assert_script_run("curl " . data_url("aistack/get_var('MILVUS_TOTEST')") . " -o " . get_var('MILVUS_TOTEST'), 60);
    assert_script_run("curl " . data_url("aistack/get_var('OLLAMA_TOTEST')") . " -o " . get_var('OLLAMA_TOTEST'), 60);
    assert_script_run("curl " . data_url("aistack/get_var('OPENWEBUI_TEST')") . " -o " . get_var('OPENWEBUI_TEST'), 60);

    # Replace tag values
    file_content_replace("get_var('MILVUS_TOTEST')", array('tag: .*' => "tag: " . get_var('MILVUS_TAG'), '--debug' => 1));
    #to handle first and last occurance to update the tag
    assert_script_run(sprintf("sed -E '0,/tag: .*/s/%s/%s/' -i %s", 'tag: .*', "tag: " . get_var('OPENWEBUI_TAG'), get_var('OPENWEBUI_TEST')));
    assert_script_run(sprintf("sed -E ':a; N; $!ba; s/%s/%s/; ta' -i %s", 'tag: .*', "tag: " . get_var('OLLAMA_TAG'), get_var('OPENWEBUI_TEST')));

    # Download tgz file
    assert_script_run("curl " . get_var('AI_TOTEST_URL') . "/charts/" . get_var('MILVUS_TGZ') . " -o " . get_var('MILVUS_TGZ'), 60);
    assert_script_run("curl " . get_var('AI_TOTEST_URL') . "/charts/" . get_var('OLLAMA_TGZ') . " -o " . get_var('OLLAMA_TGZ'), 60);
    assert_script_run("curl " . get_var('AI_TOTEST_URL') . "/charts/" . get_var('OPENWEBUI_TGZ') . " -o " . get_var('OPENWEBUI_TGZ'), 60);

    # Helm Install
    assert_script_run("helm install milvus -f " . get_var('MILVUS_TOTEST') . " -n $namespace ./" . get_var('MILVUS_TGZ'), timeout => 100);
    assert_script_run("helm install ollama -f " . get_var('OLLAMA_TOTEST') . " -n $namespace ./" . get_var('OLLAMA_TGZ'), timeout => 100);
    assert_script_run("helm install open-webui -f " . get_var('OPENWEBUI_TEST') . " -n $namespace ./" . get_var('OPENWEBUI_TGZ'), timeout => 100);

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

    # get endpoints
    assert_script_run("kubectl get endpoints $sr_name -n $namespace -o=jsonpath='{.subsets[*].addresses[*].ip}'");
    my $endpoint_cmd = "kubectl get endpoints $sr_name -n $namespace -o=jsonpath='{.subsets[*].addresses[*].ip}'";
    my $endpoint_result = script_output($endpoint_cmd);
    record_info("Endpoint code: $endpoint_result \n");
    if (!$endpoint_result) {
        die "No healthy endpoints found for the open-webui service in $namespace\n";
    } else {
        # connect open-webui service
        assert_script_run("curl --output /dev/null --silent --head --write-out \"%{http_code}\n\" -k -L https://$host_name");
        my $curl_cmd = "curl --output /dev/null --silent --head --write-out \"%{http_code}\n\" -k -L https://$host_name";
        my $curl_result = script_output($curl_cmd);
        record_info("http code: $curl_result \n");
        if ($curl_result == 200) {
            record_info("Successfully connected to the open-webui service at $curl_cmd \n");
        } else {
            die "Received unexpected HTTP error code $curl_result for $curl_cmd\n";
        }
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
    my ($instance) = @_;
    my $easyinstall_url = 'https://gitlab.nue.suse.com/cloud-solutions-sys-eng/nvidia-drivers-easy-install/-/blob/main/nvidia_easy_install.sh';
    my $driver_version = '550.54.14';
    my $gpu_op_url = get_var('GPU_OPERATOR');
    my $file_name = 'nvidia_gpu_values.yaml';

    record_info('Install nvidia drivers');
    # assert_script_run("curl -sSL $easyinstall_url -o ./nvidia_easy_install.sh && chmod +x ./nvidia_easy_install.sh");
    # script_run("sh ./nvidia_easy_install.sh");
    script_run("sudo zypper ar https://download.nvidia.com/suse/sle15sp6/ nvidia-sle15sp6-main");
    script_run("sudo zypper --gpg-auto-import-keys refresh");
    trup_call("pkg install -y --auto-agree-with-licenses nvidia-open-driver-G06-signed-kmp=$driver_version nvidia-compute-utils-G06=$driver_version");

    record_info('Install nvidia gpu operator');
    assert_script_run("curl " . data_url("aistack/$file_name") . " -o $file_name", 60);
    assert_script_run("helm repo add $gpu_op_url", timeout => 600);
    assert_script_run("helm repo update", timeout => 600);
    assert_script_run("helm repo list", timeout => 600);
    assert_script_run("helm install gpu-operator -n gpu-operator --create-namespace nvidia/gpu-operator --set driver.enabled=false -f $file_name ", timeout => 600);

    # After reboot validate nvidia driver and gpu-operator installed
    process_reboot(trigger => 1);
    script_run("sudo nvidia-smi");
    script_run("kubectl get pods -n gpu-operator");
}

sub run {
    my ($self, $args) = @_;
    my $ai_ns = 'suse-private-ai';

    my $instance = $self->{my_instance} = $args->{my_instance};
    my $provider = $self->{provider} = $args->{my_provider};

    # Install dependency package, config kubectl and depnedency components
    install_dependency_package($instance);
    config_kubectl($instance);
    install_dependency_components($instance);

    # choose the correct values.yaml based on the test flavor
    if (check_var('PUBLIC_CLOUD_NVIDIA_GPU_AISTACK', 1)) {
        install_nvidia_drivers($instance);
    }

    # Install private_ai_stack chart
    install_aistack_chart($instance, $ai_ns);

    # OpenWebUI service test
    test_openwebui_service($instance, $ai_ns);
    record_info('End of AISTACK_BASIC');
}

1;
