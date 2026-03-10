FROM debian:bookworm

LABEL maintainer="Bineyond <bineyond@gmail.com>" \
    org.opencontainers.image.title="SFTP Server" \
    org.opencontainers.image.description="基于 OpenSSH 的 SFTP 服务容器，支持免密登录、高级用户配置及中文日志。" \
    org.opencontainers.image.source="https://github.com/bineyond/sftp"

# Steps done in one RUN layer:
# - Install upgrades and new packages
# - OpenSSH needs /var/run/sshd to run
# - Remove generic host keys, entrypoint generates unique keys
RUN apt-get update && \
    apt-get upgrade -y && \
    DEBIAN_FRONTEND="noninteractive" apt-get -y install --no-install-recommends openssh-server acl && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /var/run/sshd && \
    rm -f /etc/ssh/ssh_host_*key*

COPY files/sshd_config /etc/ssh/sshd_config
COPY files/entrypoint /

EXPOSE 22

ENTRYPOINT ["/entrypoint"]
