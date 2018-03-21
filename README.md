# vertica-eon-docker
Docker container for Vertica Eon mode

The goal is a Docker container for Vertica Eon mode outside AWS using S3-compatible storage such as Minio.

Prerequisite: S3-compatible storage.  I'm testing with the "official" Minio docker build:  https://hub.docker.com/r/minio/minio/

As an aside, you can load data into Vertica CE/EE from Minio by setting your aws_id, aws_secret, aws_endpoint to match your Minio config.

### My approach:

Provide a Dockerfile here to build an image with Vertica and MC

Provide tools (scripts, etc.) to connect to the S3-compatible storage and create the Eon mode database

Provide tools to create and manage additional Vertica Eon mode nodes

### Progress so far:

I'm building based on the Vertica CE Dockerfile developed by Bluelabs forked from https://github.com/bluelabsio/docker-vertica

I will create the database using admintools CLI as documented at https://my.vertica.com/docs/9.0.x/HTML/index.htm#Authoring/InstallationGuide/InstallingVertica/CreatingAnEonDatabase.htm
