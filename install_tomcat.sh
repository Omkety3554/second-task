#!/bin/sh
sudo apt update -y
sudo apt install openjdk-11-jdk -y
sudo apt-get install tomcat9 tomcat9-docs tomcat9-admin -y
sudo cp -r /usr/share/tomcat9-admin/* /var/lib/tomcat9/webapps/ -v
sudo chmod 777 /var/lib/tomcat9/conf/tomcat-users.xml
sudo cat <<EOF >> /var/lib/tomcat9/conf/tomcat-users.xml
<role rolename="manager-script"/>
<user username="tomcat" password="password" roles="manager-script"/>
<role rolename="admin-gui"/>
<role rolename="manager-gui"/>
<user username="admin" password="admin" roles="admin-gui,manager-gui"/>
</tomcat-users>
EOF
sudo sed -i '44d' /var/lib/tomcat9/conf/tomcat-users.xml
echo 'clearing screen...' && sleep 5
clear
echo 'tomcat is installed'
sudo systemctl restart tomcat9