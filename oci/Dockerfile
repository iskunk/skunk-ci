# oci/Dockerfile

FROM debian:unstable

LABEL maintainer="team@xtradeb.net"

ENV LANG=C.UTF-8 LC_COLLATE=C

ARG APT_MIRROR=NONE REG_UID=1000

# Do all setup in an external script, to keep the layer count down
RUN --mount=type=bind,source=setup.sh,target=/tmp/setup.sh \
	sh /tmp/setup.sh

USER user
WORKDIR /home/user
CMD ["/bin/bash"]

# end oci/Dockerfile
