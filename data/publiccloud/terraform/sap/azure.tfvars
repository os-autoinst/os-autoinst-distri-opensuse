# Launch SLES-HAE of SLES4SAP cluster nodes

# Instance type to use for the cluster nodes
instancetype = "%MACHINE_TYPE%"

# Disk type for HANA
hana_data_disk_type = "StandardSSD_LRS"

# Caching used for HANA disk
hana_data_disk_caching = "ReadWrite"

# Number of nodes in the cluster
ninstances = "2"

# Region where to deploy the configuration
az_region = "%REGION%"

# Installation type
# Value can be all, skip-hana, skip-cluster
init_type = "all"

# SLES4SAP image information
# If custom uris are enabled public information will be omitted
# Custom sles4sap image
sles4sap_uri = "https://openqa.blob.core.windows.net/sle-images/%SLE_IMAGE%"

# Custom iscsi server image
# iscsi_srv_uri = "/path/to/your/iscsi/image"

# Public SLES4SAP image
hana_public_sku     = "15"
hana_public_version = "latest"

# Public iscsi server image
iscsi_public_sku     = "15"
iscsi_public_version = "latest"

# Admin user
admin_user = "ldevulder"

# Private SSH Key location
private_key_location = "~/.ssh/id_rsa"

# SSH public key file
public_key_location = "~/.ssh/id_rsa.pub"

# Azure storage account name
storage_account_name = "%STORAGE_ACCOUNT_NAME%"

# Azure storage account secret key (key1 or key2)
storage_account_key = "%STORAGE_ACCOUNT_KEY%"

# Azure storage account path where HANA installation master is located
hana_inst_master = "%HANA_BUCKET%"

# Local folder where HANA installation master will be mounted
hana_inst_folder = "/root/sap_inst/"

# Device used by node where HANA will be installed
hana_disk_device = "/dev/sdc"

# Device used by the iSCSI server to provide LUNs
iscsidev = "/dev/sdc"

# Path to a custom ssh public key to upload to the nodes
# Used for cluster communication for example
cluster_ssh_pub = "salt://hana_node/files/sshkeys/cluster.id_rsa.pub"

# Path to a custom ssh private key to upload to the nodes
# Used for cluster communication for example
cluster_ssh_key = "salt://hana_node/files/sshkeys/cluster.id_rsa"

# Each host IP address (sequential order).
# example : host_ips = ["10.0.1.0", "10.0.1.1"]
host_ips = ["10.74.1.11", "10.74.1.12"]

# Repository url used to install HA/SAP deployment packages
# The latest RPM packages can be found at:
# https://download.opensuse.org/repositories/network:/ha-clustering:/Factory/{YOUR OS VERSION}
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

# Cost optimized scenario
#scenario_type: "cost-optimized"

# To disable the provisioning process
#provisioner = ""

# Run provisioner execution in background
#background = "true"

# Monitoring variables

# Enable the host to be monitored by exporters
monitoring_enabled = "false"

# IP address of the machine where prometheus and grafana are running
#monitoring_srv_ip = "10.74.1.13"

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
