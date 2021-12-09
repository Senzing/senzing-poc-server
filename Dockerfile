ARG BASE_IMAGE=senzing/senzing-base:1.6.3
ARG BASE_BUILDER_IMAGE=senzing/base-image-debian:1.0.6

# -----------------------------------------------------------------------------
# Stage: builder
# -----------------------------------------------------------------------------

FROM ${BASE_BUILDER_IMAGE} as builder

ENV REFRESHED_AT=2021-12-07

LABEL Name="senzing/senzing-poc-server-builder" \
      Maintainer="support@senzing.com" \
      Version="1.0.0"

# Set environment variables.

ENV SENZING_ROOT=/opt/senzing
ENV SENZING_G2_DIR=${SENZING_ROOT}/g2
ENV PYTHONPATH=${SENZING_ROOT}/g2/python
ENV LD_LIBRARY_PATH=${SENZING_ROOT}/g2/lib:${SENZING_ROOT}/g2/lib/debian

# Build "senzing-api-server.jar"

COPY senzing-api-server /senzing-api-server
WORKDIR /senzing-api-server

RUN export SENZING_API_SERVER_JAR_VERSION=$(mvn "help:evaluate" -Dexpression=project.version -q -DforceStdout) \
 && make package \
 && cp /senzing-api-server/target/senzing-api-server-${SENZING_API_SERVER_JAR_VERSION}.jar "/app/senzing-api-server.jar"

# Install senzing-api-server.jar into maven repository.

RUN mvn install:install-file \
      -Dfile=/app/senzing-api-server.jar  \
      -DgroupId=com.senzing \
      -DartifactId=senzing-api-server \
      -Dversion=${SENZING_API_SERVER_VERSION} \
      -Dpackaging=jar

# Copy Repo files to Builder step.

COPY . /poc-api-server

# Run the "make" command to create the artifacts.

WORKDIR /poc-api-server

RUN export POC_API_SERVER_JAR_VERSION=$(mvn "help:evaluate" -Dexpression=project.version -q -DforceStdout) \
 && make \
     package \
 && cp /poc-api-server/target/senzing-poc-server-${POC_API_SERVER_JAR_VERSION}.jar "/senzing-poc-server.jar"

# -----------------------------------------------------------------------------
# Stage: Final
# -----------------------------------------------------------------------------

FROM ${BASE_IMAGE}

ENV REFRESHED_AT=2021-12-07

LABEL Name="senzing/senzing-poc-server" \
      Maintainer="support@senzing.com" \
      Version="1.1.0"

HEALTHCHECK CMD ["/app/healthcheck.sh"]

# Run as "root" for system installation.

USER root

# Install packages via apt.

RUN apt update \
 && apt -y install \
      software-properties-common \
 && rm -rf /var/lib/apt/lists/*

# Install Java-11.

RUN wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add - \
 && add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ \
 && apt update \
 && apt install -y adoptopenjdk-11-hotspot \
 && rm -rf /var/lib/apt/lists/*

# Service exposed on port 8080.

EXPOSE 8080

# Copy files from builder step.

COPY --from=builder "/senzing-poc-server.jar" "/app/senzing-poc-server.jar"

# Make non-root container.

USER 1001

# Runtime execution.

WORKDIR /app
ENTRYPOINT ["java", "-jar", "senzing-poc-server.jar"]
