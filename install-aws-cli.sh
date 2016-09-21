#!/bin/bash
#set -x

#Update packages list
sudo apt-get update > /dev/null

#Install Python
sudo apt-get install python2.7 > /dev/null

#Install unzip
sudo apt-get install unzip > /dev/null

#Install AWS CLI
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "/tmp/awscli-bundle.zip" &> /dev/null
unzip -o /tmp/awscli-bundle.zip -d /tmp/ > /dev/null
sudo /tmp/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws > /dev/null

# AWS configure
## config file
mkdir ~/.aws &> /dev/null
touch ~/.aws/config 
echo -e "[default]\noutput = text\nregion = us-west-2\n" > ~/.aws/config

## credentials file
touch ~/.aws/credentials
read -p "Enter your AWS Access Key ID [None]: "  awsKeyID
read -p "Enter your AWS Secret Access Key [None]: "  awsKey
echo -e "[default]\naws_access_key_id = ${awsKeyID}\naws_secret_access_key = ${awsKey}\n" > ~/.aws/credentials

# AWS creating security group and allows incoming traffic over port 22 for SSH
SecGroupName="test-4me"
GroupId=$(aws ec2 create-security-group --group-name $SecGroupName --description "TEST Security group for ME")
aws ec2 authorize-security-group-ingress --group-id $GroupId --protocol tcp --port 22 --cidr 0.0.0.0/0

# AWS creating a key pair for connect to instance
KeyPairName="devenv-key"
KeyPairFile=${KeyPairName}.pem
aws ec2 create-key-pair --key-name $KeyPairName --query 'KeyMaterial' --output text > ${KeyPairFile}
chmod 400 $KeyPairFile

#AWS create and run instance
InstanceID=$(aws ec2 run-instances --image-id ami-29ebb519 --security-group-ids $GroupId --count 1 --instance-type t2.micro --key-name $KeyPairName --query 'Instances[0].InstanceId') #2>&1

# AWS give some time to pending and running instance
sleep 60

# AWS get public IP from instance and make SSH connecting to it
InstanceIP=$(aws ec2 describe-instances --instance-ids $InstanceID --query 'Reservations[0].Instances[0].PublicIpAddress')

#set -x
# DOCKER
ssh -o "StrictHostKeyChecking no" -i $KeyPairFile ubuntu@"$InstanceIP" 'sudo apt-get update' &> /dev/null
ssh -i $KeyPairFile ubuntu@"$InstanceIP" 'curl -fsSL https://get.docker.com/ > /tmp/docker.sh' &> /dev/null
ssh -i $KeyPairFile ubuntu@"$InstanceIP" 'bash /tmp/docker.sh' &> /dev/null
ssh -i $KeyPairFile ubuntu@"$InstanceIP" 'sudo usermod -aG docker $USER' &> /dev/null
ssh -i $KeyPairFile ubuntu@"$InstanceIP" 'logout' &> /dev/null
ssh -i $KeyPairFile ubuntu@"$InstanceIP" 'docker run --name mySQLserver -d -p 3306:3306 -e MYSQL_ROOT_PASSWORD=pass@word01 mysql:latest'&> /dev/null
ssh -i $KeyPairFile ubuntu@"$InstanceIP" 'docker run java:latest' &> /dev/null
#something else about docker

#set +x

# Information and ending futuries
echo -e " \nNow you have run your:\n   instance $InstanceID\n   public IP $InstanceIP\n   and key name $KeyPairFile\n" 

read -t10 -n1 -r -p 'Press any key to EXIT or wait 10 sec to connect to your intrance...' key
if [ "$?" -eq "0" ]; then
    exit
else
    ssh -i $KeyPairFile ubuntu@"$InstanceIP"
fi
