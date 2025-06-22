# oci/Makefile

IMAGE     = build-env
CONTAINER = $(IMAGE)-con
HOSTNAME := $(shell hostname -s)
TOP      := $(shell cd .. && pwd)
DOCKER    = docker

APT_MIRROR   =
REG_UID      =
IMAGE_SOURCE =

VOL_MOUNTS = \
	-v $(TOP):/external/src:ro \
	--tmpfs=/external/tmp:exec

ifdef SCRATCH
export TMPDIR = $(SCRATCH)
endif

build_stamp = $(IMAGE).$(HOSTNAME).stamp

run: $(build_stamp)
	@if $(DOCKER) container inspect $(CONTAINER) >/dev/null 2>&1; then \
		set -x; \
		$(DOCKER) container exec -it $(CONTAINER) /bin/bash; \
	else \
		set -x; \
		$(DOCKER) container run -it --rm \
			--name=$(CONTAINER) \
			--hostname=$(CONTAINER) \
			--pids-limit -1 \
			--cap-add=SYS_ADMIN \
			--cap-add=SYS_PTRACE \
			$(VOL_MOUNTS) \
			$(IMAGE); \
	fi

build: $(build_stamp)

$(build_stamp): Dockerfile
	$(DOCKER) build \
		$(if $(APT_MIRROR),--build-arg APT_MIRROR=$(APT_MIRROR)) \
		$(if $(REG_UID),--build-arg REG_UID=$(REG_UID)) \
		$(if $(IMAGE_SOURCE),--label org.opencontainers.image.source=$(IMAGE_SOURCE)) \
		--tag $(IMAGE) \
		.
#	$(DOCKER) container run --rm $(IMAGE) true
	touch $@

clean:
	-$(DOCKER) image rm $(IMAGE)
	rm -f $(build_stamp)

# end oci/Makefile
