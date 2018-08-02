# noVNC + TurboVNC + VirtualGL
# http://novnc.com
# https://turbovnc.org
# https://virtualgl.org

# xhost +si:localuser:root
# openssl req -new -x509 -days 365 -nodes -out self.pem -keyout self.pem
# docker build -t turbovnc .
# docker run --init --runtime=nvidia --name=turbovnc --rm -i -v /tmp/.X11-unix/X0:/tmp/.X11-unix/X0 -p 5901:5901 turbovnc
# docker exec -ti turbovnc vglrun glxspheres64

FROM nvidia/opengl:1.0-glvnd-runtime

ARG TURBOVNC_VERSION=2.1.2
ARG VIRTUALGL_VERSION=2.5.2
ARG LIBJPEG_VERSION=1.5.2
ARG WEBSOCKIFY_VERSION=0.8.0
ARG NOVNC_VERSION=1.0.0-beta

ENV NVIDIA_DRIVER_CAPABILITIES ${NVIDIA_DRIVER_CAPABILITIES},display

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gcc \
        libc6-dev \
        libglu1 \
        libglu1:i386 \
        libsm6 \
        libxv1 \
        libxv1:i386 \
        make \
        python \
        python-numpy \
        x11-xkb-utils \
        xauth \
        xfonts-base \
        xkb-data && \
    rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    curl -fsSL -O https://svwh.dl.sourceforge.net/project/turbovnc/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb \
        -O https://svwh.dl.sourceforge.net/project/libjpeg-turbo/${LIBJPEG_VERSION}/libjpeg-turbo-official_${LIBJPEG_VERSION}_amd64.deb \
        -O https://svwh.dl.sourceforge.net/project/virtualgl/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb \
        -O https://svwh.dl.sourceforge.net/project/virtualgl/${VIRTUALGL_VERSION}/virtualgl32_${VIRTUALGL_VERSION}_amd64.deb && \
    dpkg -i *.deb && \
    rm -f /tmp/*.deb && \
    sed -i 's/$host:/unix:/g' /opt/TurboVNC/bin/vncserver

ENV PATH ${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin

RUN curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar -xzf - -C /opt && \
    curl -fsSL https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz | tar -xzf - -C /opt && \
    mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC && \
    mv /opt/websockify-${WEBSOCKIFY_VERSION} /opt/websockify && \
    ln -s /opt/noVNC/vnc_lite.html /opt/noVNC/index.html && \
    cd /opt/websockify && make

ADD self.pem /

RUN echo 'no-remote-connections\n\
no-httpd\n\
no-x11-tcp-connections\n\
no-pam-sessions\n\
permitted-security-types = otp\
' > /etc/turbovncserver-security.conf

# Install Java 8

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential libgtk2.0-dev \
        libgtk2.0-0:i386 libsm6:i386 \
        software-properties-common python-software-properties \
        default-jre default-jdk

# Install Java.
RUN \
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer

# Set the locale
RUN apt-get clean && apt-get update && apt-get install -y locales
RUN locale-gen en_US.UTF-8

# some utils to have proper menus, mime file types etc.
#RUN apt-get install -y --no-install-recommends xdg-utils xdg-user-dirs \
#    menu-xdg mime-support desktop-file-utils

# Xfce
RUN apt-get install -y --no-install-recommends xfce4
RUN apt-get install -y --no-install-recommends gtk3-engines-xfce xfce4-notifyd \
      mousepad xfce4-taskmanager xfce4-terminal libgtk-3-bin

# Define working directory.
WORKDIR /data

# Define commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# Define default command.
CMD ["bash"]

EXPOSE 5901
ENV DISPLAY :1

ENTRYPOINT ["/opt/websockify/run", "5901", "--cert=/self.pem", "--ssl-only", "--web=/opt/noVNC", "--wrap-mode=ignore", "--", "vncserver", "-geometry", "1920x1080", "-dpi", "128"]

#":1", "-securitytypes", "otp", "-otp", "-noxstartup"]
