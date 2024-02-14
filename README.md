# Sqrbot

Sqrbot is a chat bot built on the [Hubot][hubot] framework.  The only
important function it still provides is unfurling Jira ticket links.

## IMPORTANT NOTE

We're totally cheating.  The dependencies broke, and we haven't been
able to get a working fresh build that actually functions since 0.10.5.

So...we're cheating.  The Docker image now starts with 0.10.5 and only
updates our own script.  The "real" Dockerfile is in Dockerfile.og.
