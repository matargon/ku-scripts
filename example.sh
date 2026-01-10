#!/usr/bin/env bash
USER=$(whoami)
SRV=$1
ssh -i /root/.ssh/id_ed25519 $USER@$SRV 'mkdir /home/student/Desktop/try'
rsync -av -e "ssh -i /root/.ssh/id_ed25519" /home/student/Desktop/try2 $USER@$SRV:/home/student/Desktop/
# rsync -av /home/student/Desktop/try2 $USER@$SRV:/home/student/Desktop/
