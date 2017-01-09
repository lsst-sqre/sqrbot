FROM node
MAINTAINER sqre-admin
LABEL description="LSST DM-SQuaRE Hubot Automation" \
      name="lsstsqre/sqrbot"
RUN useradd -d /home/hubot -m hubot
COPY external-scripts.json package.json README.md /home/hubot/
COPY bin /home/hubot/bin/
COPY node_modules home/hubot/node_modules/
RUN chown -R hubot /home/hubot
COPY scripts /home/hubot/scripts/
RUN chown -R hubot /home/hubot/scripts
USER hubot
WORKDIR /home/hubot
#
# You will need to set HUBOT_SLACK_TOKEN in order for this to work.
#
CMD bin/hubot -a slack
ARG VERSION="0.4.0"
LABEL version="$VERSION"
