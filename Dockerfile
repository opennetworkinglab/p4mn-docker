FROM ubuntu:18.04

LABEL maintainer="Carmelo Cascone <carmelo@opennetworking.org>"
LABEL description="P4Runtime-enabled Mininet that uses BMv2 simple_switch_grpc as the default switch"

# Mininet custom switch class for BMv2.
COPY bmv2.py /bmv2.py

# Install BMv2, PI, etc. and dependencies.
ENV P4LANG_PKGS p4lang-3rd-party p4lang-bionic
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:frederic-loui/p4lang-bionic && \
    add-apt-repository -y ppa:frederic-loui/p4lang-3rd-party && \
    apt-get update && \
    echo "America/Los_Angeles" | tee /etc/timezone && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends $P4LANG_PKGS && \
    apt-get remove -y software-properties-common && \
    apt-get clean && apt-get -y autoremove && \
    rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Mininet runtime dependencies.
ENV MN_RUN_PKGS iproute2 \
                iputils-ping \
                net-tools \
                ethtool \
                socat \
                psmisc \
                iperf \
                telnet \
                python-pexpect \
                python-setuptools \
                tcpdump
RUN apt-get update && \
    apt-get install -y --no-install-recommends $MN_RUN_PKGS && \
    rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Install Mininet.
ENV MN_INSTALL_PKGS wget unzip gcc help2man
RUN apt-get update && \
    apt-get install -y --no-install-recommends $MN_INSTALL_PKGS && \
    wget https://github.com/mininet/mininet/archive/master.zip && \
    unzip master.zip && cd mininet-master && make install && \
    cd .. && rm -rf mininet-master master.zip && \
    apt-get remove -y $MN_INSTALL_PKGS && apt-get -y autoremove && \
    rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Expose one port per switch (gRPC server), hence the number of exposed ports
# limit the number of switches that can be controlled from an external P4Runtime
# controller.
EXPOSE 50001-50999
ENTRYPOINT ["mn", "--custom", "bmv2.py", "--switch", "ss_grpc", "--controller", "none"]