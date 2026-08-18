FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        qemu-system-x86 \
        qemu-utils \
        cloud-image-utils \
        genisoimage \
        openssh-client \
        curl \
        ca-certificates \
        netcat-openbsd \
        python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab

COPY cloud-init/ /lab/cloud-init/
COPY lab-poc/ /lab/lab-poc/
COPY scripts/entrypoint.sh /lab/entrypoint.sh
COPY scripts/wait-ssh.sh /lab/wait-ssh.sh

RUN chmod +x /lab/entrypoint.sh /lab/wait-ssh.sh

# Image will be downloaded / mounted at runtime under /lab/images
VOLUME ["/lab/images"]

EXPOSE 2222

ENTRYPOINT ["/lab/entrypoint.sh"]
