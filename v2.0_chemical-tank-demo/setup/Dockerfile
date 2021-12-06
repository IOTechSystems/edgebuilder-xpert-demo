FROM alpine:3.12

LABEL maintainer="iotech <support@iotechsys.com>"

# install necessary tools
RUN apk add --update --no-cache curl

ENV BASE_DIR=/service-setup METADATA_HOST=core-metadata INFLUXDB_HOST=influxdb2 GRAFANA_HOST=grafana NODERED=nodered

WORKDIR $BASE_DIR

# Copy device profiles into profiles under working dir
COPY ./profiles/*-profile.yml profiles/
# Copy devices creation payload into devices under working dir
COPY ./devices/device-*.json devices/
# Copy grafana dashboard into dashboards working dir
COPY ./dashboards/*.json dashboards/
# Copy nodered flows into nodered working dir
COPY ./nodered/*.json nodered/
# Copy setup script into working dir
COPY setup.sh .

RUN chmod 755 ./setup.sh

ENTRYPOINT ["/service-setup/setup.sh"]
