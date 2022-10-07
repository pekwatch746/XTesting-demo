#! /bin/bash
set -ex

echo "This is to demonstrate the XTesting work flow against the OSC RIC platform deployment and perform health check"

if [ $# -lt 2 ]
then 
	echo "Usage: $0 target-ip private-key-file-path [working-directory]"
	exit 1
fi

IP=$1
KEYFILE=$2
if [ $# -ge 3 ]
then
	WORKDIR=$3
fi

if [ ! -d $WORKDIR ]
then 
	mkdir -p $WORKDIR
fi

# copy over the health check test case to the working directory
cp healthcheck.robot $WORKDIR
cd $WORKDIR
# replace it with the target IP address for health check
sed -i "s/TARGET-IP/${IP}/" healthcheck.robot

# step 1 deploy Kubernetes cluster and obtain the Kube config
# remove the old one if it's already there
if [ -d kubespray ]
then
	rm -rf kubespray
fi
git clone https://github.com/pekwatch746/kubespray.git
cd kubespray
TMPFILE=/tmp/tmp`date +%s`
cat sample_env | sed -e '/ANSIBLE_HOST_IP/d' > $TMPFILE
echo "ANSIBLE_HOST_IP=${IP}" > sample_env
cat $TMPFILE >> sample_env

# copy the private key to the inventory/sample folder as id_rsa
cp $KEYFILE inventory/sample/id_rsa
chmod 400 inventory/sample/id_rsa

# build the Docker image
docker build -t kubespray .

# run the docker container to deploy Kubernetes onto the SUT specified by the IP address
docker run -v ~/.kube:/kubespray/config kubespray 

cd $WORKDIR
# step 2 complete the deployment based on the Kube config from step 1
# remove the old one if it's already there
if [ -d richelm ]
then
	rm -rf richelm
fi

git clone https://github.com/pekwatch746/richelm.git

cd richelm && export REBUILD=true && ./build.sh

docker run -ti --rm -w /apps -v ~/.kube:/root/.kube -t alpine/k8s:1.23.7

# sometimes some RIC platform containers are not up right away so wait a bit
sleep 60	

cd $WORKDIR
# step 3 run the health check test case to complete the demo
ansible-playbook healthcheck.robot
