FROM viaductoss/ksops:v4.2.1 as ksops-builder

FROM quay.io/argoproj/argocd:v2.8.0

# Switch to root for the ability to perform install
USER root

COPY helm-wrapper.sh /usr/local/bin/

# Install tools needed for your repo-server to retrieve & decrypt secrets, render manifests
# (e.g. curl, awscli, gpg, sops)
RUN apt-get update && \
    apt-get install -y \
        curl \
        awscli \
        gpg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    curl -o /usr/local/bin/sops -L https://github.com/mozilla/sops/releases/download/3.7.3/sops-3.7.3.linux && \
    chmod +x /usr/local/bin/sops &&\
    cd /usr/local/bin && \
    mv helm helm.bin && \
    mv helm-wrapper.sh helm && \
    chmod +x helm

# Switch back to non-root user
USER $ARGOCD_USER_ID

#################
# Install ksops #
#################
# Override the default kustomize executable with the Go built version
COPY --from=ksops-builder /usr/local/bin/kustomize /usr/local/bin/kustomize
# Add ksops executable to path
COPY --from=ksops-builder /usr/local/bin/ksops .config/kustomize/plugin/viaduct.ai/v1/ksops/

########################
# Install Helm Secrets #
########################
RUN helm plugin install https://github.com/jkroepke/helm-secrets
