# vertica-eon-docker
Docker container for Vertica Eon mode

The goal is a Docker container for Vertica Eon mode outside AWS using S3-compatible storage such as Minio.

Prerequisite: S3-compatible storage.  I'm testing with the "official" Minio docker build:  https://hub.docker.com/r/minio/minio/

As an aside, you can load data into Vertica CE/EE from Minio by setting your aws_id, aws_secret, aws_endpoint to match your Minio config.

### My approach:

The Vertica CE Dockerfile and entry script were forked from https://github.com/jbfavre/docker-vertica

Provide a Dockerfile here to build an image with Vertica

Provide tools (scripts, etc.) to connect to the S3-compatible storage and create the Eon mode database

Provide tools to create and manage additional Vertica Eon mode nodes

TODO: figure out how to scale automatically, then look into Kubernetes orchestration.

### Quick start:

If you don't want to rebuild, just `docker pull bryanherger/vertica_eon:latest` and skip to the "Run it" step below.

You can create a single node Eon mode instance with this Dockerfile.

Download the Vertica server RPM for RHEL/CentOS from the website and place it in the packages folder.

Clone the repo and build the image with:
`docker build -f Dockerfile.eondocker --build-arg VERTICA_PACKAGE=vertica-9.2.0-6.x86_64.RHEL6.rpm -t vertica_eon .`

Run it:  Eon mode parameters are set with environment variables.  The following options are recognized (with defaults):
- DATABASE_NAME=eondocker
- DATABASE_PASSWORD=[blank/no password]
- COMMUNAL_STORAGE=s3://verticatest/db
- AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
- AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
- AWS_ENDPOINT=192.168.1.206:9999
- AWS_REGION=us-west-1
- AWS_ENABLE_HTTPS=0

Use the -e switch to pass variables, e.g.:
`sudo docker run -it -e COMMUNAL_STORAGE=s3://foo/bar -p 15433:5433 vertica_eon:latest`

Note that this will expose Vertica on port 15433 rather than default.  You can change -p to 5433:5433 to have Vertica on the default port.
You also don't need to run interactive (-it), though it is handy for monitoring and debugging.

### Kubernetes:

There's a very minimal one-node prototype definition in vertica.yaml.  To try it with Minikube:

Install minikube as decribed at https://kubernetes.io/docs/setup/minikube/
 
Start minikube: `minikube start`
 
Edit vertica.yaml and set environment variables noted above using procedure at https://kubernetes.io/docs/tasks/inject-data-application/define-environment-variable-container/
 
Set up the Vertica service: `kubectl apply -f vertica.yaml`

Get the Vertica host and port: `minikube service vertica --url`  (sample output: `http://192.168.39.254:32339`)

Connect to Vertica using host and port from the above output: `vsql -U dbadmin -h 192.168.39.254 -p 32339`
