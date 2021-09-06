SHELL=/bin/bash
MKCERT_VERSION=v1.4.3
MKCERT_LOCATION=bin/mkcert
HOSTS_VERSION=3.6.4
HOSTS_LOCATION=bin/hosts

# linux-amd64, darwin-amd64, linux-arm
# On windows, override with windows-amd64.exe
ifndef BINARY_SUFFIX
	BINARY_SUFFIX:=$(shell [[ "`uname -s`" == "Linux" ]] && echo linux || echo darwin)-amd64
endif

install-mkcert:
	@echo "Installing mkcert for OS type ${BINARY_SUFFIX}"
	@if [[ ! -f '$(MKCERT_LOCATION)' ]]; then curl -sL 'https://github.com/FiloSottile/mkcert/releases/download/$(MKCERT_VERSION)/mkcert-$(MKCERT_VERSION)-$(BINARY_SUFFIX)' -o $(MKCERT_LOCATION); chmod +x $(MKCERT_LOCATION);	fi;
	bin/mkcert -install

create-certs:
	bin/mkcert -cert-file=traefik/certs/localhost.pem -key-file=traefik/certs/localhost-key.pem *.local

install-hosts:
	@echo "Installing hosts script"
	@if [[ ! -f '$(HOSTS_LOCATION)' ]]; then curl -sL 'https://raw.githubusercontent.com/xwmx/hosts/$(HOSTS_VERSION)/hosts' -o $(HOSTS_LOCATION); chmod +x $(HOSTS_LOCATION);	fi;

clean-hosts:
	sudo bin/hosts remove --force *$(SITE_HOST) > /dev/null 2>&1 || exit 0

init-hosts: clean-hosts
	sudo bin/hosts add 127.0.0.1 $(SITE_HOST)
