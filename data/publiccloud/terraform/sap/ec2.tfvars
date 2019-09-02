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
sles4sap = {
    "%REGION%" = "%SLE_IMAGE%"
}

# aws-cli credentials file. Located on ~/.aws/credentials on Linux, MacOS or Unix or at C:\Users\USERNAME\.aws\credentials on Windows
aws_credentials = "/root/amazon_credentials"

# Hostname, without the domain part
name = "hana"

# S3 bucket where HANA installation master is located
hana_inst_master = "%HANA_BUCKET%"

# Local folder where HANA installation master will be downloaded from S3
hana_inst_folder = "/root/sap_inst/"

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

# Each host IP address (sequential order).
# example : host_ips = ["10.0.1.0", "10.0.1.1"]
host_ips = ["10.0.1.0", "10.0.1.1"]

# Repository url used to install install HA/SAP deployment packages (OS version must be ommited)"
# Contains the salt formulas
ha_sap_deployment_repo = "https://download.opensuse.org/repositories/network:/ha-clustering:/Factory/SLE_%SLE_VERSION%"

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
#background = "true"

# Enable the host to be monitored by exporters
monitoring_enabled = "false"

# IP address of the machine where Prometheus and Grafana are running
#monitoring_srv_ip = "10.0.1.2"

# QA variables

# Define if the deployement is using for testing purpose
# Disable all extra packages that do not come from the image
# Except salt-minion (for the moment) and salt formulas
# true or false
qa_mode = "true"

# Execute HANA Hardware Configuration Check Tool to bench filesystems
# qa_mode must be set to true for executing hwcct
# true or false (default)
#hwcct = false
