FROM centos:7

# TODO: We're temporarily uncommenting the baseurl option in the epel repo so
# that download.fedoraproject.org is used to choose a mirror rather than the
# mirrorlist/metalink, as this fails often in certain environments.
RUN yum update -y \
    && yum install -y epel-release && sed '/^#baseurl/s/^#//' -i /etc/yum.repos.d/epel.repo && yum update -y \
    && yum clean all && rm -fR /var/cache/yum

COPY stacksmith-scripts /opt/stacksmith/stacksmith-scripts
COPY user-uploads /opt/stacksmith/user-uploads
COPY user-hooks /opt/stacksmith/user-hooks

RUN chmod +x /opt/stacksmith/stacksmith-scripts/{pre-build-hooks,build,boot,run}.sh && \
    (chmod +x --quiet /opt/stacksmith/stacksmith-scripts/run-template.sh || true) && \
    install -m 755 -o root -g root /opt/stacksmith/stacksmith-scripts/boot.sh /boot.sh

ENV UPLOADS_DIR=/opt/stacksmith/user-uploads

# Run any pre-build steps provided by the user
RUN bash /opt/stacksmith/stacksmith-scripts/pre-build-hooks.sh && \
  yum clean all && rm -fR /var/cache/yum

# Build script from our template
RUN bash /opt/stacksmith/stacksmith-scripts/build.sh && \
  yum clean all && rm -fR /var/cache/yum

# Ensure user scripts are executable and then build script from the user
COPY user-scripts /opt/stacksmith/user-scripts
RUN chmod +x /opt/stacksmith/user-scripts/{build,boot}.sh && \
    (chmod +x --quiet /opt/stacksmith/user-scripts/run.sh || true) && \
    bash /opt/stacksmith/user-scripts/build.sh && \
    yum clean all && rm -fR /var/cache/yum

ENTRYPOINT ["/boot.sh"]
CMD ["bash", "/opt/stacksmith/stacksmith-scripts/run.sh"]
