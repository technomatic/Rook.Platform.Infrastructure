#!/usr/bin/env bash


#Install and configure the AWS Cli in order to configure AWS
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

#Assuming your repo is on github and connected to travis-ci. In AWS create a keypair (.pem) and use travis cli to encrypt it inside the repo directory. Do not commit the .pem to the repo, 
#only the encrypted version and add the variables travis generates in the build to the line below
openssl aes-256-cbc -K $encrypted_97c782117613_key -iv $encrypted_97c782117613_iv -in rsakey.pem.enc -out rsakey.pem -d
chmod 400 rsakey.pem

#Use the cloudformation template created by docker and approved by AWS. The latest version (18.09) has issues with cloudstor so using 18.03.0
aws cloudformation create-stack --stack-name rookstack --template-body https://s3-eu-west-1.amazonaws.com/dev.kube.mab.scot/rook.tmpl --region eu-west-1 --parameters ParameterKey=KeyName,ParameterValue=rsakey ParameterKey=InstanceType,ParameterValue=t2.micro ParameterKey=ManagerInstanceType,ParameterValue=t2.medium ParameterKey=ClusterSize,ParameterValue=7 --capabilities CAPABILITY_IAM 

#wait for aws stack status to reach CREATE_COMPLETE
stackStatus="CREATE_IN_PROGRESS"
while [[ 1 ]]; do
    echo "checking stack status..."
    response=$(aws cloudformation describe-stacks --region eu-west-1 --stack-name rookstack 2>&1)
    responseOrig="$response"
    response=$(echo "$response" | tr '\n' ' ' | tr -s " " | sed -e 's/^ *//' -e 's/ *$//')

    if [[ "$response" != *"StackStatus"* ]]
    then
        echo "Error occurred creating AWS CloudFormation stack. Error:"
        echo "    $responseOrig"
        exit -1
    fi

    stackStatus=$(echo $response | sed -e 's/^.*"StackStatus"[ ]*:[ ]*"//' -e 's/".*//')
    echo "    StackStatus: $stackStatus"

    if [[ "$stackStatus" == "ROLLBACK_IN_PROGRESS" ]] || [[ "$stackStatus" == "ROLLBACK_COMPLETE" ]] || [[ "$stackStatus" == "DELETE_IN_PROGRESS" ]] || [[ "$stackStatus" == "DELETE_COMPLETE" ]]; then
        echo "Error occurred creating AWS CloudFormation stack and returned status code ROLLBACK_IN_PROGRESS. Details:"
        echo "$responseOrig"
        exit -1
    elif [[ "$stackStatus" == "CREATE_COMPLETE" ]]; then
        break
    fi
    sleep 60
done


export EMAIL=mark.jones@mab.org.uk
export DOMAIN=dev.mab.scot
export USERNAME=admin
export PASSWORD=SmallGreenFish
export HASHED_PASSWORD=$(openssl passwd -apr1 $PASSWORD)
export CONSUL_REPLICAS=3
export TRAEFIK_REPLICAS=3
export ADMIN_USER=admin
export ENVIRONMENT=dev


#get the swarm manager public IP address and set local ssh port forwarding to connect to docker
IP=`aws ec2 describe-instances --filter "Name=tag:swarm-node-type,Values=manager"  --query 'Reservations[].Instances[].{IP:PublicIpAddress}' --output text | grep -v None | head -n1`
ssh -oStrictHostKeyChecking=no -4 -i rsakey.pem -NL localhost:2374:/var/run/docker.sock docker@$IP & docker -H localhost:2374 info

#sometime the script is to fast and things don't work as expected
sleep 5

export NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')

docker node update --label-add swarmpit.db-data=true $NODE_ID

#create docker networks
docker network create --attachable --driver overlay traefik-public
docker network create --attachable --driver overlay rook_private_net
#docker -H localhost:2374 network create --attachable --driver overlay rook_monitoring_net
#docker -H localhost:2374 network create --attachable --driver overlay rook_logging_net

#deploy platform stacks. 

docker stack deploy -c traefik-docker-compose.yml proxy
docker stack deploy -c monitoring-docker-compose.yml monitoring
docker stack deploy -c visualiser-docker-compose.yml visualiser
docker stack deploy -c swarmpit-docker-compose.yml manager

docker stack deploy -c rabbit-docker-compose.yml queue
docker stack deploy -c rook-platform.yml rook
