ARG GRPC_VER=1.19.1
ARG PI_COMMIT=9f6c1f2
ARG BMV2_COMMIT=8c6f852
ARG BMV2_CONFIG_FLAGS="--with-pi --disable-elogger --without-nanomsg --without-thrift"
ARG PI_CONFIG_FLAGS="--with-proto"
ARG JOBS=2

# We use a 2-stage build. Build everything then copy only the strict necessary
# to a new image with runtime dependencies.
FROM bitnami/minideb:stretch as builder

ENV BUILD_DEPS \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    curl \
    g++ \
    git \
    help2man \
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
    libssl-dev \
    libtool \
    make \
    pkg-config \
    python \
    python-dev \
    python-pip \
    python-setuptools \
    unzip
RUN install_packages $BUILD_DEPS

ARG GRPC_VER
ARG JOBS

# Install protobuf and grpc.
RUN git clone https://github.com/grpc/grpc.git /tmp/grpc && \
    cd /tmp/grpc && git fetch --tags && git checkout v$GRPC_VER
WORKDIR /tmp/grpc
RUN git submodule update --init --recursive

WORKDIR third_party/protobuf
RUN ./autogen.sh
RUN ./configure --enable-shared
RUN make -j$JOBS
RUN make install-strip
RUN ldconfig

WORKDIR /tmp/grpc
RUN make -j$JOBS
RUN make install
RUN ldconfig

ARG PI_COMMIT
ARG PI_CONFIG_FLAGS

# Build PI
RUN git clone https://github.com/p4lang/PI.git /tmp/PI && \
    cd /tmp/PI && git checkout ${PI_COMMIT}
WORKDIR /tmp/PI
RUN git submodule update --init --recursive
RUN ./autogen.sh
RUN ./configure $PI_CONFIG_FLAGS
RUN make -j${JOBS}
RUN make install
RUN ldconfig

ARG BMV2_COMMIT
ARG BMV2_CONFIG_FLAGS

# Build simple_switch
RUN git clone https://github.com/p4lang/behavioral-model.git /tmp/bmv2 && \
    cd /tmp/bmv2 && git checkout ${BMV2_COMMIT}
WORKDIR /tmp/bmv2
RUN ./autogen.sh
# Build only simple_switch and simple_switch_grpc
RUN ./configure $BMV2_CONFIG_FLAGS \
    --without-targets CPPFLAGS="-I${PWD}/targets/simple_switch -DWITH_SIMPLE_SWITCH"
RUN make -j${JOBS}
RUN make install
RUN ldconfig

WORKDIR /tmp/bmv2/targets/simple_switch
RUN make -j${JOBS}
RUN make install
RUN ldconfig

WORKDIR /tmp/bmv2/targets/simple_switch_grpc
RUN ./autogen.sh
RUN ./configure
RUN make -j${JOBS}
RUN make install
RUN ldconfig

# Build Mininet
RUN mkdir /tmp/mininet
WORKDIR /tmp/mininet
RUN curl -L https://github.com/mininet/mininet/tarball/master | \
    tar xz --strip-components 1
# Install in a special directory that we will copy to the runtime image.
RUN mkdir -p /output
RUN PREFIX=/output make install-mnexec install-manpages
RUN python setup.py install --root /output

# From `ldd /usr/local/bin/simple_switch_grpc`, we put aside just the strict
# necessary to run simple_switch_grpc, i.e. the binary and some (not all) of the
# shared objects we just built. Other shared objects (such as boost) will be
# installed via apt-get.
RUN mkdir -p /output/usr/local/bin
RUN mkdir -p /output/usr/local/lib

RUN cp --parents /usr/local/bin/simple_switch_grpc /output

# protobuf
RUN cp --parents --preserve=links /usr/local/lib/libprotobuf.so.* /output
# grpc
RUN cp --parents --preserve=links /usr/local/lib/libgpr.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libgrpc++.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libgrpc++_reflection.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libgrpc.so.* /output
# PI
RUN cp --parents --preserve=links /usr/local/lib/libpi.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libpiconvertproto.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libpifecpp.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libpifeproto.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libpigrpcserver.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libpip4info.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libpiprotobuf.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libpiprotogrpc.so.* /output
# BMv2
RUN cp --parents --preserve=links /usr/local/lib/libbm_grpc_dataplane.so.* /output
RUN cp --parents --preserve=links /usr/local/lib/libbmpi.so.* /output

# Final stage, runtime.
FROM bitnami/minideb:stretch as runtime

LABEL maintainer="Carmelo Cascone <carmelo@opennetworking.org>"
LABEL description="P4Runtime-enabled Mininet that uses BMv2 simple_switch_grpc as the default switch"

# Mininet and BMv2 simple_switch runtime dependencies
ENV RUNTIME_DEPS \
    iproute2 \
    iputils-ping \
    net-tools \
    ethtool \
    socat \
    psmisc \
    procps \
    iperf \
    telnet \
    python-pexpect \
    tcpdump \
    libboost-filesystem1.62.0 \
    libboost-program-options1.62.0 \
    libboost-thread1.62.0 \
    libjudydebian1 \
    libgmp10 \
    libpcap0.8
RUN install_packages $RUNTIME_DEPS

COPY --from=builder /output /
RUN ldconfig
ENV PYTHONPATH "${PYTHONPATH}:/usr/lib/python2.7/site-packages/"

WORKDIR /root
COPY bmv2.py .

# Expose one port per switch (gRPC server), hence the number of exposed ports
# limit the number of switches that can be controlled from an external P4Runtime
# controller.
EXPOSE 50001-50999
ENTRYPOINT ["mn", "--custom", "bmv2.py", "--switch", "simple_switch_grpc", "--controller", "none"]