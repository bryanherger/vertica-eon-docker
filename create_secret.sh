#!/bin/bash
# create ssh keys and authorized file
rm ./vsshkey ./vsshkey.pub
ssh-keygen -t rsa -N "" -C "" -f ./vsshkey
cp ./vsshkey.pub ./authorized_keys
cp ./authorized_keys ./authorized_keys2
# associate keys with k8s secret expected by vertica
kubectl create secret generic verticasshkeys --from-file=./vsshkey --from-file=./vsshkey.pub --from-file=./authorized_keys --from-file=./authorized_keys2
