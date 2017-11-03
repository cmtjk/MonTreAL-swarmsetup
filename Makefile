#
#
#
#

start_all: create_networks create_secrets create_infrastructure start_montreal
stop_all: stop_montreal remove_infrastructure remove_secrets remove_networks

###############################################
# Flash SD-Card								  #
###############################################
# DEVICE - /dev/sdX
# HYPRIOTOS - Location of hypriotos-rpi-v*.img
USER:=cornelius
GECOS:=cornelius
HOME:=/home/cornelius
TIMESERVER:=0.de.pool.ntp.org
SWARM_TOKEN:=SWMTKN-1-3ug8esrjwyzzl814ayl9ncww7nkk853lg9t06tj8kbvfp7kbmi-9vb3azf3dloq9jdhaih4vhtzd
SWARM_LEADER_IP:=192.168.178.37:2377

flash_sd:
	-sed -e "s|{USER}|${USER}|g" cloud-init.template.yml > cloud-init.yml
	-sed -i -e "s|{GECOS}|${GECOS}|g" cloud-init.yml
	-sed -i -e "s|{HOME}|${HOME}|g" cloud-init.yml
	-sed -i -e "s|{TIMESERVER}|${TIMESERVER}|g" cloud-init.yml
	-sed -i -e "s|{SWARM_TOKEN}|${SWARM_TOKEN}|g" cloud-init.yml
	-sed -i -e "s|{SWARM_LEADER_IP}|${SWARM_LEADER_IP}|g" cloud-init.yml
	-curl -sLo ./flash https://raw.githubusercontent.com/hypriot/flash/master/Linux/flash
	-chmod +x ./flash
	-./flash -u cloud-init.yml -d ${DEVICE} ${HYPRIOTOS}
	-rm -f ./flash ./cloud-init.yml


###############################################
# Configuration                               #
###############################################
DOCKER_USER:=r3r57
NAME:=montreal
DOMAIN:=montreal.de
IMAGE:=${DOCKER_USER}/${NAME}
NETWORK_OPTIONS:=--opt encrypted --attachable --driver overlay
DIRECTORIES=influxdb chronograf grafana

###############################################
# Utility Functions		              				  #
###############################################
define start_service
	$(eval STACK_NAME=${1})
	$(eval COMPOSE_FILE=${2})
	#docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} ${DOCKER_REPO}
	sed -e "s|{DOMAIN}|${DOMAIN}|g" templates/${COMPOSE_FILE} > ${COMPOSE_FILE}
	sed -i -e "s|{IMAGE}|${IMAGE}|g" ${COMPOSE_FILE}
	docker stack rm ${STACK_NAME} || true
	docker stack deploy --with-registry-auth --prune --resolve-image never --compose-file ${COMPOSE_FILE} ${STACK_NAME}
	rm ${COMPOSE_FILE}
endef

define stop_service
	$(eval STACK_NAME=${1})
	docker stack rm ${STACK_NAME}
endef

###############################################
# Start/Stop Environment	           				  #
###############################################
start_environment: create_directories create_networks create_secrets create_infrastructure
stop_environment: remove_infrastructure remove_secrets remove_networks

create_directories:
	-mkdir -p data && cd data && mkdir ${DIRECTORIES} && cd ..

create_networks:
	-docker network create ${NETWORK_OPTIONS} traefik-net
	-docker network create ${NETWORK_OPTIONS} nsq-net
	-docker network create ${NETWORK_OPTIONS} dummy
	-docker network create ${NETWORK_OPTIONS} influxdb-net

create_secrets:
	-sed -i -e "s|{IMAGE}|${IMAGE}|g" montreal.json
	-docker secret create montreal.json montreal.json

create_infrastructure:
	$(call start_service,infrastructure,infrastructure.yml)

remove_directories:
	-rm -rf data

remove_networks:
	-docker network rm traefik-net
	-docker network rm nsq-net
	-docker network rm dummy
	-docker network rm influxdb-net

remove_secrets:
	-docker secret rm montreal.json

remove_infrastructure:
	$(call stop_service,infrastructure)


###############################################
# Start/Stop MonTreAL	    			          	  #
###############################################
start_montreal:
	#nsq
	$(call start_service,nsq,nsq.yml)
	#nsqcli
	$(call start_service,nsq-cli,nsq-cli.yml)
	#nsqadmin
	$(call start_service,nsq-admin,nsq-admin.yml)
	#memcached
	$(call start_service,memcached,memcached.yml)
	#influxdb
	$(call start_service,influxdb,influxdb.yml)
	#chronograf
	$(call start_service,chronograf,chronograf.yml)
	#grafana
	$(call start_service,grafana,grafana.yml)
	#raw memcache writer
	$(call start_service,raw-memcache-writer,raw-memcache-writer.yml)
	#influxdb writer
	$(call start_service,influxdb-writer,influxdb-writer.yml)

	#sensor
	$(call start_service,sensor,sensor.yml)

stop_montreal:
	#nsq
	$(call stop_service,nsq)
	#nsqcli
	$(call stop_service,nsq-cli)
	#nsqadmin
	$(call stop_service,nsq-admin)
	#memcached
	$(call stop_service,memcached)
	#influxdb
	$(call stop_service,influxdb)
	#chornograf
	$(call stop_service,chronograf)
	#chornograf
	$(call stop_service,grafana)
	#raw memcache writer
	$(call stop_service,raw-memcache-writer)
	#influxdb writer
	$(call stop_service,influxdb-writer)

	#sensor
	$(call stop_service,sensor)


###############################################
# For Testing Purposes	            				  #
###############################################
adapt_hosts_file:
	$(eval LOCAL_IP=$(shell hostname -i))
	printf "\
	${LOCAL_IP} ${DOMAIN}\n\
	${LOCAL_IP} traefik.${DOMAIN}\n\
	${LOCAL_IP} visualizer.${DOMAIN}\n\
	${LOCAL_IP} portainer.${DOMAIN}\n\
	${LOCAL_IP} nsqadmin.${DOMAIN}\n\
	${LOCAL_IP} grafana.${DOMAIN}\n\
	${LOCAL_IP} chronograf.${DOMAIN}"\
	| sudo tee --append /etc/hosts

restore_hosts_file:
	sudo sed -i '/${DOMAIN}/d' /etc/hosts
