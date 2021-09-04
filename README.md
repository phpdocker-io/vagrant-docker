# Vagrant docker box [wip]

Since docker desktop is becoming a paid-for product for business users on Mac and PC, this
vm is being designed as an easy way to load a bunch of services within a Vagrant box and 
expose them externally.

If you're a Linux user there's very little need for you to use this over docker directly 
on your computer. Although it will work - in fact my main desktop OS is Linux.

If you're a Windows user, same applies. Docker in WSL2 is said to work reasonably well.
I don't use Windows so I can't attest to the veracity of that statement.

This is still a work in progress.

## Requirements
 - Ansible 2
 - Vagrant 2.2
 - Virtualbox

## Permission issues in containers
**Scenario:** PHP symfony app has issues writing to the `var/` folder its logs or caches or
whatever.

**Solution:** Ensure you tweak the runtime's user in the relevant `Dockerfile` to run as user/group IDs 1000 in order 
to match the `vagrant` user on the VM which will own all files shared from the host. Examples:

```dockerfile
# In alpine images
RUN apk add --no-cache shadow; \
    usermod -u 1000 www-data; \
    groupmod -g 1000 www-data; \
    apk del shadow

# In other OS bases (debian, ubuntu, etc) \
RUN usermod -u 1000 www-data; \
    groupmod -g 1000 www-data
```

You might want to do this only on your dev container, which you can achieve by using
multi stages:

```dockerfile
FROM phpdockerio/php80-fpm AS base
# ... do some stuff common to dev & prod images

FROM base AS dev
RUN usermod -u 1000 www-data; \
    groupmod -g 1000 www-data
```

Then you can simply target that multistage on your docker-compose file:

```yaml
  php-fpm:
    build:
      dockerfile: Dockerfile
      target: dev
      context: .
```

## Services

### How services are run
Each service defined in [services.yaml](services.yaml) is set up as a supervisor program service. You can have a 
look at the [supervisor config template](ansible/templates/supervisor_program.conf.j2) to see where everything goes. 

See below for file structure.

When you define the `startup_command` make sure the command does not terminate - this is similar to docker where
you must make sure your program does not go into the background to continue execution. Supervisor (and docker) consider
the process to have died when it exits.

Examples for a docker-compose service
```yaml
definitions:
    # Good - process won't exit and docker-compose prints logs to stdout, which supervisor collects
    - startup_command: docker-compose up
 
    # Bad - process goes into background. This really upsets supervisor as it things your process terminated
    - startup_command: docker-compose up -d
```


### Services.yaml file structure
TBD

### Logs
Your services are started via supervisor. Logs are piped to `/home/vagrant/logs/supervisor-SERVICE_NAME.log` 


## FAQ
### Why not assign more than 1 CPU?
Virtualbox actually runs slower when you assign more than 1 CPU core to the box due to overheads on how it implements
multi threading. This is a very old issue and who knows if it'll ever get fixed.

### Why Virtualbox only?
Virtualbox is the only open source, multiplatform solution out there at the moment.

You're free to fork and tweak to your heart's content though - this project is MIT licensed. You could re-wire this VM 
to function in VMWARE instead, or the native hypervisor on your OS (eg windows Hyper V). Some of those hypervisors 
don't have the performance penalties Virtualbox have. 

### The vagrant box has started, but the services aren't loading on my host

Supervisor will run the `startup_command` once it starts up, but that does not mean your service is immediately
available. Check the logs for that service in `/home/vagrant/projects/logs` to see at what point of startup your service
actually is. 

It is common for a docker service to take a while to start if a docker build is necessary, especially after 
re-creating the box from scratch as there will be no cached built containers. For instance, if your service uses
the official php base image you'll probably be building a ton of dependencies from sources the first time you do
docker-compose up on a pristine vm.
