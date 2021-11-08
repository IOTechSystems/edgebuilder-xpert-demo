FROM alpine:3.12

LABEL maintainer="iotech <support@iotechsys.com>"

# install necessary tools
RUN apk add --update --no-cache curl

ENV BASE_DIR=/service-setup METADATA_HOST=core-metadata EXPORT_HOST=export-client INFLUXDB_HOST=influxdb17 GRAFANA_HOST=grafana

WORKDIR $BASE_DIR

# Copy setup script into working dir
COPY setup.sh .

RUN chmod 755 ./setup.sh

ENTRYPOINT ["/service-setup/setup.sh"]
