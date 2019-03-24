# Rook.Platform.Infrastructure
Rook Platform Infrastructure Deployment Scripts

[![Build Status](https://travis-ci.org/rookframework/Rook.Platform.Infrastructure.svg?branch=master)](https://travis-ci.org/rookframework/Rook.Platform.Infrastructure)

This repository contains all the scripts needed to deploy the rook platform to AWS using Travis CI. 

If you intend to replicate this build for your own environment you will need to define the following environment variables in Travis CI. If you use another build system, you can use this script as a starting point for creating your own script. You could also modify the stackname in the script to be an environment variable, allowing you to deploy multipe instances of the environmwnt. The Default environment variables you will need are:

    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_REGION

You will also need to create a key pair in AWS called rsakey so that the docker client can connect to the AWS infrastructure to perform deployments. It is important not to store your private key in the repository. With travis CI this can be solved by installing the travis cli client and encrypting your private key. See https://docs.travis-ci.com/user/encrypting-files/ for more information. 
