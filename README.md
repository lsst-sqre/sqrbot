# sqrbot

Sqrbot is Hubot with a few custom scripts, which you will find in
"scripts".  It's designed to talk to the LSSTC Slack and provide
automation services.  For instance, try `@sqrbot status` in the
&#35;dm-square-status channel.

Don't get attached to Hubot; that's an implementation detail and we may
replace it with something we like more.  Hubot is an easy starting
point, though, with tons of community scripts available.

## Environment

You need to set `HUBOT_SLACK_TOKEN` to an appropriate bot token for it to
run.  If we use something besides Hubot, we'll update the documentation.

In order for all of our services to work, you will need
`HUBOT_GITHUB_USER`, `HUBOT_GITHUB_PASSWORD`, and `HUBOT_GITHUB_TOKEN`
to all be set as well.

## Dockerize

Use the included Dockerfile; the artifact itself is lsstsqre/sqrbot on
Docker Hub, so you can just pull it if that's easier.  You still have to
set the environment for it, though.
