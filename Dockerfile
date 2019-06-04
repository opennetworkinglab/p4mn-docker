FROM debian:stretch-slim

LABEL maintainer="Carmelo Cascone <carmelo@opennetworking.org>"
LABEL description="P4Runtime-enabled Mininet that uses BMv2 simple_switch_grpc as the default switch"

ENV GRPC_RELEASE_TAG v1.19.x
ENV PI_COMMIT 9f6c1f2
ENV BMV2_COMMIT 8c6f852

ENV PKG_DEPS \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    curl \
    g++ \
    git \
    help2man \
    libtool \
    make \
    pkg-config \
    python \
    python-dev \
    python-pip \
    python-setuptools \
    unzip
RUN apt-get update && apt-get install -y --no-install-recommends $PKG_DEPS && \
    apt-get clean

# Install protobuf first, then grpc.
RUN git clone --depth 1 --single-branch --branch $GRPC_RELEASE_TAG \
    https://github.com/grpc/grpc.git /tmp/grpc && \
    cd /tmp/grpc && \
    git submodule update --init --recursive && \
    echo "--- installing protobuf ---" && \
    cd third_party/protobuf && \
    ./autogen.sh && ./configure --enable-shared && \
    make -j$(nproc) && make install && ldconfig && \
    cd python && python setup.py build --cpp_implementation && pip install . && \
    echo "--- installing grpc ---" && \
    cd /tmp/grpc && \
    make -j$(nproc) && make install && ldconfig && \
    pip install -r requirements.txt && pip install . && \
    rm -rf ~/.cache/pip && rm -rf /tmp/grpc

ENV BMV2_PI_DEPS \
    libboost-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-test-dev \
    libboost-thread-dev \
    libevent-dev \
    libgmp-dev \
    libjudy-dev \
    libpcap-dev \
    libssl-dev
RUN apt-get update && apt-get install -y --no-install-recommends $BMV2_PI_DEPS && \
    apt-get clean

RUN git clone https://github.com/p4lang/PI.git /tmp/PI && \
    cd /tmp/PI && git checkout $PI_COMMIT && \
    git submodule update --init --recursive && \
    ./autogen.sh && ./configure --with-proto && \
    make -j$(nproc) && make install && ldconfig && \
    rm -rf /tmp/PI

RUN git clone https://github.com/p4lang/behavioral-model.git /tmp/bmv2 && \
    cd /tmp/bmv2 && git checkout $BMV2_COMMIT && \
    ./autogen.sh && \
    ./configure --with-pi --disable-elogger --without-nanomsg --without-targets \
        --without-thrift \
        CPPFLAGS="-I$PWD/targets/simple_switch -DWITH_SIMPLE_SWITCH" && \
    make -j$(nproc) && make install && ldconfig && \
    cd targets/simple_switch && make -j$(nproc) && make install && ldconfig && \
    cd ../simple_switch_grpc && ./autogen.sh && ./configure && \
    make -j$(nproc) && make install && ldconfig && \
    rm -rf /tmp/bmv2


# Mininet runtime dependencies.
ENV MN_RUN_PKGS iproute2 \
                iputils-ping \
                net-tools \
                ethtool \
                socat \
                psmisc \
                procps \
                iperf \
                telnet \
                python-pexpect \
                tcpdump
RUN apt-get update && \
    apt-get install -y --no-install-recommends $MN_RUN_PKGS && \
    rm -rf /var/cache/apt/* /var/lib/apt/lists/*

# Install Mininet.
RUN git clone https://github.com/mininet/mininet.git /tmp/mininet && \
    cd /tmp/mininet && make install && \
    rm -rf /tmp/mininet

# Expose one port per switch (gRPC server), hence the number of exposed ports
# limit the number of switches that can be controlled from an external P4Runtime
# controller.
COPY bmv2.py /bmv2.py
EXPOSE 50001-50999
ENTRYPOINT ["mn", "--custom", "/bmv2.py", "--switch", "ss_grpc", "--controller", "none"]