use base "consoletest";
use testapi;
use utils 'zypper_call';
use strict;
use warnings;
use version_utils 'is_sle';
use utils;
use Utils::Architectures;
use repo_tools 'generate_version'; 
use utils 'clear_console';
use serial_terminal 'select_serial_terminal';
sub run {
    
    select_console 'root-console';	
    
    # setup repositories 
    zypper_call 'ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/Velociraptor/SLE_15_SP4/ sensor';
    zypper_call 'ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-15:/Update/standard/ sle15update';
    zypper_call 'ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-15-SP4:/Update/standard/ sle15SP4update';
    zypper_call 'ar -p 90 -f --no-gpgcheck http://download.suse.de/ibs/SUSE:/SLE-15-SP1:/Update/standard/ sle15SP1update';
    #if (is_sle) {
    #   if (is_sle('>=15')) {
    #        zypper_call("ar -f --no-gpgcheck " "http://download.suse.de/ibs/SUSE:/Velociraptor/");
    #    }
    #    elsif (is_sle('>=12-SP4') and get_var('REPO_SLES_SOURCE')) {
    #        zypper_call("ar -f --no-gpgcheck " "http://download.suse.de/ibs/SUSE:/Velociraptor/" . get_var('REPO_SLES_SOURCE') . " repo-source");
    #    }
    #    elsif (is_sle('>=12-SP4') and get_var('REPO_SLES_POOL_SOURCE')) {
    #zypper_call("ar -f --no-gpgcheck " "http://download.suse.de/ibs/SUSE:/Velociraptor/" . get_var('REPO_SLES_POOL_SOURCE') . " repo-source");
	    #}
	#else {
		#record_info('No repo', 'Missing source repository');
	    #die('Missing source repository');
	    #}
	# }




    # create config dir to run server container
    assert_script_run 'cd /root';
    assert_script_run 'mkdir -p vrr/config vrr/data vrr/logs vrr/definitions';
    
    #install podman and required dependencies 
    zypper_call 'in cni';
    zypper_call 'in podman';

    #run server as container
    assert_script_run 'podman ps';
    assert_script_run 'podman run -d --rm     --name vrr     -v /root/vrr/data:/data:Z     -v /root/vrr/config:/config:Z     -v /root/vrr/logs:/logs:Z     -v /root/vrr/definitions:/definitions:Z     -p 8001:8001     -p 8889:8889     -p 8000:8000     -p 8003:8003     registry.opensuse.org/security/sensor/containers/linux-security-sensor';
    assert_script_run 'sleep 10';
    assert_script_run 'podman ps';
    
    #velociraptor client install
    zypper_call 'se velociraptor-client';
    zypper_call 'in velociraptor-client';

    #velociraptor service start
    systemctl 'enable velociraptor-client';
    systemctl 'is-enabled velociraptor-client';
    
    #copy config files
    assert_script_run 'cp /root/vrr/config/client.conf  /etc/velociraptor/client.config';
    assert_script_run 'sed -i "s/sensor-frontend/localhost/g" /etc/velociraptor/client.config';
    
    #start client
    systemctl 'start velociraptor-client';
    systemctl 'status velociraptor-client';

    #check service runing
    assert_script_run 'curl --insecure --user admin:admin https://localhost:8889/app/index.html';
    # check client connected to server 
    #assert_script_run 'systemctl status velociraptor-client | grep "Sender: Connected to https://localhost:8000/control"'
    #generate server api config
    assert_script_run 'sed -i "s/sensor-frontend/localhost/g" vrr/config/server.conf';
    assert_script_run 'velociraptor --config vrr/config/server.conf config api_client --name admin --role administrator api.config.yaml';
    # get client info from server
    assert_script_run 'velociraptor-client --api_config ~/api.config.yaml query "SELECT * FROM info()"';

    #get client id
    assert_script_run 'clientid=velociraptor-client --api_config api.config.yaml query \'SELECT *, os_info.hostname as Hostname, client_id FROM clients() where labels =~ "client1"\' | grep -oP \'"client_id": "\K.*(?=")\'';
    #assert_script_run 'clientid=velociraptor-client --api_config api.config.yaml query \'SELECT *, os_info.hostname as Hostname, client_id FROM clients() where labels =~ "client1"\' | grep -oP \'"client_id": "\K.*(?=")\'' ;

    #create artifact directory
    assert_script_run 'mkdir /root/artifacts';
    assert_script_run 'velociraptor-client --api_config api.config.yaml query \'SELECT add_client_monitoring(artifact="SUSE.Linux.Events.ExecutableFiles", label="execfiles") FROM scope()\'';
    # wait for event sto be collected
    assert_script_run 'sleep 30';
    assert_script_run 'mkdir /root/artifacts';
    # generetae client events sarqel random anunnerov filer
    assert_script_run 'name=$(date +"%m_%d_%Y") | echo "Client Event exec" >> /home/$name.sh';
    assert_script_run 'chmod +x /home/$name.sh';
    assert_script_run 'ls /home/';
    # check for collected event on server
    assert_script_run 'ls /vrr/data/clients/$client';
    assert_script_run 'grep -r -i $name * vrr/data/clients/$clientid/ > collected.json';
    assert_script_run 'cat collected.json';

}
sub test_flags {
    return {fatal => 1};
}


1;

