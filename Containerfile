# Containerfile
# Updated for simplified data directory approach
# Fixed log directory issue

FROM registry.redhat.io/ubi8/ruby-27

WORKDIR /opt/app-root/src

# Copy Gemfile first for cache efficiency
COPY Gemfile Gemfile.lock ./

# Configure bundler to install gems locally (avoiding permission issues)
RUN bundle config set --local path vendor/bundle && \
    bundle install

# Now copy the rest of the app
COPY --chown=1000:1000 . .

# Stamp the deployed commit into the image for `cleanbox version` / debugging.
# Placed last so changing the SHA on every build only busts this trailing layer,
# not the gem install or source copy layers above.
ARG GIT_SHA=unknown
ARG GIT_SHA_SHORT=unknown
ARG GIT_COMMIT_DATE=unknown
ARG GIT_COMMIT_SUBJECT=unknown
RUN { \
      echo "sha=${GIT_SHA}"; \
      echo "short_sha=${GIT_SHA_SHORT}"; \
      echo "commit_date=${GIT_COMMIT_DATE}"; \
      echo "commit_subject=${GIT_COMMIT_SUBJECT}"; \
      echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; \
    } > .cleanbox_version
# No default CMD — pass at runtime
