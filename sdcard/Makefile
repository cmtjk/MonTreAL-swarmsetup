HYPRIOTOS=./hypriotos-rpi-v1.5.1.img.zip
DEVICE=/dev/sda

HOSTNAME:=montreal-device-2
USER:=montreal
GECOS:=montreal
HOME:=/home/montreal
TIMESERVER:=0.de.pool.ntp.org
SWARM_TOKEN:=SWMTKN-1-1k7oln5uiu72ugqmgggdvxgjz2hlwgy4ngwcqu6xe29v0a9p52-1w83k95uvzcoodsrakldzhowk
SWARM_LEADER_IP:=192.168.178.25:2377
DEVICE_ID:=L9WDev2
BUILDING:=L9
ROOM:=Wohnzimmer
ARCHITECTURE:="arm"

flash_sd:
	-sed -e "s|{USER}|${USER}|g" sdcard/cloud-init.template.yml > cloud-init.yml
	-sed -i -e "s|{GECOS}|${GECOS}|g" cloud-init.yml
	-sed -i -e "s|{HOME}|${HOME}|g" cloud-init.yml
	-sed -i -e "s|{HOSTNAME}|${HOSTNAME}|g" cloud-init.yml
	-sed -i -e "s|{TIMESERVER}|${TIMESERVER}|g" cloud-init.yml
	-sed -i -e "s|{SWARM_TOKEN}|${SWARM_TOKEN}|g" cloud-init.yml
	-sed -i -e "s|{SWARM_LEADER_IP}|${SWARM_LEADER_IP}|g" cloud-init.yml
	-sed -i -e "s|{DEVICE_ID}|${DEVICE_ID}|g" cloud-init.yml
	-sed -i -e "s|{BUILDING}|${BUILDING}|g" cloud-init.yml
	-sed -i -e "s|{ROOM}|${ROOM}|g" cloud-init.yml
	-sed -i -e "s|{ARCHITECTURE}|${ARCHITECTURE}|g" cloud-init.yml
	-curl -sLo ./flash https://raw.githubusercontent.com/hypriot/flash/master/Linux/flash
	-chmod +x ./flash
	-./flash -u cloud-init.yml -d ${DEVICE} ${HYPRIOTOS}
	-rm -f ./flash ./cloud-init.yml
