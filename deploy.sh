#!/usr/bin/env bash

sudo pip install awscli

mkdir -p ~/.aws


cat > ~/.aws/credentials << EOL
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOL

cat > ~/.aws/config << EOL
[default]
output = json
region = ${AWS_REGION}
EOL

aws cloudformation create-stack --stack-name rookstack --template-url https://editions-us-east-1.s3.amazonaws.com/aws/stable/Docker.tmpl --region eu-west-1 --parameters ParameterKey=KeyName,ParameterValue=rsakey ParameterKey=InstanceType,ParameterValue=t2.micro ParameterKey=ManagerInstanceType,ParameterValue=t2.micro ParameterKey=ClusterSize,ParameterValue=3 --capabilities CAPABILITY_IAM 
aws cloudformation wait stack-create-complete --stack-name rookstack
aws ec2 describe-instances --query 'Reservations[0].Instances[0].{ID:InstanceId}' | grep ID | awk -F ":" '{print $2}' | sed 's/[",]//g'
MANAGER_INSTANCE=`aws ec2 describe-instances --query 'Reservations[0].Instances[0].{ID:InstanceId}' | grep ID | awk -F ":" '{print $2}' | sed 's/[",]//g'`
echo $MANAGER_INSTANCE
IP=`aws ec2 describe-instances --instance-ids $MANAGER_INSTANCE | grep PublicIpAddress | awk -F ":" '{print $2}' | sed 's/[",]//g'`
echo $IP
ssh - ./rsakey.pem -NL localhost:2374:/var/run/docker.sock docker@'{print $IP}
set DOCKER_HOST=localhost:2374

docker info