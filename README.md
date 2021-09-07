# Vagrant docker box [wip]

Since docker desktop is becoming a paid-for product for business users on Mac and PC, this vm is being designed as an
easy way to load a bunch of services within a Vagrant box and expose them externally.

If you're a Linux user there's very little need for you to use this over docker directly on your computer. Although it
will work - in fact my main desktop OS is Linux.

If you're a Windows user, same applies. Docker in WSL2 is said to work reasonably well. I don't use Windows so I can't
attest to the veracity of that statement.

This is still a work in progress.

## Requirements
 - Ansible 2
 - Vagrant 2.2
 - Virtualbox

## Services

The VM can set up and autostart services checked out in [projects](projects), providing you create the (optional)
`services.yaml` file on the root of this project. You have a template you can peruse at
[services.yaml.dist](services.yaml.dist).

Your `services.yaml` file will be ignored by git.

### Services.yaml file structure

The file is composed of a list of objects named `definitions`. Each object has the following properties:

* `name` _(mandatory)_: the name of your service. Try not to use spaces and weird chars as this is used on log filenames
  and other things.
* `git_repo` _(optional)_: if provided, we'll git-clone this repo in the [projects](projects) folder at the location of
  `directory` below (if not exists).
* `directory` _(mandatory)_: where this particular service's sources are in [projects](projects). Try not to use spaces
  or weird chars here.
* `gateway` _(optional)_: if provided, we'll create an entry for this service on the gateway. This is an object with the
  following properties:
   * `hostname` _(mandatory)_: if provided, we'll create an entry on the gateway to your service, and a hosts entry on
     your host computer matching that gateway. We'll be adding `.local` automatically to your choice here.
   * `exposed_service_port` _(mandatory): which port does your app listen on? we'll connect the gateway to it
   * `is_ssl` _(optional): whether your service uses SSL
* `supervisor` _(optional)_: if provided, we'll set the app up on supervisor to have it available as a service. This is
  an object with the following properties:
   * `startup_command` _(mandatory)_: when setting up your service on the machine's supervisor, we'll use this command
     to start the service. See note in `How services are run` below for more info.
   * `autostart` _(mandatory): `true/false` whether this service must be started on boot.

**Examples:**

```yaml
definitions:
    # Docker-compose based, exposes an HTTP endpoint on port 3000. We want it exposed via the gateway. There's a
    # git repo in github for it. We want it to start on VM's boot. Service at port 3000 uses a self-signed cert
    - name: awesome-service
      git_repo: https://github.com/yay/phpdocker.io.git
      directory: awesome
      gateway:
         hostname: awesome
         exposed_service_port: 3000
         is_ssl: true
      supervisor:
         startup_command: docker-compose up
         autostart: true

    # Another docker-compose service, but it works via a Makefile. Doesn't expose any ports. We want it active on
    # boot. There's no git repo for it
    - name: yolo
      directory: awesome
      supervisor:
         startup_command: make start -e SOME_CONFIG_PARAM=yes
         autostart: true
```

### How services are run

Each service defined in `services.yaml`  is set up as a supervisor program service. You can have a look at the
[supervisor config template](ansible/roles/services/templates/supervisor_program.conf.j2) to see where everything goes.

When you define the `startup_command` make sure the command does not terminate - this is similar to docker where you
must make sure your program does not go into the background to continue execution. Supervisor (and docker) consider the
process to have died when it exits.

Examples for a docker-compose service

```yaml
definitions:
   - supervisor:
        # Good - process won't exit and docker-compose prints logs to stdout, which supervisor collects
        startup_command: docker-compose up
   - supervisor:
        # Bad - process goes into background. This really upsets supervisor as it things your process terminated
        startup_command: docker-compose up -d
```

### Connectivity

**>> 192.168.33.10 <<**

The VM is accessible on a virtual private network at the IP address above. Any ports you open on it will be available
from your host without port forwarding. Entries that are set up on your hosts file automatically all point to this IP
address as well.

For instance, if one of your services is running mysql and it exposes its 3306 port as 12000, you'll be able to connect
to it from your host at `192.168.33.10:12000`.

#### The gateway

As part of this set up, the VM creates a reverse proxy gateway (using nginx) for each service that requests it on the
`services.yaml` file, as well as hosts entries on your host computer to match and SSL certificates (more on those
certificates below). The gateway exposes ports 80 and 443 for each of those services, although all reguests to port 80
will get redirected to the https address.

If your service exposes an SSL endpoint, you must indicate `is_ssl: true` on the gateway config. It will not verify
SSL certs to allow for self-signed certificates there.

#### Certificates

To create certificates, we're using [mkcert](https://github.com/FiloSottile/mkcert). This tool does a lot of black magic
to not just generate those certificates, but it also installs a CA on your host computer so that the certificates aren't
classed as self signed on your computer's clients (like your browser, or curl), with all the troubles that implies. Have
a look at [mkcert](https://github.com/FiloSottile/mkcert) if you need more info on how it works.

All the certs are dumped within the VM at `/home/vagrant/gateway-certs` and are generated via `vagrant provision`

### Logs

Your services are started via supervisor. Logs are piped to `/home/vagrant/logs/supervisor-SERVICE_NAME.log`

## FAQ

### I've added a new service to my services.yaml, now what?

You need to run `vagrant provision`.

### Why not assign more than 1 CPU?

Virtualbox actually runs slower when you assign more than 1 CPU core to the box due to overheads on how it implements
multi threading. This is a very old issue and who knows if it'll ever get fixed.

### Why Virtualbox only?

Virtualbox is the only open source, multiplatform solution out there at the moment.

You're free to fork and tweak to your heart's content though - this project is MIT licensed. You could re-wire this VM
to function in VMWARE instead, or the native hypervisor on your OS (eg windows Hyper V). Some of those hypervisors don't
have the performance penalties Virtualbox have.

### The vagrant box has started, but the services aren't loading on my host

Supervisor will run the `startup_command` once it starts up, but that does not mean your service is immediately
available. Check the logs for that service in `/home/vagrant/projects/logs` to see at what point of startup your service
actually is.

It is common for a docker service to take a while to start if a docker build is necessary, especially after re-creating
the box from scratch as there will be no cached built containers. For instance, if your service uses the official php
base image you'll probably be building a ton of dependencies from sources the first time you do docker-compose up on a
pristine vm.

### Permission issues in containers

**Scenario:** PHP symfony app has issues writing to the `var/` folder its log files and/or caches.

**Solution:** Ensure you tweak the runtime's user in the relevant `Dockerfile` to run as user/group IDs 1000 in order to
match the `vagrant` user on the VM which will own all files shared from the host. Examples:

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
