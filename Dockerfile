FROM node
MAINTAINER sqre-admin
LABEL version="0.2.1" description="LSSR DM-SQuaRE Hubot Automation"
RUN useradd -d /home/hubot -m hubot
COPY external-scripts.json package.json README.md /home/hubot/
COPY bin /home/hubot/bin/
COPY scripts /home/hubot/scripts/
COPY node_modules home/hubot/node_modules/
RUN chown -R hubot /home/hubot
USER hubot
WORKDIR /home/hubot
#
# You will need to set HUBOT_SLACK_TOKEN in order for this to work.
#
CMD bin/hubot -a slack
