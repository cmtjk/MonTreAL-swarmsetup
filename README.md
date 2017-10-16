### Docker Swarm Setup for [MonTreAL](https://github.com/r3r57/MonTreAL)


# IoT basic setup

#### Setup Docker swarm manager

... with encrypted overlay networks:
 - traefik-net
 - nsq-net

... and services:
- nsqadmin as webUI for NSQ to monitor it
- nsqlookupd for discovering the nsqd containers
- nsqd as messaging service

`docker node update --label-add sensortype=elv-wde <node name>`


#### Flash microSD Cards with cloud-init to automatically join the swarm

Download the flash tool from [hypriot/flash](https://github.com/hypriot/flash)

```
sudo curl -sLo /usr/local/bin/flash https://raw.githubusercontent.com/hypriot/flash/master/Linux/flash
sudo chmod +x /usr/local/bin/flash
```

Get the latest Hypriot image for rPis
[Releases](https://github.com/firecyberice/image-builder-rpi/releases)
**Note** minimum release v1.4.2

cloud-init
```
...
runcmd:
# disable ssh password login
  - sed -i -e "s|#PasswordAuthentication yes|PasswordAuthentication no|g" /etc/ssh/sshd_config
  - systemctl restart sshd.service

# join the swarm
  - docker swarm join --token <TOKEN> <SWARM MANAGER IP>:2377
...
```

Execute `flash -u cloud-init.yml -d /dev/sdc ~/Downloads/hypriotos-rpi-v1.5.1.img.zip`

