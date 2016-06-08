 [![Build Status](https://travis-ci.org/Azure/azure-bigcompute-hpcscripts.png?branch=master)](https://travis-ci.org/Azure/azure-bigcompute-hpcscripts)

# CentOS-HPC
Based on https://github.com/smith1511/hpc with additions of CentOS-HPC Image offers (fixed kernels), dynamic disk stripping ssh password, docker enabling, docker cross compiling. Fixed Kernel Swiss Knife Pureplay Azure HPC Cluster with Direct RDMA and Intel MPI
* Status: __WIP__

   *  General Cleanup
   *  More cleanup
   *  Intel Lustre Client with options of Lustre PFS Creation on Azure.
   *  Scheduler Choce: SLURM or Torque
   *  Proper Docker Cross Compile Entry Point for target Intel
   *  DEV/Test Lab for optimized Comp Node usage with formulas and CI  for custom VHDs
   *  VMSS (maybe? )

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-bigcompute-hpcscripts%2Fmaster%2Fazuredeploy.json" target="_blank">
   <img alt="Deploy to Azure" src="http://azuredeploy.net/deploybutton.png"/>
</a>

* This creates configurable number of disks with configurable size for centos-hpc A8/A9 
Creates a Cluster with configurable number of worker nodes each with prebuilt Intel MPI and Direct RDMA for each Head and corresponding compute Nodes.
   * For CentOS-HPC imageOffer for skuName(s) 6.5 and 7.1
   * Cluster Scheduler can be ignored for now and Torque and SLURM options to be put in __WIP__
   * Head Node is defaulted to A8 and has striped configurable disks attached.
   * Specific Logic in <code>install_packages_all()</code> to distinguish between sku for CentOS-HPC 6.5 and 7.1, primarily for docker usage.
* __These are not for DEV but with fixed kernels for Intel MPI and Direct RDMA.__
* __All Local program compiles are disabled in this template__
* __No icc or gcc presence.__
   * GCC Cross compilation can be performed via docker as in <a href="https://hub.docker.com/_/gcc/" target="_blank>__gcc docker for cross compiling on local fixed kernel__</a>
   * Latest Docker configurable each Head and compute Nodes. - default is 1.11 (Only for CentOS-HPC 7.1, kernel 3.10.x and above).
   * Latest docker-compose configurable each Head and compute Nodes. - default is 1.7.1 (Only for CentOS-HPC 7.1, kernel 3.10.x and above).
   * Latest docker-machine configurable  - default is the now latest v0.7.0 (Only for 7.1, kernel 3.10.x and above). [Docs](https://docs.docker.com/machine/drivers/azure/)
   * Latest Rancher available dockerized (CentOS-HPC 7.1) @ <code>8080</code> i.e. <code>http://'DNS Name'.'location'.cloudapp.azure.com:8080 - Unauthenticated.. Authentication and agent setup is manual setup>.</code>
   * Azure CLI usage is <code>docker exec -ti azure-cli bash -c "azure login && bash"</code>.
   * First testing of using official gcc docker image on src in container with shared dir with node fs in <code>install_munge</code> experimental builds.. (See below)
* Disk auto mounting is at /'parameter'/data.
* NFS4 is on on the above.
* Strict ssh public key enabled.
* Nodes that share public RSA key shared can be used as direct jump boxes as <code>azureuser@DNS</code>.
* Head and comp nodes work via <code>sudo su - <<hpc user>></code> and then direct ssh.
* NSG is required . __WIP__
* msft drivers check via rpm -qa msft* or rpm -qa microsoft*
* Internal firewalld is off.
* WALinuxAgent updates are disabled on first deployment.

## mpirun

<code>source /opt/intel/impi/5.1.3.181/bin64/mpivars.sh</code>

<code>mpirun -ppn 1 -n 2 -hosts compn0,compn1 -env I_MPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 hostname</code>  (Cluster Check)

<code>mpirun -hosts compn0,compn1 -ppn <<processes per node in number>> -n <<number of consequtive processes>> -env I_MPI_FABRICS=dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 IMB-MPI1 pingpong</code>
(Base Pingpong stats)

## Docker Cross Compiling (e.g:)

<code>cd /data/data</code>

<code>mkdir -m 755 /data/data/mungebuild</code>

<code>wget https://github.com/dun/munge/archive/munge-0.5.12.tar.gz</code>

<code>tar xvfz munge-0.5.12.tar.gz</code>

<code>cd munge-munge-0.5.12</code>

<code>docker run --rm -it -v /data/data/munge-munge-0.5.12:/usr/src/munge:rw -v /data/data/mungebuild:/usr/src/mungebuild:rw -v /usr/lib64:/usr/src/lib64:rw  -v /etc:/etc:rw -v /var:/var:rw -v /usr:/opt:rw  gcc:5.1 bash -c "cd /usr/src/munge && ./configure -libdir=/opt/lib64 --prefix=/opt --sysconfdir=/etc --localstatedir=/var && make && make install"</code>

## IB

<code>ls /sys/class/infiniband</code>

<code>cat /sys/class/infiniband/mlx4_0/ports/1/state</code>

<code>/etc/init.d/opensmd start</code> (if required)

<code>cat /sys/class/infiniband/mlx4_0/ports/1/rate</code>

<code>pdsh –a cat /sys/class/infiniband/mlx4_0/ports/1/rate</code> (on comp nodes)
