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

openssl aes-256-cbc -K $encrypted_97c782117613_key -iv $encrypted_97c782117613_iv -in rsakey.pem.enc -out rsakey.pem -d
chmod 400 rsakey.pem

aws cloudformation create-stack --stack-name rookstack --template-url https://editions-us-east-1.s3.amazonaws.com/aws/stable/18.03.0/Docker.tmpl --region eu-west-1 --parameters ParameterKey=KeyName,ParameterValue=rsakey ParameterKey=InstanceType,ParameterValue=t2.micro ParameterKey=ManagerInstanceType,ParameterValue=t2.micro ParameterKey=ClusterSize,ParameterValue=3 --capabilities CAPABILITY_IAM 



stackStatus="CREATE_IN_PROGRESS"

while [[ 1 ]]; do
    echo aws cloudformation describe-stacks --region eu-west-1 --stack-name rookstack
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
IP=`aws ec2 describe-instances --filter "Name=tag:swarm-node-type,Values=manager"  --query 'Reservations[].Instances[].{IP:PublicIpAddress}' --output text | grep -v None | head -n1`
echo Manager IP Address: $IP
ssh -oStrictHostKeyChecking=no -4 -i rsakey.pem -NL localhost:2374:/var/run/docker.sock docker@$IP & docker -H localhost:2374 info
echo "port forwaring setup complete"
sleep 5
echo "try to run docker on the server"
docker -H localhost:2374 info
docker -H localhost:2374 network create --attachable --driver overlay rook_public_net
docker -H localhost:2374 network create --attachable --driver overlay rook_private_net
docker -H localhost:2374 network create --attachable --driver overlay rook_monitoring_net
docker -H localhost:2374 network create --attachable --driver overlay rook_logging_net
docker -H localhost:2374 stack deploy -c visualiser-docker-compose.yml visualiser
docker -H localhost:2374 stack deploy -c nginx-docker-compose.yml proxy
docker -H localhost:2374 stack deploy -c rabbit-docker-compose.yml queue
docker -H localhost:2374 stack deploy -c monitoring-docker-compose.yml monitoring