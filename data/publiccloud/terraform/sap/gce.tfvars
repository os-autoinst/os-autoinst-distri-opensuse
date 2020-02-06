# Launch SLES-HAE of SLES4SAP cluster nodes

# Project name in GCP
project = "suse-css-qa"

# Credentials file for GCP
gcp_credentials_file = "/root/google_credentials.json"

# Internal IPv4 range
ip_cidr_range = "10.0.0.0/24"

# IP for iSCSI server
iscsi_ip = "10.0.0.253"

# Type of VM (vCPUs and RAM)
machine_type = "%MACHINE_TYPE%"
machine_type_iscsi_server = "custom-1-2048"

# Disk type for HANA
hana_data_disk_type = "pd-ssd"

# SSH private key file
private_key_location = "~/.ssh/id_rsa"

# SSH public key file
public_key_location = "~/.ssh/id_rsa.pub"

# Region where to deploy the configuration
region = "%REGION%"

# Variable for init-nodes.tpl script. Can be all, skip-hana or skip-all
init_type = "all"

# The name of the GCP storage bucket in your project that contains the SAP HANA installation files
sap_hana_deployment_bucket = "%HANA_BUCKET%"

# Custom sles4sap image
sles4sap_os_image_file = "%SLE_IMAGE%"

# Device used by the iSCSI server to provide LUNs
iscsidev = "/dev/sdb"

# Path to a custom ssh public key to upload to the nodes
# Used for cluster communication for example
cluster_ssh_pub = "salt://hana_node/files/sshkeys/cluster.id_rsa.pub"

# Path to a custom ssh private key to upload to the nodes
# Used for cluster communication for example
cluster_ssh_key = "salt://hana_node/files/sshkeys/cluster.id_rsa"

# Each host IP address (sequential order).
# example : host_ips = ["10.0.0.2", "10.0.0.3"]
host_ips = ["10.0.0.2", "10.0.0.3"]

# Local folder where HANA installation master will be mounted
hana_inst_folder = "/root/sap_inst/"

# Device used by node where HANA will be installed
hana_disk_device = "/dev/sdb"

# Device used by node where HANA will be downloaded
hana_inst_disk_device = "/dev/sdc"

# HA packages Repository
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
#monitoring_srv_ip = "10.0.0.4"

# QA variables

# Define if the deployment is using for testing purpose
# Disable all extra packages that do not come from the image
# Except salt-minion (for the moment) and salt formulas
# true or false
qa_mode = "true"

# Execute HANA Hardware Configuration Check Tool to bench filesystems
# qa_mode must be set to true for executing hwcct
# true or false (default)
#hwcct = false
