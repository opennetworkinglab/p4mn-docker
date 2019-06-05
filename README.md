# P4Runtime-enabled Mininet Docker Image

[![Build Status](https://travis-ci.org/ccascone/p4mn-docker.svg?branch=master)](https://travis-ci.org/ccascone/p4mn-docker)
[![](https://images.microbadger.com/badges/image/opennetworking/p4mn.svg)](https://microbadger.com/images/opennetworking/p4mn)

Docker image that can execute a mininet emulated network of BMv2 virtual
switches, controlled by an external SDN controller via P4Runtime.

## Run container

To run the container:

    docker run --privileged --rm -it opennetworking/p4mn [MININET ARGS]

After running this command, you should see the mininet CLI (`mininet>`).

It is important to run this container in privileged mode (`--privileged`) so
mininet can modify the network interfaces and properties to emulate the desired
topology.

The image defines as entry point the mininet executable configured to use BMv2
`simple_switch_grpc` as the default switch. Options to the docker run command
(`[MININET ARGS]`) are passed as parameters to the mininet process. For more
information on the supported mininet options, please check the official mininet
documentation.

For example, to run a linear topology with 3 switches:

    docker run --privileged --rm -it opennetworking/p4mn --topo linear,3

### P4Runtime server ports

Each switch starts a P4Runtime server which is bound to a different port,
starting from 50001 and increasing. To connect an external P4Runtime client
(e.g. an SDN controller) to the switches, you have to publish the corresponding
ports.

For example, when running a topology with 3 switches:

     docker run --privileged --rm -it -p 50001-50003:50001-50003 opennetworking/p4mn --topo linear,3

### BMv2 logs and other temporary files

To allow easier access to BMv2 logs and other files, we suggest sharing the
`/tmp` directory inside the container on the host system using the docker run
`-v` option, for example:

    docker run ... -v /tmp/p4mn:/tmp ... opennetworking/p4mn ...

By using this option, during the container execution, a number of files related
to the execution of the BMv2 switches will be available under `/tmp/p4mn` in the
host system. The name of these files depends on the switch name used in Mininet,
e.g. s1, s2, etc.

Example of these files are:

* `bmv2-s1-grpc-port`: contains the port used for the P4Runtime server executed
  by the switch instance named `s1`;
* `bmv2-s1-log`: contains the BMv2 log;
* `bmv2-s1-netcfg.json`: ONOS netcfg JSON file that can be pushed to the ONOS
  SDN controller to discover this switch instance.