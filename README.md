# P4Runtime-enabled Mininet Docker Image

Docker image that can execute a Mininet-emulated network of BMv2 virtual
switches, controlled by an external SDN controller via P4Runtime.

This image was created to facilitate testing of P4Runtime support in the ONOS
controller, but you can use it without ONOS.

To obtain the image:

    docker pull opennetworking/p4mn:<tag>

## Tags

The image comes in two versions (tags):

* `opennetworking/p4mn:latest` Updated daily and built from the master branch of
  the [BMv2][BMv2] and [PI][PI] (P4Runtime server implementation) repositories;
* `opennetworking/p4mn:stable` Built using selected BMv2 and PI versions that
  are known to work well with ONOS master.

Moreover, each tag is available in a "no-logging" version with disabled logging
macros in BMv2 to improve packet forwarding performance:

* `opennetworking/p4mn:latest-no-logging`
* `opennetworking/p4mn:stable-no-logging`

## Status [![Build Status](https://github.com/opennetworkinglab/p4mn-docker/actions/workflows/main.yml/badge.svg)](https://github.com/opennetworkinglab/p4mn-docker/actions/workflows/main.yml)

Images are built daily using [Github Actions][GH Actions] and pushed to
[Docker Hub][Docker Hub].

## Steps to run p4mn

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
* `bmv2-s1-netcfg.json`: ONOS netcfg JSON file that can be pushed to ONOS
  to discover this switch instance. This file assumes that ONOS is running on
  the same host as the container. If this is not the case, you will need to
  modify the `managementAddress` property in the JSON file, replacing
  `localhost` with the IP address of the host system of the `p4mn` container.

### Bash alias

A convenient way to quickly start the p4mn container is to create an alias in
your bash profile file (`.bashrc`, `.bash_aliases`, or `.bash_profile`) . For
example:

    alias p4mn="rm -rf /tmp/p4mn && docker run --privileged --rm -it -v /tmp/p4mn:/tmp -p50001-50030:50001-50030 --name p4mn --hostname p4mn opennetworking/p4mn"

Then, to run a a simple 1-switch 2-host topology:

    $ p4mn
    *** Creating network
    *** Adding controller
    *** Adding hosts:
    h1 h2
    *** Adding switches:
    s1
    *** Adding links:
    (h1, s1) (h2, s1)
    *** Configuring hosts
    h1 h2
    *** Starting controller
    
    *** Starting 1 switches
    s1 ....⚡️ simple_switch_grpc @ 50001
    
    *** Starting CLI:
    mininet>

Or a linear one with 3 switches and 3 hosts:

    $ p4mn --topo linear,3
    *** Creating network
    *** Adding controller
    *** Adding hosts:
    h1 h2 h3
    *** Adding switches:
    s1 s2 s3
    *** Adding links:
    (h1, s1) (h2, s2) (h3, s3) (s2, s1) (s3, s2)
    *** Configuring hosts
    h1 h2 h3
    *** Starting controller
    
    *** Starting 3 switches
    s1 .....⚡️ simple_switch_grpc @ 50001
    s2 .....⚡️ simple_switch_grpc @ 50002
    s3 .....⚡️ simple_switch_grpc @ 50003
    
    *** Starting CLI:
    mininet>

[Travis]: https://travis-ci.org/opennetworkinglab/p4mn-docker
[Docker Hub]: https://hub.docker.com/r/opennetworking/p4mn
[BMv2]: https://github.com/p4lang/behavioral-model
[PI]: https://github.com/p4lang/PI
