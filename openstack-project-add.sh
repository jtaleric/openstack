#!/bin/sh

if [ $# -eq 0 ]
then
	echo " Usage: `basename $0` Project#"
	exit 2
fi

#variables
	
id=$1
tenant=Tenant #Client
project=Customer

###begin
create_project(){
keystone tenant-create --name=$project$id --description $tenant$id
}

create_admin_user(){
if ! [ -f /usr/bin/pwmake ]
then 
	echo " WARN: /usr/bin/pwmake not found. Pls install libpwquality"
	exit 1
fi
password=`pwmake 4`
keystone user-create --name=c$id --pass=$password --email=admin@localhost --tenant $project$id
echo " INFO: admin user (c$id) for $project$id has password $password"
echo " ToDo: should be emailed instead"
}

assign_role_to_user(){
keystone user-role-add --user c$id --role admin$id --tenant $project$id
}

create_admin_role(){
keystone role-create --name admin$id
}

create_networks(){

neutron router-create router$id
neutron net-create int_lan_$id
CIDR=`neutron subnet-list | awk '{print $6}'| grep ^10. | cut -d/ -f1`
	echo DEBUG CIDR=$CIDR
if [ "$CIDR" == "" ]
then
	echo "WARN: CIDR 10.x.x.x not found. Is this a new install?"
	CIDR=10.0.0.0
	echo DEBUG CIDR=$CIDR
fi
CIDR2=`echo $CIDR| cut -d. -f2`
CIDR3=`echo $CIDR| cut -d. -f3`
if [ $CIDR3 -eq 255 ]
then
	if [ $CIDR2 -eq	255 ]
	then
		echo " INFO: NICE! you are out of networks!"
		exit 3
	else
		CIDR2=`expr $CIDR2 + 1`
	fi
else
	CIDR3=`expr $CIDR3 + 1`
fi

CIDR=10.$CIDR2.$CIDR3.0
echo CIDR=$CIDR

neutron subnet-create int_lan_$id $CIDR/24 --name subnet$id
neutron router-interface-add router$id subnet$id

neutron router-gateway-set router$id PublicLAN
}

commented(){
###attaching a public subnet ###supposedly previously created
neutron net-show PublicLAN > /dev/null
if [ $? -eq 1 ]
then
	echo "WARN: PublicLAN not found"
	exit 4
fi
neutron net-create PublicLAN --router:external=True
#neutron subnet-create PublicLAN --allocation-pool start=192.168.0.129,end=192.168.0.140 --disable-dhcp --dns-nameserver 8.8.8.8 --gateway 192.168.0.1 --name PublicLAN 192.168.0.0/24
#neutron subnet-create PublicLAN --allocation-pool start=192.168.0.130,end=192.168.0.190 --gateway 192.168.0.1 192.168.0.0/24 -- --enable_dhcp=False
neutron subnet-create PublicLAN 192.168.0.128/25 --name PublicLAN --enable_dhcp=False --allocation-pool start=192.168.0.129,end=192.168.0.140 --gateway=192.168.0.1
neutron router-gateway-set router1 PublicLAN
}

tear_down(){
#neutron floatingip-delete <floatingip-id> 

neutron router-gateway-clear router$id
neutron router-interface-delete router$id subnet$id
neutron router-delete router$id
}

###main
create_project
create_admin_role
create_admin_user
assign_role_to_user

create_networks