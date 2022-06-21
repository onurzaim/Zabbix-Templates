#!/bin/bash

deployAmi2 () {
serverAddress="zabbix.staging.moblize.com"
agentConfigFile="/etc/zabbix/zabbix_agent2.conf"

yum update -y ca-certificates
rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
yum install -y zabbix-agent2

sed -i "s/Server=127.0.0.1/Server=$serverAddress/g" $agentConfigFile
sed -i "s/ServerActive=127.0.0.1/ServerActive=$serverAddress/g" $agentConfigFile
sed -i "s/Hostname=Zabbix server/#Hostname=Zabbix server/g" $agentConfigFile
sed -i "s/# HostnameItem=system.hostname/HostnameItem=system.hostname/g" $agentConfigFile
sed -i "s/# HostMetadata=/HostMetadata=MoblizeDocker/g" $agentConfigFile

mkdir -p /etc/systemd/system/zabbix-agent2.service.d/
tee /etc/systemd/system/zabbix-agent2.service.d/override.conf <<EOF
[Service]
User=root
Group=root
EOF

systemctl daemon-reload
systemctl restart zabbix-agent2

}

deployAmi1 () {

serverAddress="zabbix.staging.moblize.com"
agentConfigFile="/etc/zabbix/zabbix_agentd.conf"
agentParameterDir="/etc/zabbix/zabbix_agentd.d"

yum update -y ca-certificates
rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/6/x86_64/zabbix-release-4.0-2.el6.noarch.rpm
yum install -y zabbix-agent

sed -i "s/Server=127.0.0.1/Server=$serverAddress/g" $agentConfigFile
sed -i "s/ServerActive=127.0.0.1/ServerActive=$serverAddress/g" $agentConfigFile
sed -i "s/Hostname=Zabbix server/#Hostname=Zabbix server/g" $agentConfigFile
sed -i "s/# HostnameItem=system.hostname/HostnameItem=system.hostname/g" $agentConfigFile
sed -i "s/# HostMetadata=/HostMetadata=MoblizeDockerAMI1/g" $agentConfigFile
sed -i "s/# AllowRoot=0/AllowRoot=1/g" $agentConfigFile
sed -i "s/# EnableRemoteCommands=0/EnableRemoteCommands=1/g" $agentConfigFile
sed -i "s/# LogRemoteCommands=0/LogRemoteCommands=1/g" $agentConfigFile

sed -i "s/ZABBIX_AGENT_USER=zabbix/ZABBIX_AGENT_USER=root/g"  /etc/sysconfig/zabbix-agent

tee $agentParameterDir/docker.conf <<EOF
UserParameter=docker.container_info[*], curl -s --unix-socket /var/run/docker.sock http://localhost/containers/\$1/json
UserParameter=docker.container_stats[*], curl -s --unix-socket /var/run/docker.sock http://localhost/containers/\$1/stats?stream=false
UserParameter=docker.containers, curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json?all=true
UserParameter=docker.containers.discovery[*], curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json?all=\$1 | jq '[.[] | {Id,Names}] | .[].Names|=.[0]' | sed -e s/Id/{#ID}/g -e s/Names/{#NAME}/g
UserParameter=docker.data_usage, curl -s --unix-socket /var/run/docker.sock http://localhost/system/df
UserParameter=docker.images, curl -s --unix-socket /var/run/docker.sock http://localhost/images/json
UserParameter=docker.images.discovery, curl -s --unix-socket /var/run/docker.sock http://localhost/images/json | jq '[.[] | {Id,RepoTags}] | .[].RepoTags|=.[0]' | sed -e s/Id/{#ID}/g -e s/RepoTags/{#NAME}/g
UserParameter=docker.info, curl -s --unix-socket /var/run/docker.sock http://localhost/info
UserParameter=docker.ping, curl -s --unix-socket /var/run/docker.sock http://localhost/_ping
EOF


service zabbix-agent restart
chkconfig --level 35 zabbix-agent on

}

osCheck=$(cat /etc/os-release | grep -c -i "Amazon Linux 2")

if [ "$osCheck" = 1 ]; then
echo "AMI 2 Detected"
deployAmi2
else
echo "AMI 1 Detected"
deployAmi1
fi

