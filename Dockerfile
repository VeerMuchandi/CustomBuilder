# This creates a custom docker builder image that invokes build.sh which includes
# the custom code to build your own image.
# this is a customization of example posted here:
# https://github.com/openshift/origin/tree/master/images/builder/docker/custom-docker-builder
#
# This image expects to have the Docker socket bind-mounted into the container.
# If "/root/.dockercfg" is bind mounted in, it will use that as authorization
# to a Docker registry.
#
#
FROM openshift/origin-base

RUN INSTALL_PKGS="gettext automake make docker" && \
    yum install -y $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all

LABEL io.k8s.display-name="OpenShift Custom Builder Example" \
      io.k8s.description="This is an example of a custom builder for use with OpenShift"
ENV HOME=/root
COPY build.sh /tmp/build.sh
CMD ["/tmp/build.sh"]
