#!/bin/sh

echo "install java"
yum install java-1.8.0-openjdk-devel

echo "install jenkins repo"
curl --silent --location http://pkg.jenkins-ci.org/redhat-stable/jenkins.repo | sudo tee /etc/yum.repos.d/jenkins.repo
rpm --import https://jenkins-ci.org/redhat/jenkins-ci.org.key

echo "install Jenkins"
yum install jenkins -y

echo "start Jenkins"
systemctl start jenkins
systemctl start jenkins