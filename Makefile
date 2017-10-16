#
#
#
#
NAME:=montreal

DOMAIN:=montreal.de
IMAGE:=${DOCKER_USER}/${NAME}
NETWORK_OPTIONS:=--opt encrypted --attachable --driver overlay

define start_service
	$(eval STACK_NAME=${1})
	$(eval COMPOSE_FILE=${2})
	#docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} ${DOCKER_REPO}
	sed -e "s|{DOMAIN}|${DOMAIN}|g" template/${COMPOSE_FILE} > ${COMPOSE_FILE}
	sed -i -e "s|{IMAGE}|${IMAGE}|g" ${COMPOSE_FILE}
	sed -i -e "s|{IMAGE}|${IMAGE}|g" montreal.json
	docker stack rm ${STACK_NAME} || true
	docker stack deploy --with-registry-auth --prune --resolve-image changed --compose-file ${COMPOSE_FILE} ${STACK_NAME}	
	rm ${COMPOSE_FILE}
endef

define stop_service
	$(eval STACK_NAME=${1})
	docker stack rm ${STACK_NAME}
endef

start_all: create_networks create_secrets create_infrastructure start_montreal
stop_all: stop_montreal remove_infrastructure remove_secrets remove_networks


#### Preparation
create_networks:
	docker network create ${NETWORK_OPTIONS} traefik-net || true
	docker network create ${NETWORK_OPTIONS} nsq-net || true

create_secrets:
	#docker secret rm PRTG_CREDENTIALS || true
	#echo -n ${PRTG_CREDENTIALS} | docker secret create PRTG_CREDENTIALS - || true
	docker secret rm montreal.json || true
	docker secret create montreal.json montreal.json || true

create_infrastructure: 
	$(call start_service,infrastructure,infrastructure.yml)

remove_networks:
	docker network rm traefik-net || true
	docker network rm nsq-net || true

remove_secrets:
	#docker secret rm PRTG_CREDENTIALS
	docker secret rm montreal.json || true

remove_infrastructure:
	$(call stop_service,infrastructure)


#### Starting
start_montreal:
	#prtg

	#json
	$(call start_service,json,json.yml)
	#web
	#$(call start_service,web,web.yml)
	#sensor
	$(call start_service,sensor,sensor.yml)
	#nsq
	$(call start_service,nsq,nsq.yml)
	#nsqcli
	$(call start_service,nsq-cli,nsq-cli.yml)
	#nsqadmin
	$(call start_service,nsq-admin,nsq-admin.yml)

stop_montreal:
	#prtg

	#json
	$(call stop_service,json)
	#web
	#$(call stop_service,web)
	#sensor
	$(call stop_service,sensor)
	#nsq
	$(call stop_service,nsq)
	#nsqcli
	$(call stop_service,nsq-cli)
	#nsqadmin
	$(call stop_service,nsq-admin,nsq-admin.yml)

#### Testing
adapt_hosts_file:
	$(eval LOCAL_IP=$(shell hostname -i))
	printf "\
	${LOCAL_IP} ${DOMAIN}\n\
	${LOCAL_IP} traefik.${DOMAIN}\n\
	${LOCAL_IP} visualizer.${DOMAIN}\n\
	${LOCAL_IP} portainer.${DOMAIN}\n\
	${LOCAL_IP} nsqadmin.${DOMAIN}"\
	| sudo tee --append /etc/hosts

restore_hosts_file:
	sudo sed -i '/montreal.de/d' /etc/hosts
