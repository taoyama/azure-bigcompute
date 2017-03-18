![Azure icon](https://www.microsoft.com/favicon.ico)           ![Intel icon](https://yepo.com.au/media/catalog/product/cache/1/thumbnail/128x128/9df78eab33525d08d6e5fb8d27136e95/a/h/ahr0cdovl2ltywdlcy5py2vjyxquyml6l2ltzy9nywxszxj5lzi2mje1njq5xzg2mdguanbn.jpg)           ![nvidia icon](http://img.informer.com/icons/png/128/3096/3096710.png) ![mellanoxicon](https://az846835.vo.msecnd.net/company/logos/MellanoxTechnologies.png) ![infinibandicon](https://pbs.twimg.com/profile_images/566244657/InfiniBandLG_reasonably_small.jpg) ![Ubuntu Icon](https://static.start.me/favicons/wczxq9siw9fnsc7hvy1a) ![Centos icon](https://copr.fedorainfracloud.org/static/chroot_logodir/epel.png)


[![Build Status](https://travis-ci.org/Azure/azure-bigcompute-hpcscripts.png?branch=master)](https://travis-ci.org/Azure/azure-bigcompute-hpcscripts)


Table of Contents
=================

   * [Azure Big Compute](#azure-big-compute)
   * [Deploy from Portal and visualize](#deploy-from-portal-and-visualize)
      * [Optional usage with OMS](#optional-usage-with-oms)
      * [Reporting bugs](#reporting-bugs)
      * [Patches and pull requests](#patches-and-pull-requests)
      * [Region availability and Quotas for MS Azure Skus](#region-availability-and-quotas-for-ms-azure-skus)
   * [Topology Examples with Azure CLI](#topology-examples-with-azure-cli)
      * [New Azure CLI](#new-azure-cli)
      * [Old Azure CLI](#old-azure-cli)
   * [GPUs for Compute](#gpus-for-compute)
   * [H-Series and A9 with schedulers](#h-series-and-A9-with-schedulers)
      * [mpirun](#mpirun)
      * [IB](#ib)
      * [Torque and pbspro for CentOS-HPC Skus](#torque-and-pbspro-for-centos-hpc-skus)


# Azure Big Compute

**[Azure Big Compute](https://azure.microsoft.com/en-us/solutions/big-compute/)**


Please see the [LICENSE file](https://github.com/Azure/azure-bigcompute-hpcscripts/blob/master/LICENSE) for licensing information.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information
see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional
questions or comments.

**This repo is inspired by [Christian Smith](https://github.com/smith1511)'s repo https://github.com/smith1511/hpc**

# Deploy from Portal and visualize

<a href="https://preview.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-bigcompute-hpcscripts%2Fmaster%2Fazuredeploy.json" target="_blank">
   <img alt="Deploy to Azure" src="http://azuredeploy.net/deploybutton.png"/>
</a>

<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-bigcompute-hpcscripts%2Fmaster%2Fazuredeploy.json" target="_blank">  
<img src="http://armviz.io/visualizebutton.png"/> </a> 

For portal Deployment, the following pic might assist.

![azureportaldeploy](https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azurebigcompute.png)

This project is hosted at:

  * https://github.com/Azure/azure-bigcompute-hpcscripts

For the latest version, to contribute, and for more information, please go through [this README.md](https://github.com/Azure/azure-bigcompute-hpcscripts/blob/master/README.md).

To clone the current master (development) branch run:

```
git clone git://github.com/Azure/azure-bigcompute-hpcscripts.git
```


## Optional usage with OMS

**OMS Setup is optional and the OMS Workspace Id and OMS Workspace Key can either be kept blank or populated post the steps below.**

[Create a free account for MS Azure Operational Management Suite with workspaceName](https://login.mms.microsoft.com/signin.aspx?signUp=on&ref=ms_mms)
* Provide a Name for the OMS Workspace.
* Link your Subscription to the OMS Portal.
* Depending upon the region, a Resource Group would be created in the Sunscription like 'mms-weu' for 'West Europe' and the named OMS Workspace with portal details etc. would be created in the Resource Group.
* Logon to the OMS Workspace and Go to -> Settings -> 'Connected Sources'  -> 'Linux Servers' -> Obtain the Workspace ID like <code>ba1e3f33-648d-40a1-9c70-3d8920834669</code> and the 'Primary and/or Secondary Key' like <code>xkifyDr2s4L964a/Skq58ItA/M1aMnmumxmgdYliYcC2IPHBPphJgmPQrKsukSXGWtbrgkV2j1nHmU0j8I8vVQ==</code>
* Add The solutions 'Agent Health', 'Activity Log Analytics' and 'Container' Solutions from the 'Solutions Gallery' of the OMS Portal of the workspace.
* While Deploying the Template just the WorkspaceID and the Key are to be mentioned and all will be registered including all containers in any nodes of the cluster(s).
* Then one can login to https://OMSWorkspaceName.portal.mms.microsoft.com and check all containers running for Docker DataCenter and use Log Analytics and if Required perform automated backups using the corresponding Solutions for OMS.
 * Or if the OMS Workspace and the Machines are in the same subscription, one can just connect the Linux Node sources manually to the OMS Workspace as Data Sources.
 
## Reporting bugs

Please report bugs  by opening an issue in the [GitHub Issue Tracker](https://github.com/Azure/azure-bigcompute-hpcscripts/issues)

## Patches and pull requests

Patches can be submitted as GitHub pull requests. If using GitHub please make sure your branch applies to the current master as a 'fast forward' merge (i.e. without creating a merge commit). Use the `git rebase` command to update your branch to the current master if necessary.

## Region availability and Quotas for MS Azure Skus

* Sku availability per region is [here](https://azure.microsoft.com/en-us/regions/services/#).
* Please see this [link](https://blogs.msdn.microsoft.com/girishp/2015/09/20/increasing-core-quota-limits-in-azure/) for instructions on requesting a core quota increase.
* For more information on Azure subscription and service limits, quota, and constraints, please see [here](https://azure.microsoft.com/en-us/documentation/articles/azure-subscription-service-limits/).


## Topology Examples with Azure CLI


### New Azure CLI


<code>docker run -dti --restart=always --name=azure-cli-python azuresdk/azure-cli-python && docker exec -ti azure-cli-python bash -c "az login && bash"</code>

<code>To sign in, use a web browser to open the page https://aka.ms/devicelogin and enter the code XXXXXXXXX to authenticate.</code>


* GPU Cluster (each NC24) with no scheduler and no OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below]:

<code>bash-4.3# az group create -l eastus -n tstgpu4computes && az group deployment create -g tstgpu4computes -n tstgpu4computes --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json --parameters "{\"dnsLabelPrefix\":{\"value\":\"tstgpu4computes\"},\"adminUserName\":{\"value\":\"azuregpuuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"Canonical\"},\"imageOffer\":{\"value\":\"UbuntuServer\"},\"imageSku\":{\"value\":\"16.04.0-LTS\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_NC24\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"}}"</code>


* GPU Cluster (each NC24) with no scheduler with OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below along with OMSWorkSpaceId and OMSWorkSpaceKey]:

<code> bash-4.3# az group create -l eastus -n tstgpu4computes && az group deployment create -g tstgpu4computes -n tstgpu4computes --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json --parameters "{\"dnsLabelPrefix\":{\"value\":\"tstgpu4computes\"},\"adminUserName\":{\"value\":\"azuregpuuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"Canonical\"},\"imageOffer\":{\"value\":\"UbuntuServer\"},\"imageSku\":{\"value\":\"16.04.0-LTS\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_NC24\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"},\"OMSWorkSpaceId\":{\"value\": \"xxxxxxxxxx\"},\"OMSWorkSpaceKey\":{\"value\": \"xxxxxxxxx\"}}"</code>

* HPC Cluster (each H16R) with PBSPro and no OMS - minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below]:

<code>bash-4.3# az group create -l southcentralus -n tsthpc && az group deployment create -g tsthpc -n tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json --parameters "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"pbspro\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"}}"</code>

* HPC Cluster (each H16R) with PBSPro with OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below along with OMSWorkSpaceId and OMSWorkSpaceKey]:

<code>bash-4.3# az group create -l southcentralus -n tsthpc && az group deployment create -g tsthpc -n tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json --parameters "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"pbspro\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"},\"OMSWorkSpaceId\":{\"value\": \"xxxxxxxxxx\"},\"OMSWorkSpaceKey\":{\"value\": \"xxxxxxxxx\"}}"</code>

* HPC (each H16R) Cluster with Torque and no OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below]:

<code>bash-4.3# az group create -l southcentralus -n tsthpc && az group deployment create -g tsthpc -n tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json --parameters "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"Torque\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"}}"</code>


* HPC (each H16R) Cluster with Torque with OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below along with OMSWorkSpaceId and OMSWorkSpaceKey]:

<code>bash-4.3# az group create -l southcentralus -n tsthpc && az group deployment create -g tsthpc -n tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json --parameters "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"Torque\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"},\"OMSWorkSpaceId\":{\"value\": \"xxxxxxxxxx\"},\"OMSWorkSpaceKey\":{\"value\": \"xxxxxxxxx\"}}"</code>


### Old Azure CLI

<code>docker run -dti --restart=always --name=azure-cli microsoft/azure-cli && docker exec -ti azure-cli bash -c "azure login && bash"</code>


<code>To sign in, use a web browser to open the page https://aka.ms/devicelogin and enter the code XXXXXXXXX to authenticate.</code>

* GPU Cluster (each NC24) with no scheduler and no OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below]:

<code>bash-4.3# azure group create tstgpu4computes "eastus"  && azure group deployment create tstgpu4computes tstgpu4computes --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json -p "{\"dnsLabelPrefix\":{\"value\":\"tstgpu4computes\"},\"adminUserName\":{\"value\":\"azuregpuuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"Canonical\"},\"imageOffer\":{\"value\":\"UbuntuServer\"},\"imageSku\":{\"value\":\"16.04.0-LTS\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_NC24\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"}}"</code>

* GPU Cluster (each NC24) with no scheduler with OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below along with OMSWorkSpaceId and OMSWorkSpaceKey]:

<code>bash-4.3# azure group create tstgpu4computes "eastus"  && azure group deployment create tstgpu4computes tstgpu4computes --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json -p "{\"dnsLabelPrefix\":{\"value\":\"tstgpu4computes\"},\"adminUserName\":{\"value\":\"azuregpuuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"Canonical\"},\"imageOffer\":{\"value\":\"UbuntuServer\"},\"imageSku\":{\"value\":\"16.04.0-LTS\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_NC24\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"},\"OMSWorkSpaceId\":{\"value\": \"xxxxxxxxxx\"},\"OMSWorkSpaceKey\":{\"value\": \"xxxxxxxxx\"}}"</code>

* HPC Cluster (each H16R) with PBSPro and no OMS - minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below]:

<code>bash-4.3# azure group create tsthpc "southcentralus"  && azure group deployment create tsthpc tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json -p "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"pbspro\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"}}"</code>

* HPC Cluster (each H16R) with PBSPro with OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below along with OMSWorkSpaceId and OMSWorkSpaceKey]:

<code>bash-4.3# azure group create tsthpc "southcentralus"  && azure group deployment create tsthpc tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json -p "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"pbspro\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"},\"OMSWorkSpaceId\":{\"value\": \"xxxxxxxxxx\"},\"OMSWorkSpaceKey\":{\"value\": \"xxxxxxxxx\"}}"</code>

* HPC (each H16R) Cluster with Torque with OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below along with OMSWorkSpaceId and OMSWorkSpaceKey]:

<code>bash-4.3# azure group create tsthpc "southcentralus"  && azure group deployment create tsthpc tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json -p "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"Torque\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"}}"</code>

* HPC (each H16R) Cluster with Torque with OMS- minimum 1 head and minimum 1 worker [provided sshpublickey value is supplied below along with OMSWorkSpaceId and OMSWorkSpaceKey]:

<code>bash-4.3# azure group create tsthpc "southcentralus"  && azure group deployment create tsthpc tsthpc --template-uri https://raw.githubusercontent.com/Azure/azure-bigcompute-hpcscripts/master/azuredeploy.json -p "{\"dnsLabelPrefix\":{\"value\":\"tsthpc\"},\"adminUserName\":{\"value\":\"azurehpcuser\"},\"sshPublicKey\":{\"value\":\"\"},\"imagePublisher\":{\"value\":\"openlogic\"},\"imageOffer\":{\"value\":\"CentOS-HPC\"},\"imageSku\":{\"value\":\"7.1\"},\"schedulerpbsORTorque\":{\"value\":\"Torque\"},\"headandWorkerNodeSize\":{\"value\":\"Standard_H16R\"},\"workerNodeCount\":{\"value\": 1},\"numDataDisks\":{\"value\":\"32\"},\"OMSWorkSpaceId\":{\"value\": \"xxxxxxxxxx\"},\"OMSWorkSpaceKey\":{\"value\": \"xxxxxxxxx\"}}"</code>


## GPUs for Compute

[Azure GPUs](http://gpu.azure.com/)

* Entry point is valid for the stated sku presently only for  specific regions of "East-US" or "Southcentral-US". Sku availability per region is [here](https://azure.microsoft.com/en-us/regions/services/#).
* gpu enablement is possible only on approval of quota for sku usage in the stated subscription. Please see this [link](https://blogs.msdn.microsoft.com/girishp/2015/09/20/increasing-core-quota-limits-in-azure/) for instructions on requesting a core quota increase. 
* NVDIA drivers are auto-loaded for Ubuntu 16.04-LTS.
* Latest Secure Install of CUDA available and on RAID0 (/data/data default).
* One can run all [CUDA Samples](http://developer.download.nvidia.com/compute/cuda/1.1-Beta/x86_website/samples.html) across the cluster and test with latest CUDA and CUDAnn.
* Latest Docker CE both for Ubuntu and CentOS configurable each Head and all compute Nodes. - default is 17.03 CE.
* Latest docker-compose configurable each Head and compute Nodes. 
* Latest docker-machine configurable.
* Latest new and old azure cli are in both Head and Compute nodes.
* Disk auto mounting is at /'parameter'/data.
* NFS4 is on.
* Strict ssh public key enabled.
* Nodes that share public RSA key shared can be used as direct jump boxes as <code>azureuser@DNS</code>.
* Head and comp nodes work via <code>sudo su - --hpc user-- </code> and then direct ssh.
* Internal firewall is off.
* For M60 usage for visualizations, please visit [aka.ms/accessgpu](https://aka.ms/accessgpu)


## H-Series and A9 with schedulers 
 
* [Simulations with Azure Big Compute](https://simulation.azure.com/)

* H-Series Skus added
 * **[H-Series Blog](https://azure.microsoft.com/en-us/blog/availability-of-h-series-vms-in-microsoft-azure/)**

**Details**
* Entry point is valid for the stated sku presently for specific regions. Sku availability per region is [here](https://azure.microsoft.com/en-us/regions/services/#).
* Default quota is always 8 cores per region and it is possible to request quotas for the stated subscription. Please see this [link](https://blogs.msdn.microsoft.com/girishp/2015/09/20/increasing-core-quota-limits-in-azure/) for instructions on requesting a core quota increase. 
* This creates configurable number of disks with configurable size for centos-hpc A9/H16R/H16MR
Creates a Cluster with configurable number of worker nodes each with prebuilt Intel MPI and Direct RDMA for each Head and corresponding compute Nodes.
   * For CentOS-HPC imageOffer for skuName(s) are 7.1
   * Cluster Scheduler can be Torque or PBSPro.
   * __Only Intel MPI__.
   * Latest Docker CE both for Ubuntu and CentOS configurable each Head and all compute Nodes. - default is 17.03 CE.
   * Latest docker-compose configurable each Head and compute Nodes. 
   * Latest docker-machine configurable.
   * Latest new and old azure cli are in both Head and Compute nodes.
   * Disk auto mounting is at /'parameter'/data.
   * NFS4 is on.
   * Strict ssh public key enabled.
   * Nodes that share public RSA key shared can be used as direct jump boxes as <code>azureuser@DNS</code>.
   * Head and comp nodes work via <code>sudo su - --hpc user--</code> and then direct ssh.
   * msft drivers check via rpm -qa msft* or rpm -qa microsoft*
   * Internal firewalld is off.
   * WALinuxAgent disabling and manual workrounds required **ONLY for NC24R- CentOS 7.3**, presently.

### mpirun

All path are set automatically for key 'default' provided users like azureuser/hpc.
for root specific <code>su - root</code> is required.

<code>source /opt/intel/impi/5.1.3.181/bin64/mpivars.sh</code>

<code>mpirun -ppn 1 -n 2 -hosts headN,compn0 -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 hostname</code>  (Cluster Check)

<code>mpirun -hosts headN,compn0 -ppn --processes per node in number-- -n --number of consequtive processes-- -env I_MPI_FABRICS=dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 IMB-MPI1 pingpong</code>
(Base Pingpong stats)



### IB

<code>ls /sys/class/infiniband</code>

<code>cat /sys/class/infiniband/mlx4_0/ports/1/state</code>

<code>/etc/init.d/opensmd start</code> (if required)

<code>cat /sys/class/infiniband/mlx4_0/ports/1/rate</code>



### Torque and pbspro for CentOS-HPC Skus

**All computes would have automatic pbs_mom and head the pbs_mom and pbs_server for latest Torque or Pbspro from their respective master repos made from source during cluster provision time**. No post installation tasks are required post successful cluster deployment except if np is to be increased from 1.

check for Torque or PBSPro via
<code>pbsnodes -a</code>
* [Torque 6.1.0](http://www.adaptivecomputing.com/support/download-center/torque-download/)
* [PBS Pro Master 4.0.1](https://github.com/PBSPro/pbspro/)
  * [PBS Pro Open Source License Information](https://github.com/PBSPro/pbspro/blob/6733daa7c24ca65c2975908d930d43b18f21caec/src/cmds/scripts/pbs_server#L8-L35)
  * [AGPL](https://www.gnu.org/licenses/agpl-3.0.en.html)

All path are set automatically for key 'default' users like azureuser/hpc/root
for root specific <code>su - root</code> is required.

