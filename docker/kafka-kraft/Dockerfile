# ==============================================================================
# Dockerfile: Apache Kafka 4.0.1 with KRaft mode running on Java 21 LTS
# ==============================================================================
FROM eclipse-temurin:21-jre-jammy

ENV KAFKA_VERSION=4.0.1 \
    SCALA_VERSION=2.13 \
    KAFKA_HOME=/opt/kafka \
    PATH=$PATH:/opt/kafka/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    tar \
    procps \
    awscli \
    && rm -rf /var/lib/apt/lists/*

# Download Apache Kafka 4.0.1 (KRaft supported, Java 21 LTS runtime native)
RUN set -ex; \
    mkdir -p ${KAFKA_HOME}; \
    curl -fsSL "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz" \
      -o /tmp/kafka.tgz; \
    tar -xf /tmp/kafka.tgz -C ${KAFKA_HOME} --strip-components=1; \
    rm /tmp/kafka.tgz

RUN groupadd -r kafka --gid=1001 && \
    useradd -r -g kafka --uid=1001 -d ${KAFKA_HOME} kafka && \
    mkdir -p /var/lib/kafka/data && \
    chown -R kafka:kafka ${KAFKA_HOME} /var/lib/kafka

WORKDIR ${KAFKA_HOME}
USER kafka

EXPOSE 9092 9093 9094
CMD ["kafka-server-start.sh", "/opt/kafka/config/kraft/server.properties"]
