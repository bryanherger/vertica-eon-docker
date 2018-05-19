#!/bin/bash
sudo docker run -it --rm -p 15450:5450 -p 9000:9000 vertica-eon-docker server /data

