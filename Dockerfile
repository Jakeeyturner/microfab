#
# SPDX-License-Identifier: Apache-2.0
#
FROM registry.access.redhat.com/ubi8/ubi-minimal AS base
RUN microdnf install git gzip shadow-utils tar xz \
    && groupadd -g 7051 ibp-user \
    && useradd -u 7051 -g ibp-user -s /bin/bash ibp-user \
    && microdnf remove shadow-utils \
    && microdnf clean all
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
RUN mkdir -p /opt/go /opt/node /opt/java \
    && curl -sSL https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz | tar xzf - -C /opt/go --strip-components=1 \
    && curl -sSL https://nodejs.org/download/release/latest-v12.x/node-v12.16.3-linux-x64.tar.xz | tar xJf - -C /opt/node --strip-components=1 \
    && curl -sSL https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.7%2B10/OpenJDK11U-jdk_x64_linux_hotspot_11.0.7_10.tar.gz | tar xzf - -C /opt/java --strip-components=1
ENV GOROOT=/opt/go
ENV JAVA_HOME=/opt/java
ENV PATH=/opt/go/bin:/opt/node/bin:/opt/java/bin:${PATH}
RUN mkdir -p /opt/fabric \
    && curl -sSL https://github.com/hyperledger/fabric/releases/download/v2.1.0/hyperledger-fabric-linux-amd64-2.1.0.tar.gz | tar xzf - -C /opt/fabric
ENV FABRIC_CFG_PATH=/opt/fabric/config
ENV PATH=/opt/fabric/bin:${PATH}

FROM base AS builder
ADD . /tmp/fablet
RUN cd /tmp/fablet \
    && mkdir -p /opt/fablet/bin /opt/fablet/data \
    && chown ibp-user:ibp-user /opt/fablet/data \
    && go build -o /opt/fablet/bin/fablet cmd/fablet/main.go \
    && cp -rf builders /opt/fablet/builders

FROM base
COPY --from=builder /opt/fablet /opt/fablet
ENV FABLET_HOME=/opt/fablet
ENV PATH=/opt/fablet/bin:${PATH}
EXPOSE 8080
USER ibp-user
VOLUME /opt/fablet/data
ENTRYPOINT [ "/tini", "--" ]
CMD [ "/opt/fablet/bin/fablet" ]