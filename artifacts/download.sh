exec >download.log
exec 2>&1

sudo apt-get update
sudo apt install rsync -y

# Injecting environment variables from Azure deployment
echo '#!/bin/bash' >> vars.sh
echo $ADMIN_USER_NAME:$1 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_ID:$2 | awk '{print substr($1,2); }' >> vars.sh
echo $SPN_CLIENT_SECRET:$3 | awk '{print substr($1,2); }' >> vars.sh
echo $TENANT_ID:$4 | awk '{print substr($1,2); }' >> vars.sh
echo $AKS_RESOURCE_GROUP_NAME:$5 | awk '{print substr($1,2); }' >> vars.sh
echo $LOCATION:$6 | awk '{print substr($1,2); }' >> vars.sh
echo $DNS_PRIVATE_ZONE_NAME:$7 | awk '{print substr($1,2); }' >> vars.sh
echo $AKS_NAME:$8 | awk '{print substr($1,2); }' >> vars.sh
echo $AKV_NAME:$9 | awk '{print substr($1,2); }' >> vars.sh
echo $CERT_NAME:${10} | awk '{print substr($1,2); }' >> vars.sh
echo $DNS_PRIVATE_ZONE_RESOURCE_GROUP_NAME:${11} | awk '{print substr($1,2); }' >> vars.sh
echo $TEMPLATE_BASE_URL:${12} | awk '{print substr($1,2); }' >> vars.sh
echo $AKV_RESOURCE_GROUP_NAME:${13} | awk '{print substr($1,2); }' >> vars.sh 
echo $FQDN_BACKEND_POOL:${14} | awk '{print substr($1,2); }' >> vars.sh 

sed -i '2s/^/export ADMIN_USER_NAME=/' vars.sh
sed -i '3s/^/export SPN_CLIENT_ID=/' vars.sh
sed -i '4s/^/export SPN_CLIENT_SECRET=/' vars.sh
sed -i '5s/^/export TENANT_ID=/' vars.sh
sed -i '6s/^/export AKS_RESOURCE_GROUP_NAME=/' vars.sh
sed -i '7s/^/export LOCATION=/' vars.sh
sed -i '8s/^/export DNS_PRIVATE_ZONE_NAME=/' vars.sh
sed -i '9s/^/export AKS_NAME=/' vars.sh
sed -i '10s/^/export AKV_NAME=/' vars.sh
sed -i '11s/^/export CERT_NAME=/' vars.sh
sed -i '12s/^/export DNS_PRIVATE_ZONE_RESOURCE_GROUP_NAME=/' vars.sh
sed -i '13s/^/export TEMPLATE_BASE_URL=/' vars.sh
sed -i '14s/^/export AKV_RESOURCE_GROUP_NAME=/' vars.sh
sed -i '15s/^/export FQDN_BACKEND_POOL=/' vars.sh

chmod +x vars.sh
. ./vars.sh
sudo mv vars.sh /etc/profile.d/vars.sh

# Creating login message of the day (motd)
sudo curl -o /etc/profile.d/welcome.sh ${TEMPLATE_BASE_URL}welcome.sh

# Download install script
sudo curl -o /home/$ADMIN_USER_NAME/install.sh ${TEMPLATE_BASE_URL}install.sh
sudo chmod +x /home/$ADMIN_USER_NAME/install.sh
sudo curl -o /home/$ADMIN_USER_NAME/external-dns.yaml ${TEMPLATE_BASE_URL}external-dns.yaml
sudo curl -o /home/$ADMIN_USER_NAME/secret-provider-class.yaml ${TEMPLATE_BASE_URL}secret-provider-class.yaml
sudo curl -o /home/$ADMIN_USER_NAME/app.yaml ${TEMPLATE_BASE_URL}app.yaml
sudo curl -o /home/$ADMIN_USER_NAME/ingress.yaml ${TEMPLATE_BASE_URL}ingress.yaml

# Syncing this script log to 'home/user/' directory for ease of troubleshooting
while sleep 1; do sudo -s rsync -a /var/lib/waagent/custom-script/download/0/download.log /home/${ADMIN_USER_NAME}/download.log; done &