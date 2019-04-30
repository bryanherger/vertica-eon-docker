VERSION9x = 9.2.0-6

push: push-9.x

push-9.x: build-9.x
	docker tag bryanherger/vertica:$(VERSION9x)_eon bryanherger/vertica:9.x
	docker tag bryanherger/vertica:$(VERSION9x)_eon bryanherger/vertica:latest
	docker push bryanherger/vertica:$(VERSION9x)_eon
	docker push bryanherger/vertica:9.x
	docker push bryanherger/vertica:latest

build: build-9.x

build-9.x:
	docker build --rm=true --no-cache -f Dockerfile.eondocker \
	             --build-arg VERTICA_PACKAGE=vertica-$(VERSION9x).x86_64.RHEL6.rpm \
	             -t bryanherger/vertica:$(VERSION9x)_eon .

clean:
	docker rm -v $(docker ps -a -q -f status=exited)
	docker rmi $(docker images -f "dangling=true" -q)
