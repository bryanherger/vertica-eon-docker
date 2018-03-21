# vertica-eon-docker
Docker container for Vertica Eon mode

The goal is a Docker container for Vertica Eon mode outside AWS using S3-compatible storage such as Minio.

Prerequisite: S3-compatible storage.  I'm testing with the "official" Minio docker build:  https://hub.docker.com/r/minio/minio/

My approach:

Provide a Dockerfile here to build an image with Vertica and MC

Provide tools (scripts, etc.) to connect to the S3-compatible storage and create the Eon mode database

Provide tools to create and manage additional Vertica Eon mode nodes

