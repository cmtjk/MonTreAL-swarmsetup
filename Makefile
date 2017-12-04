start_all: start_environment start_montreal
stop_all: stop_montreal stop_environment

###############################################
# Configuration                               #
###############################################
DOCKER_USER:=r3r57
NAME:=montreal
VERSION:=latest-multiarch
DOMAIN:=montreal.de
IMAGE:=${DOCKER_USER}/${NAME}:${VERSION}
NETWORK_OPTIONS:=--opt encrypted --attachable --driver overlay
DIRECTORIES=influxdb chronograf grafana prometheus

###############################################
# Utility Functions                           #
###############################################
define start_service
	$(eval STACK_NAME=${1})
	$(eval COMPOSE_FILE=${2})
	@#docker login -u ${DOCKER_USER} -p ${DOCKER_PASS} ${DOCKER_REPO}
	@sed -e "s|{DOMAIN}|${DOMAIN}|g" templates/${COMPOSE_FILE} > ${COMPOSE_FILE}
	@sed -i -e "s|{IMAGE}|${IMAGE}|g" ${COMPOSE_FILE}
	@docker stack rm ${STACK_NAME} 2> /dev/null || true
	@docker stack deploy --with-registry-auth --prune --resolve-image never --compose-file ${COMPOSE_FILE} ${STACK_NAME}
	@rm ${COMPOSE_FILE}
endef

define stop_service
	$(eval STACK_NAME=${1})
	@echo ${STACK_NAME}
	@docker stack rm ${STACK_NAME} 2> /dev/null
endef

###############################################
# Start/Stop Environment                      #
###############################################
start_environment: create_directories create_networks create_secrets create_infrastructure
stop_environment: remove_infrastructure remove_secrets remove_networks

create_directories:
	$(foreach dir, ${DIRECTORIES}, mkdir -pv data/${dir};)
	-@echo Changing permissions... this might be a potential issue!
	-chmod 757 data/prometheus

create_networks:
	-@docker network create ${NETWORK_OPTIONS} traefik-net
	-@docker network create ${NETWORK_OPTIONS} nsq-net
	-@docker network create ${NETWORK_OPTIONS} dummy
	-@docker network create ${NETWORK_OPTIONS} influxdb-net
	-@docker network create ${NETWORK_OPTIONS} prometheus-net
	-@docker network create ${NETWORK_OPTIONS} memcache-net
	-@docker network ls -f scope=swarm

create_secrets:
	-@docker secret create montreal.json config/montreal.json
	-@docker secret create prometheus.yml config/prometheus/prometheus.yml
	-@docker secret create grafana.ini config/grafana/grafana.ini
	-@docker secret ls

create_infrastructure:
	$(call start_service,infrastructure,infrastructure.yml)

remove_directories:
	-@rm -rf data

remove_networks:
	-@docker network rm traefik-net
	-@docker network rm nsq-net
	-@docker network rm dummy
	-@docker network rm influxdb-net
	-@docker network rm prometheus-net
	-@docker network rm memcache-net

remove_secrets:
	-@docker secret rm montreal.json
	-@docker secret rm prometheus.yml
	-@docker secret rm grafana.ini

remove_infrastructure:
	$(call stop_service,infrastructure)


###############################################
# Start/Stop MonTreAL                         #
###############################################
start_montreal:
	-@echo Starting independend services...
	@#nsq
	$(call start_service,nsq,nsq.yml)
	@#memcached
	$(call start_service,memcached,memcached.yml)
	@#influxdb
	$(call start_service,influxdb,influxdb.yml)
	@#prometheus
	$(call start_service,prometheus,prometheus.yml)

	-@echo Waiting 15 seconds for services to start...
	-@sleep 15

	-@echo Starting dependend services...
	@#nsqcli
	$(call start_service,nsq-cli,nsq-cli.yml)
	@#nsqadmin
	$(call start_service,nsq-admin,nsq-admin.yml)
	@#chronograf
	$(call start_service,chronograf,chronograf.yml)
	@#grafana
	$(call start_service,grafana,grafana.yml)
	@#sensor data memcache writer
	$(call start_service,sensor-data-memcache-writer,sensor-data-memcache-writer.yml)
	@#influxdb writer
	$(call start_service,influxdb-writer,influxdb-writer.yml)
	@#prometheus writer
	$(call start_service,prometheus-writer,prometheus-writer.yml)
	@#rest
	$(call start_service,rest,rest.yml)
	@#sensor list memcache writer
	$(call start_service,sensor-list-memcache-writer,sensor-list-memcache-writer.yml)

	@#local manager
	$(call start_service,local-manager,local-manager.yml)

stop_montreal:
	-@echo Shutting down dependend services...
	@#local manager
	$(call stop_service,local-manager)
	@#nsqcli
	$(call stop_service,nsq-cli)
	@#nsqadmin
	$(call stop_service,nsq-admin)
	@#chornograf
	$(call stop_service,chronograf)
	@#chornograf
	$(call stop_service,grafana)
	@#sensor data memcache writer
	$(call stop_service,sensor-data-memcache-writer)
	@#influxdb writer
	$(call stop_service,influxdb-writer)
	@#prometheus writer
	$(call stop_service,prometheus-writer)
	@#rest
	$(call stop_service,rest)
	@#sensor list memcache writer
	$(call stop_service,sensor-list-memcache-writer)

	-@echo Waiting 15 seconds for threads to finish...
	-@sleep 15

	-@echo Shutting down independend services...
	@#memcached
	$(call stop_service,memcached)
	@#influxdb
	$(call stop_service,influxdb)
	@#prometheus
	$(call stop_service,prometheus)
	@#nsq
	$(call stop_service,nsq)

###############################################
# For Testing Purposes                        #
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
	${LOCAL_IP} prometheus.${DOMAIN}\n\
	${LOCAL_IP} chronograf.${DOMAIN}\n\
	${LOCAL_IP} rest.${DOMAIN}"\
	| sudo tee --append /etc/hosts

restore_hosts_file:
	sudo sed -i '/${DOMAIN}/d' /etc/hosts
