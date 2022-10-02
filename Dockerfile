FROM docker.io/library/ubuntu:22.04

SHELL ["/bin/bash", "-c"]

# installer does not like being run from /
WORKDIR "/root"

# Ports: ???, http, https, ???, snmp, snmp
# See https://dl4jz3rbrsfum.cloudfront.net/documents/CyberPower_UM_PowerPanel-Business-486.pdf
EXPOSE 2003
EXPOSE 3052
EXPOSE 53568/tcp
EXPOSE 53566/udp
EXPOSE 161/udp
EXPOSE 162/udp

# set Apt package manager to non-interactive mode, avoids prompts
ARG DEBIAN_FRONTEND=noninteractive  

# define the terminal
ENV TERM="xterm-256color"

ENV POWERPANEL_VERSION=486
ENV ENABLE_LOGGING=true

### ENV FONTCONFIG_PATH="/etc/fonts"       # this seems to break things

# set some environment variables for Bash
RUN printf "\nexport TERM=xterm-256color\nexport FONTCONFIG_PATH=/etc/fonts\n" >> /root/.bashrc

# Set the time zone
ENV TZ="America/New_York"
RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime

# See https://www.ej-technologies.com/resources/install4j/help/doc/installers/responseFile.html
# for definition of response files
# trying new, seems to have worked?
COPY response.varfile response.varfile

# install some basic pre-reqs to avoid errors in future apt installations
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    apt-utils=2.4.7 \
    dialog=1.3-20211214-1

# Package reasons:
#   curl: to download installer
#   ca-certificates: to make https work
#   *usb*: to connect to UPSs over USB
RUN apt-get install -y --no-install-recommends \
        curl=7.81.0-1ubuntu1.4 \
        ca-certificates \
        libgusb2=0.3.10-1 \
        libusb-0.1=2:0.1.12-32build3 \
        libusb-1.0-0=2:1.0.25-1ubuntu2 \
        usb.ids=2022.04.02-1 \
        usbutils=1:014-1build1 && \
    rm -rf /var/lib/apt/lists/* && \
    curl -s -L 'https://dl4jz3rbrsfum.cloudfront.net/software/PPB_Linux%2064bit_v4.8.6.sh' -o ppb-linux-x86_64.sh && \
    # curl -s -L 'https://www.cyberpower.com/global/en/File/GetFileSampleByType?fileId=SU-20040001-06&fileType=Download%20Center&fileSubType=FileOriginal' -o ppb-linux-x86_64.sh && \
    chmod +x ppb-linux-x86_64.sh && \
    # See https://www.ej-technologies.com/resources/install4j/help/doc/installers/options.html
    ./ppb-linux-x86_64.sh -q -varfile response.varfile && \
    rm ppb-linux-x86_64.sh && \
    rm response.varfile

# Bug: container will hang on start unless VOLUME is commented out
# Info: There are many other folders under /usr/local/PPB that probably need to be on a VOLUME:
#   /usr/local/PPB/cert/              (your ssl cert if you enable https)
#   /usr/local/PPB/db_cloud/          (db if using cloud service)
#   /usr/local/PPB/db_local/          (db if not using cloud service)
#   /usr/local/PPB/etc/               (some test logs)
#   /usr/local/PPB/extcmd/            (*.sh files to run when events happen)
#   /usr/local/PPB/log/               (possibly only installation logs)
#   /usr/local/PPB/temp/              (current version info)
#   /usr/local/PPB/uploads/           (possibly used for importing profile settings)
#   /usr/local/PPB/web/work/local/    (the icons needed for the specific UPS attached)
#   /usr/local/PPB/web-server/local/WEB-INF/classes/static/assets/   (dynamic translations)
# Info: https://docs.docker.com/engine/reference/builder/#notes-about-specifying-volumes
#   "Changing the volume from within the Dockerfile: If any build steps change the data within
#   the volume after it has been declared, those changes will be discarded."
#       Therefore, files in /usr/local/PPB/db_local generated on service start might be lost
# Solution: The volume must be /usr/local/PPB, not /usr/local/PPB/db_local. That means it will
#   also contain ~275 MB of program files that don't need to be in a volume, but the
#   alternative would be setting up ~10 volumes, which is too many.
VOLUME ["/usr/local/PPB/"]

HEALTHCHECK CMD curl -vs --fail http://127.0.0.1:3052/ || exit 1

COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod +x docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]
