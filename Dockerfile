FROM docker.io/lsstsqre/sqrbot:0.10.5
MAINTAINER sqre-admin
LABEL description="LSST DM-SQuaRE Hubot Automation" \
      name="lsstsqre/sqrbot"
USER hubot
WORKDIR /home/hubot
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
COPY scripts/ scripts/
CMD hubot -a slack
ARG VERSION="0.11.1"
LABEL version="$VERSION"
