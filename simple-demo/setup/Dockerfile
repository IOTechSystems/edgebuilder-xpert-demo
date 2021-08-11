FROM alpine:3.12

LABEL maintainer="iotech <support@iotechsys.com>"

# install necessary tools
RUN apk add --update --no-cache curl

ENV BASE_DIR=/metadata-setup METADATA_HOST=core-metadata

WORKDIR $BASE_DIR

# Copy device profiles into profiles under working dir
COPY ./profiles/profile.*.yaml profiles/
# Copy devices creation payload into devices under working dir
COPY ./devices/device-*.json devices/
# Copy setup script into working dir
COPY setup.sh .

RUN chmod 755 ./setup.sh

ENTRYPOINT ["/metadata-setup/setup.sh"]
