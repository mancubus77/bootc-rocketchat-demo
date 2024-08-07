### Based on
### https://www.redhat.com/en/blog/image-mode-red-hat-enterprise-linux-quick-start-guide

TAG_BASE ?= base

# VER ?= 6.9.1
VER ?= 6.7.7
# VER=latest
BASE = $$(pwd)
VM_NAME ?= rocketchat
REGISTRY ?= quay.io
APP_IMAGE ?= bootc
APP_TAG ?= app_${VER}
TYPE ?= qcow2

build-registry:
	sudo mkdir -p /opt/registry/{auth,certs,data}
	sudo htpasswd -bBc /opt/registry/auth/htpasswd admin admin
	sudo openssl req -newkey rsa:4096 -nodes -sha256 -keyout /opt/registry/certs/domain.key -x509 -days 365 -out /opt/registry/certs/domain.crt
	sudo cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
	sudo update-ca-trust
	sudo podman run --name myregistry \
		-p 5000:5000 \
		-v /opt/registry/data:/var/lib/registry:z \
		-v /opt/registry/auth:/auth:z \
		-e "REGISTRY_AUTH=htpasswd" \
		-e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
		-e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
		-v /opt/registry/certs:/certs:z \
		-e "REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt" \
		-e "REGISTRY_HTTP_TLS_KEY=/certs/domain.key" \
		-e REGISTRY_COMPATIBILITY_SCHEMA1_ENABLED=true \
		-d \
		docker.io/library/registry:latest
	sudo podman login --tls-verify=false localhost:5050
	podman login --tls-verify=false localhost:5050

build-base:
	podman build -f Containerfile.base --no-cache -t ${REGISTRY}/mancubus77/bootc:${TAG_BASE}

push-base:
	podman push ${REGISTRY}/mancubus77/bootc:${TAG_BASE}

build-app:
	# Building with cache doesn't allow to modify images. Better to build if from scratch
	podman build -f Containerfile.app.rocketchat --no-cache -t ${REGISTRY}/mancubus77/${APP_IMAGE}:${APP_TAG} --build-arg VER=${VER}
	# You need this, because images not shared between host users
	podman save ${REGISTRY}/mancubus77/${APP_IMAGE}:${APP_TAG} > /tmp/img.gz
	sudo podman load < /tmp/img.gz

push-app:
	podman push ${REGISTRY}/mancubus77/${APP_IMAGE}:${APP_TAG}

build-image:
	sudo podman run --rm -it --privileged \
	-v ./build_artifacts:/output \
	-v ${BASE}/config.json:/config.json \
	-v /var/lib/containers/storage:/var/lib/containers/storage \
	registry.redhat.io/rhel9/bootc-image-builder:9.4 \
	--type ${TYPE} \
	--config /config.json \
	--chown 107 \
	--log-level debug \
	--tls-verify=false \
	--local \
	${REGISTRY}/mancubus77/${APP_IMAGE}:${APP_TAG}
	# --pull newer ## To pull new builder image all the time
	# --add-host=reg:192.168.200.200 ## Use local registry

run-vm:
	sudo cp build_artifacts/qcow2/disk.qcow2 /var/lib/libvirt/images/${VM_NAME}.qcow2
	sudo virt-install \
 	--name ${VM_NAME} \
 	--memory 4096 \
 	--vcpus 2 \
	--network=bridge:virbr0 \
 	--disk /var/lib/libvirt/images/${VM_NAME}.qcow2 \
	--disk /var/lib/libvirt/images/${VM_NAME}_extra.qcow2,size=20 \
 	--import \
 	--os-variant rhel9.4 \
	--noautoconsole

rm-vm:
	sudo virsh destroy ${VM_NAME}
	sudo virsh undefine ${VM_NAME}

get-vm-ip:
	@sudo virsh -q net-dhcp-leases default --mac 52:54:00:00:00:01 | grep ipv4 | awk '{print $$5}' | cut -d/ -f 1