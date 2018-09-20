FROM node
MAINTAINER sqre-admin
LABEL description="LSST DM-SQuaRE Hubot Automation" \
      name="lsstsqre/sqrbot"
RUN useradd -d /home/hubot -m hubot
USER hubot
WORKDIR /home/hubot
COPY external-scripts.json package.json /home/hubot/
RUN npm install
#
# You will need to set HUBOT_SLACK_TOKEN in order for this to work.
#
# For the scripts to all work you will want:
# HUBOT_GITHUB_USER
# HUBOT_GITHUB_TOKEN
# HUBOT_GITHUB_PASSWORD
# LSST_JIRA_USER
# LSST_JIRA_PWD
#
RUN mkdir scripts
COPY scripts/ scripts/
ENV PATH /usr/local/bin:/usr/bin:/bin:/home/hubot/node_modules/.bin
CMD hubot -a slack
ARG VERSION="0.9.2"
LABEL version="$VERSION"
