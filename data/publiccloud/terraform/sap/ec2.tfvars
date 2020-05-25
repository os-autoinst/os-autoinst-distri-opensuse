# Launch SLES-HAE of SLES4SAP cluster nodes

# Instance type to use for the cluster nodes
instancetype = "%MACHINE_TYPE%"

# Disk type for HANA
hana_data_disk_type = "gp2"

# Number of nodes in the cluster
ninstances = "2"

# Region where to deploy the configuration
aws_region = "%REGION%"

# SSH private key file
private_key_location = "~/.ssh/id_rsa"

# SSH public key file
public_key_location = "~/.ssh/id_rsa.pub"

# Custom AMI for nodes
hana_os_image = "%SLE_IMAGE%"
hana_os_owner = "self"

# aws-cli credentials file. Located on ~/.aws/credentials on Linux, MacOS or Unix or at C:\Users\USERNAME\.aws\credentials on Windows
aws_credentials = "/root/amazon_credentials"

# Hostname, without the domain part
name = "hana"

# S3 bucket where HANA installation master is located
hana_inst_master = "%HANA_BUCKET%"

# Local folder where HANA installation master will be downloaded from S3
hana_inst_folder = "/root/hana_inst_media/"

# Device used by node where HANA will be installed
hana_disk_device = "/dev/xvdd"

# Variable for init-nodes.tpl script. Can be all, skip-hana or skip-cluster
init_type = "all"

# Device used by the iSCSI server to provide LUNs
iscsidev = "/dev/xvdd"

# Path to a custom ssh public key to upload to the nodes
# Used for cluster communication for example
cluster_ssh_pub = "salt://hana_node/files/sshkeys/cluster.id_rsa.pub"

# Path to a custom ssh private key to upload to the nodes
# Used for cluster communication for example
cluster_ssh_key = "salt://hana_node/files/sshkeys/cluster.id_rsa"

# IP address used to configure the hana cluster floating IP. It must be in other subnet than the machines!
hana_cluster_vip = "192.168.1.10"

# Each host IP address (sequential order).
# example : host_ips = ["10.0.0.5", "10.0.1.6"]
host_ips = ["10.0.0.5", "10.0.1.6"]

# HA packages repository
ha_sap_deployment_repo = "%HA_SAP_REPO%/SLE_%SLE_VERSION%"

# Optional SUSE Customer Center Registration parameters
#reg_code = "<<REG_CODE>>"
#reg_email = "<<your email>>"
#reg_additional_modules = {
#    "sle-module-adv-systems-management/12/x86_64" = ""
#    "sle-module-containers/12/x86_64" = ""
#    "sle-ha-geo/12.4/x86_64" = "<<REG_CODE>>"
#}
reg_code = "%SCC_REGCODE_SLES4SAP%"

# To disable the provisioning process
#provisioner = ""

# Run provisioner execution in background
#background = true

# Enable the host to be monitored by exporters
monitoring_enabled = false

# IP address of the machine where Prometheus and Grafana are running
#monitoring_srv_ip = "10.0.1.2"

# QA variables

# Define if the deployement is using for testing purpose
# Disable all extra packages that do not come from the image
# Except salt-minion (for the moment) and salt formulas
# true or false
qa_mode = true

# Execute HANA Hardware Configuration Check Tool to bench filesystems
# qa_mode must be set to true for executing hwcct
# true or false (default)
#hwcct = false

# DRBD variables

drbd_enabled = true
#drbd_machine_type = "t2.xlarge"
drbd_os_image = "%SLE_IMAGE%"
drbd_os_owner = "self"
#drbd_data_disk_size = "10"
#drbd_data_disk_type = "gp2"
drbd_ips = ["10.0.4.10", "10.0.5.11"]
drbd_cluster_vip = "192.168.1.30"

# Netweaver variables

#netweaver_enabled = true
#netweaver_instancetype = "r3.8xlarge"
#netweaver_efs_performance_mode = "generalPurpose"
#netweaver_ips = ["10.0.2.7", "10.0.3.8", "10.0.2.9", "10.0.3.10"]
#netweaver_virtual_ips = ["192.168.1.20", "192.168.1.21", "192.168.1.22", "192.168.1.23"]
# Netweaver installation required folders
#netweaver_s3_bucket = "s3://path/to/your/netweaver/installation/s3bucket"
# SAP SWPM installation folder, relative to the netweaver_s3_bucket folder
#netweaver_swpm_folder     =  "your_swpm"
# Folder where needed SAR executables (sapexe, sapdbexe) are stored, relative to the netweaver_s3_bucket folder
#netweaver_sapexe_folder   =  "kernel_nw75_sar"
# Additional folders (added in start_dir.cd), relative to the netweaver_s3_bucket folder
#netweaver_additional_dvds = ["dvd1", "dvd2"]

# Pre deployment

# Enable all some pre deployment steps (disabled by default)
#pre_deployment = true
