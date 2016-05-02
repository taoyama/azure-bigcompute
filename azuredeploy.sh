#!/bin/bash

set -x
#set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# != 8 ]; then
    echo "Usage: $0 <MasterHostname> <WorkerHostnamePrefix> <WorkerNodeCount> <HPCUserName> <TemplateBaseUrl> <sharedFolder> <MUNGE_VER> <SLURM_VER> <numDataDisks>"
    exit 1
fi

# Set user args
MASTER_HOSTNAME=$1
WORKER_HOSTNAME_PREFIX=$2
WORKER_COUNT=$3
TEMPLATE_BASE_URL="$5"
LAST_WORKER_INDEX=$(($WORKER_COUNT - 1))

# Shares
MNT_POINT="$6"
SHARE_HOME=$MNT_POINT/home
SHARE_DATA=$MNT_POINT/data

# Munged
MUNGE_USER=munge
MUNGE_GROUP=munge
MUNGE_VERSION="$7"

# SLURM
SLURM_USER=slurm
SLURM_UID=6006
SLURM_GROUP=slurm
SLURM_GID=6006
SLURM_VERSION="$8"
SLURM_CONF_DIR=$SHARE_DATA/conf

# Hpc User
HPC_USER=$4
HPC_UID=7007
HPC_GROUP=hpc
HPC_GID=7007


# Returns 0 if this node is the master node.
#
is_master()
{
    hostname | grep "$MASTER_HOSTNAME"
    return $?
}


# Installs all required packages.
#
install_pkgs()
{
    rpm --rebuilddb
    updatedb
    yum clean all
    yum -y install epel-release
    yum -x 'intel-*' -x 'kernel*' -y update
    yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs gcc gcc-c++ nfs-utils rpcbind git libicu libicu-devel make wget zip unzip mdadm wget
    wget -qO- "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e" 
    rpm --import "https://pgp.mit.edu/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e"
    yum install -y yum-utils
    yum-config-manager --add-repo https://packages.docker.com/1.10/yum/repo/main/centos/7
    yum install -y docker-engine 
    systemctl stop firewalld
    systemctl disable firewalld
    service docker start
    wget https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.6.2.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    #yum install -y binutils.x86_64 compat-libcap1.x86_64 gcc.x86_64 gcc-c++.x86_64 glibc.i686 glibc.x86_64 \
    #glibc-devel.i686 glibc-devel.x86_64 ksh compat-libstdc++-33 libaio.i686 libaio.x86_64 libaio-devel.i686 libaio-devel.x86_64 \
    #libgcc.i686 libgcc.x86_64 libstdc++.i686 libstdc++.x86_64 libstdc++-devel.i686 libstdc++-devel.x86_64 libXi.i686 libXi.x86_64 \
    #libXtst.i686 libXtst.x86_64 make.x86_64 sysstat.x86_64
    curl -L https://github.com/docker/compose/releases/download/1.6.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    curl -L https://github.com/docker/machine/releases/download/v0.7.0-rc1/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine && \
    chmod +x /usr/local/bin/docker-machine
    chmod +x /usr/local/bin/docker-compose
    export PATH=$PATH:/usr/local/bin/
    mv /etc/localtime /etc/localtime.bak
    ln -s /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime
    #yum -y install icu patch ruby ruby-devel rubygems python-pip
    #yum install -y nodejs
    #yum install -y npm
    #npm install -g azure-cli
    # Setting tomcat
    #docker run -it -dp 80:8080 -p 8009:8009  rossbachp/apache-tomcat8
    docker run -dti --name=azure-cli microsoft/azure-cli 
    docker run -it -d --restart=always -p 8080:8080 rancher/server
    systemctl enable rdma
    yum groupinstall -y "Infiniband Support"
    yum install -y infiniband-diags perftest qperf opensm
    chkconfig opensm on
    chkconfig rdma on
    reboot
}

# Partitions all data disks attached to the VM and creates
# a RAID-0 volume with them.
#
setup_data_disks()
{
    mountPoint="$1"
    createdPartitions=""

    # Loop through and partition disks until not found
    for disk in sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr; do
        fdisk -l /dev/$disk || break
        fdisk /dev/$disk << EOF
n
p
1


t
fd
w
EOF
        createdPartitions="$createdPartitions /dev/${disk}1"
    done

    # Create RAID-0 volume
    if [ -n "$createdPartitions" ]; then
        devices=`echo $createdPartitions | wc -w`
        mdadm --create /dev/md10 --level 0 --raid-devices $devices $createdPartitions
        mkfs -t ext4 /dev/md10
        echo "/dev/md10 $mountPoint ext4 defaults,nofail 0 2" >> /etc/fstab
        mount /dev/md10
    fi
}
setup_dynamicdata_disks()
{
    mountPoint="$1"
    createdPartitions=""
    numberofDisks="$9"

    # Loop through and partition disks until not found

if [ $numberofDisks == "1" ]
then
   disking=( sdc )
elseif [ $numberofDisks == "2" ]
then
   disking=( sdc sdd )
elseif [ $numberofDisks == "3" ]
then
   disking=( sdc sdd sde )
elseif [ $numberofDisks == "4" ]
then
   disking=( sdc sdd sde sdf )
elseif [ $numberofDisks == "5" ]
then
   disking=( sdc sdd sde sdf sdg )
elseif [ $numberofDisks == "6" ]
then
   disking=( sdc sdd sde sdf sdg sdh )
elseif [ $numberofDisks == "7" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi )
elseif [ $numberofDisks == "8" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj )
elseif [ $numberofDisks == "9" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk )
elseif [ $numberofDisks == "10" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl )
elseif [ $numberofDisks == "11" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm )
elseif [ $numberofDisks == "12" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn )
elseif [ $numberofDisks == "13" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo )
elseif [ $numberofDisks == "14" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp )
elseif [ $numberofDisks == "15" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq )
elseif [ $numberofDisks == "16" ]
then
   disking=( sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp sdq sdr )
fi

printf "%s\n" "${disking[@]}"

for disk in "${disking[@]}"
do
        fdisk -l /dev/$disk || break
        fdisk /dev/$disk << EOF
n
p
1


t
fd
w
EOF
        createdPartitions="$createdPartitions /dev/${disk}1"
done

    # Create RAID-0 volume
    if [ -n "$createdPartitions" ]; then
        devices=`echo $createdPartitions | wc -w`
        mdadm --create /dev/md10 --level 0 --raid-devices $devices $createdPartitions
        mkfs -t ext4 /dev/md10
        echo "/dev/md10 $mountPoint ext4 defaults,nofail 0 2" >> /etc/fstab
        mount /dev/md10
    fi
}
# Creates and exports two shares on the master nodes:
#
# /share/home (for HPC user)
# /share/data
#
# These shares are mounted on all worker nodes.
#
setup_shares()
{
    mkdir -p $SHARE_HOME
    mkdir -p $SHARE_DATA

    if is_master; then
        #setup_data_disks $SHARE_DATA
	setup_dynamicdata_disks $SHARE_DATA
        echo "$SHARE_HOME    *(rw,async)" >> /etc/exports
        echo "$SHARE_DATA    *(rw,async)" >> /etc/exports

        systemctl enable rpcbind || echo "Already enabled"
        systemctl enable nfs-server || echo "Already enabled"
        systemctl start rpcbind || echo "Already enabled"
        systemctl start nfs-server || echo "Already enabled"
    else
        echo "master:$SHARE_HOME $SHARE_HOME    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
        echo "master:$SHARE_DATA $SHARE_DATA    nfs4    rw,auto,_netdev 0 0" >> /etc/fstab
        mount -a
        mount | grep "^master:$SHARE_HOME"
        mount | grep "^master:$SHARE_DATA"
    fi
}

# Downloads/builds/installs munged on the node.
# The munge key is generated on the master node and placed
# in the data share.
# Worker nodes copy the existing key from the data share.
#
install_munge()
{
    groupadd $MUNGE_GROUP

    useradd -M -c "Munge service account" -g munge -s /usr/sbin/nologin munge

    wget https://github.com/dun/munge/archive/munge-${MUNGE_VERSION}.tar.gz

    tar xvfz munge-$MUNGE_VERSION.tar.gz

    cd munge-munge-$MUNGE_VERSION

    mkdir -m 700 /etc/munge
    mkdir -m 711 /var/lib/munge
    mkdir -m 700 /var/log/munge
    mkdir -m 755 /var/run/munge

    ./configure -libdir=/usr/lib64 --prefix=/usr --sysconfdir=/etc --localstatedir=/var && make && make install

    chown -R munge:munge /etc/munge /var/lib/munge /var/log/munge /var/run/munge

    if is_master; then
        dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
    mkdir -p $SLURM_CONF_DIR
        cp /etc/munge/munge.key $SLURM_CONF_DIR
    else
        cp $SLURM_CONF_DIR/munge.key /etc/munge/munge.key
    fi

    chown munge:munge /etc/munge/munge.key
    chmod 0400 /etc/munge/munge.key

    /etc/init.d/munge start

    cd ..
}

# Installs and configures slurm.conf on the node.
# This is generated on the master node and placed in the data
# share.  All nodes create a sym link to the SLURM conf
# as all SLURM nodes must share a common config file.
#
install_slurm_config()
{
    if is_master; then

        mkdir -p $SLURM_CONF_DIR

        if [ -e "$TEMPLATE_BASE_URL/slurm.template.conf" ]; then
            cp "$TEMPLATE_BASE_URL/slurm.template.conf" .
        else
            wget "$TEMPLATE_BASE_URL/slurm.template.conf"
        fi

        cat slurm.template.conf |
        sed 's/__MASTER__/'"$MASTER_HOSTNAME"'/g' |
                sed 's/__WORKER_HOSTNAME_PREFIX__/'"$WORKER_HOSTNAME_PREFIX"'/g' |
                sed 's/__LAST_WORKER_INDEX__/'"$LAST_WORKER_INDEX"'/g' > $SLURM_CONF_DIR/slurm.conf
    fi

    ln -s $SLURM_CONF_DIR/slurm.conf /etc/slurm/slurm.conf
}

# Downloads, builds and installs SLURM on the node.
# Starts the SLURM control daemon on the master node and
# the agent on worker nodes.
#
install_slurm()
{
    groupadd -g $SLURM_GID $SLURM_GROUP

    useradd -M -u $SLURM_UID -c "SLURM service account" -g $SLURM_GROUP -s /usr/sbin/nologin $SLURM_USER

    mkdir -p /etc/slurm /var/spool/slurmd /var/run/slurmd /var/run/slurmctld /var/log/slurmd /var/log/slurmctld

    chown -R slurm:slurm /var/spool/slurmd /var/run/slurmd /var/run/slurmctld /var/log/slurmd /var/log/slurmctld

    wget https://github.com/SchedMD/slurm/archive/slurm-$SLURM_VERSION.tar.gz

    tar xvfz slurm-$SLURM_VERSION.tar.gz

    cd slurm-slurm-$SLURM_VERSION

    ./configure -libdir=/usr/lib64 --prefix=/usr --sysconfdir=/etc/slurm && make && make install

    install_slurm_config

    if is_master; then
        /usr/sbin/slurmctld -vvvv
    else
        /usr/sbin/slurmd -vvvv
    fi

    cd ..
}

# Adds a common HPC user to the node and configures public key SSh auth.
# The HPC user has a shared home directory (NFS share on master) and access
# to the data share.
#
setup_hpc_user()
{
    # disable selinux
    sed -i 's/enforcing/disabled/g' /etc/selinux/config
    setenforce permissive
    
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

    if is_master; then
    
        useradd -c "HPC User" -g $HPC_GROUP -m -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER

        mkdir -p $SHARE_HOME/$HPC_USER/.ssh
        
        # Configure public key auth for the HPC user
        ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -P ""
        cat $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub > $SHARE_HOME/$HPC_USER/.ssh/authorized_keys

        echo "Host *" > $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    StrictHostKeyChecking no" >> $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    UserKnownHostsFile /dev/null" >> $SHARE_HOME/$HPC_USER/.ssh/config
        echo "    PasswordAuthentication no" >> $SHARE_HOME/$HPC_USER/.ssh/config

        # Fix .ssh folder ownership
        chown -R $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER

        # Fix permissions
        chmod 700 $SHARE_HOME/$HPC_USER/.ssh
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/config
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/authorized_keys
        chmod 600 $SHARE_HOME/$HPC_USER/.ssh/id_rsa
        chmod 644 $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub
        
        # Give hpc user access to data share
        chown $HPC_USER:$HPC_GROUP $SHARE_DATA
    else
        useradd -c "HPC User" -g $HPC_GROUP -d $SHARE_HOME/$HPC_USER -s /bin/bash -u $HPC_UID $HPC_USER
    fi
}

# Sets all common environment variables and system parameters.
#
setup_env()
{
    # Set unlimited mem lock
    echo "$HPC_USER hard memlock unlimited" >> /etc/security/limits.conf
    echo "$HPC_USER soft memlock unlimited" >> /etc/security/limits.conf

    # Intel MPI config for IB
    echo "# IB Config for MPI" > /etc/profile.d/mpi.sh
    echo "export I_MPI_FABRICS=shm:dapl" >> /etc/profile.d/mpi.sh
    echo "export I_MPI_DAPL_PROVIDER=ofa-v2-ib0" >> /etc/profile.d/mpi.sh
    echo "export I_MPI_DYNAMIC_CONNECTION=0" >> /etc/profile.d/mpi.sh
}

install_easybuild()
{
    yum -y install Lmod python-devel python-pip gcc gcc-c++ patch unzip tcl tcl-devel libibverbs libibverbs-devel
    pip install vsc-base

    EASYBUILD_HOME=$SHARE_HOME/$HPC_USER/EasyBuild

    if is_master; then
        su - $HPC_USER -c "pip install --install-option --prefix=$EASYBUILD_HOME https://github.com/hpcugent/easybuild-framework/archive/easybuild-framework-v2.5.0.tar.gz"

        # Add Lmod to the HPC users path
        echo 'export PATH=/usr/share/lmod/6.0.15/libexec:$PATH' >> $SHARE_HOME/$HPC_USER/.bashrc

        # Setup Easybuild configuration and paths
        echo 'export PATH=$HOME/EasyBuild/bin:$PATH' >> $SHARE_HOME/$HPC_USER/.bashrc
        echo 'export PYTHONPATH=$HOME/EasyBuild/lib/python2.7/site-packages:$PYTHONPATH' >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export MODULEPATH=$EASYBUILD_HOME/modules/all" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export EASYBUILD_MODULES_TOOL=Lmod" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export EASYBUILD_INSTALLPATH=$EASYBUILD_HOME" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "export EASYBUILD_DEBUG=1" >> $SHARE_HOME/$HPC_USER/.bashrc
        echo "source /usr/share/lmod/6.0.15/init/bash" >> $SHARE_HOME/$HPC_USER/.bashrc
    fi
}
build_cross_cc()
{
    #! /bin/bash
set -e
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
trap 'echo FAILED COMMAND: $previous_command' EXIT

#-------------------------------------------------------------------------------------------
# This script will download packages for, configure, build and install a GCC cross-compiler.
# Customize the variables (INSTALL_PATH, TARGET, etc.) to your liking before running.
# If you get an error and need to resume the script from some point in the middle,
# just delete/comment the preceding lines before running it again.
#
#-------------------------------------------------------------------------------------------

INSTALL_PATH=/opt/cross
TARGET=aarch64-linux
USE_NEWLIB=0
LINUX_ARCH=arm64
CONFIGURATION_OPTIONS="--disable-multilib" # --disable-threads --disable-shared
PARALLEL_MAKE=-j4
BINUTILS_VERSION=binutils-2.24
GCC_VERSION=gcc-4.9.2
LINUX_KERNEL_VERSION=linux-3.17.2
GLIBC_VERSION=glibc-2.20
MPFR_VERSION=mpfr-3.1.2
GMP_VERSION=gmp-6.0.0a
MPC_VERSION=mpc-1.0.2
ISL_VERSION=isl-0.12.2
CLOOG_VERSION=cloog-0.18.1
export PATH=$INSTALL_PATH/bin:$PATH

# Download packages
export http_proxy=$HTTP_PROXY https_proxy=$HTTP_PROXY ftp_proxy=$HTTP_PROXY
wget -nc https://ftp.gnu.org/gnu/binutils/$BINUTILS_VERSION.tar.gz
wget -nc https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_VERSION.tar.gz
if [ $USE_NEWLIB -ne 0 ]; then
    wget -nc -O newlib-master.zip https://github.com/bminor/newlib/archive/master.zip || true
    unzip -qo newlib-master.zip
else
    wget -nc https://www.kernel.org/pub/linux/kernel/v3.x/$LINUX_KERNEL_VERSION.tar.xz
    wget -nc https://ftp.gnu.org/gnu/glibc/$GLIBC_VERSION.tar.xz
fi
wget -nc https://ftp.gnu.org/gnu/mpfr/$MPFR_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/gmp/$GMP_VERSION.tar.xz
wget -nc https://ftp.gnu.org/gnu/mpc/$MPC_VERSION.tar.gz
wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$ISL_VERSION.tar.bz2
wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$CLOOG_VERSION.tar.gz

# Extract everything
for f in *.tar*; do tar xfk $f; done

# Make symbolic links
cd $GCC_VERSION
ln -sf `ls -1d ../mpfr-*/` mpfr
ln -sf `ls -1d ../gmp-*/` gmp
ln -sf `ls -1d ../mpc-*/` mpc
ln -sf `ls -1d ../isl-*/` isl
ln -sf `ls -1d ../cloog-*/` cloog
cd ..

# Step 1. Binutils
mkdir -p build-binutils
cd build-binutils
../$BINUTILS_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS
make $PARALLEL_MAKE
make install
cd ..

# Step 2. Linux Kernel Headers
if [ $USE_NEWLIB -eq 0 ]; then
    cd $LINUX_KERNEL_VERSION
    make ARCH=$LINUX_ARCH INSTALL_HDR_PATH=$INSTALL_PATH/$TARGET headers_install
    cd ..
fi

# Step 3. C/C++ Compilers
mkdir -p build-gcc
cd build-gcc
if [ $USE_NEWLIB -ne 0 ]; then
    NEWLIB_OPTION=--with-newlib
fi
../$GCC_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET --enable-languages=c,c++ $CONFIGURATION_OPTIONS $NEWLIB_OPTION
make $PARALLEL_MAKE all-gcc
make install-gcc
cd ..

if [ $USE_NEWLIB -ne 0 ]; then
    # Steps 4-6: Newlib
    mkdir -p build-newlib
    cd build-newlib
    ../newlib-master/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS
    make $PARALLEL_MAKE
    make install
    cd ..
else
    # Step 4. Standard C Library Headers and Startup Files
    mkdir -p build-glibc
    cd build-glibc
    ../$GLIBC_VERSION/configure --prefix=$INSTALL_PATH/$TARGET --build=$MACHTYPE --host=$TARGET --target=$TARGET --with-headers=$INSTALL_PATH/$TARGET/include $CONFIGURATION_OPTIONS libc_cv_forced_unwind=yes
    make install-bootstrap-headers=yes install-headers
    make $PARALLEL_MAKE csu/subdir_lib
    install csu/crt1.o csu/crti.o csu/crtn.o $INSTALL_PATH/$TARGET/lib
    $TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $INSTALL_PATH/$TARGET/lib/libc.so
    touch $INSTALL_PATH/$TARGET/include/gnu/stubs.h
    cd ..

    # Step 5. Compiler Support Library
    cd build-gcc
    make $PARALLEL_MAKE all-target-libgcc
    make install-target-libgcc
    cd ..

    # Step 6. Standard C Library & the rest of Glibc
    cd build-glibc
    make $PARALLEL_MAKE
    make install
    cd ..
fi

# Step 7. Standard C++ Library & the rest of GCC
cd build-gcc
make $PARALLEL_MAKE all
make install
cd ..

trap - EXIT
echo 'Success!'

echo "PATH=\"/usr/local/bin:$PATH\"" >> ~/.bash_profile
ln -s /opt/cross/bin/aarch64-linux-gcc -> /usr/local/bin/gcc
ln -s /opt/cross/bin/aarch64-linux-gcc-ranlib -> /usr/local/bin/gcc-ranlib
ln -s /opt/cross/bin/aarch64-linux-objdump  /usr/local/bin/objdump
ln -s /opt/cross/bin/aarch64-linux-aarch64-linux-nm-> /usr/local/bin/nm
ln -s /opt/cross/bin/aarch64-linux-elfedit -> /usr/local/bin/elfedit
ln -s /opt/cross/bin/aarch64-linux-as -> /usr/local/bin/as
ln -s /opt/cross/bin/aarch64-linux-size -> /usr/local/bin/size
ln -s /opt/cross/bin/aarch64-linux-ar -> /usr/local/bin/ar
ln -s /opt/cross/bin/aarch64-linux-g++ -> /usr/local/bin/g++
ln -s /opt/cross/bin/aarch64-linux-strings -> /usr/local/bin/strings
ln -s /opt/cross/bin/aarch64-linux-readelf -> /usr/local/bin/readelf
ln -s /opt/cross/bin/aarch64-linux-ranlib -> /usr/local/bin/ranlib
ln -s /opt/cross/bin/aarch64-linux-c++ -> /usr/local/bin/c++
ln -s /opt/cross/bin/aarch64-linux-addr2line -> /usr/local/bin/addr2line
ln -s /opt/cross/bin/aarch64-linux-ld -> /usr/local/bin/ld
ln -s /opt/cross/bin/aarch64-linux-gprof -> /usr/local/bin/gprof
ln -s /opt/cross/bin/aarch64-linux-gcov -> /usr/local/bin/gcov
ln -s /opt/cross/bin/aarch64-linux-objcopy -> /usr/local/bin/objcopy
ln -s /opt/cross/bin/aarch64-linux-c++filt -> /usr/local/bin/c++filt
ln -s /opt/cross/bin/aarch64-linux-gcc-ar -> /usr/local/bin/gcc-ar
ln -s /opt/cross/bin/aarch64-linux-gcc-4.9.2 -> /usr/local/bin/gcc-4.9.2
ln -s /opt/cross/bin/aarch64-linux-gcc-nm -> /usr/local/bin/gcc-nm
ln -s /opt/cross/bin/aarch64-linux-cpp -> /usr/local/bin/cpp
ln -s /opt/cross/bin/aarch64-linux-strip -> /usr/local/bin/strip
export PATH=$PATH:/usr/local/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/cross/lib/gcc/aarch64-linux/4.9.2
cd /opt/cross
./configure -libdir=/usr/lib64 --prefix=/usr --sysconfdir=/etc --localstatedir=/var --host=aarch64 --target=intel64  --disable-tests --disable-failing-tests --disable-gtktest && make && make install


}
setup_shares
setup_hpc_user
install_munge
install_slurm
setup_env
install_pkgs
#install_easybuild
#build_cross_cc
