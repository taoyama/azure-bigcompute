# CentOS-HPC

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-bigcompute-hpcscripts%2Fmaster%2Fazuredeploy.json" target="_blank">
   <img alt="Deploy to Azure" src="http://azuredeploy.net/deploybutton.png"/>
</a>

* This creates configurable number of disks with configurable size for centos-hpc A8/A9 
Creates a Cluster with configurable number of worker nodes each with prebuilt Intel MPI and Direct RDMA for each Head and corresponding compute Nodes.
* Cluster Scheduler can be ignored for now only can work with gcc docker cross compilation
Head Node is defaulted to A8 and has striped configurable disks attached.
* __These are not for DEV but with fixed kernels for Intel MPI and Direct RDMA.__
* __All Local program compiles are disabled in this template__
* No icc or gcc presence.
* GCC Cross compilation can be performed via docker as in <a href="https://hub.docker.com/_/gcc/" target="_blank>gcc docker for cross compiling on local fixed kernel</a>
* Latest Docker configurable each Head and compute Nodes. - default is 1.11 (Only for CentOS-HPC 7.1, kernel 3.10.x and above).
* Latest docker-compose configurable each Head and compute Nodes. - default is 1.7.1 (Only for CentOS-HPC 7.1, kernel 3.10.x and above).
* Latest docker-machine configurable  - default is the now latest v0.7.0 (Only for 7.1, kernel 3.10.x and above). [Docs](https://docs.docker.com/machine/drivers/azure/)
* Latest Rancher available dockerized (CentOS-HPC 7.1) @ <code>8080</code> i.e. <code>http://'DNS Name'.'location'.cloudapp.azure.com:8080 - Unauthenticated.. Authentication and agent setup is manual setup>.</code>
* Azure CLI usage is <code>docker exec -ti azure-cli bash -c "azure login && bash"</code>.
* Disk auto mounting is at /'parameter'/data.
* NFS4 is on on the above.
* Strict ssh public key enabled.
* Nodes that share public RSA key shared can be used as direct jump boxes as azureuser@DNS.
* NSG is required.
* Internal firewalld is off.
* WALinuxAgent updates are disabled on first deployment.
* Specific Logic in <code>install_packages_all()</code> to distinguish between sku for CentOS-HPC 6.5 and 7.1, primarily for docker usage.
