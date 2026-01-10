#!/usr/bin/env bash
USER=S (whoani)
ssh -1 /root/.ssh/id _ed25519 SUSER@$1 'mkdir /home/student/Desktop/try'
#rsync -avz -e "ssh -i /root/.ssh/id_ed25519" /opt/backup/student/ $USER@$srv:/opt/backup/student
# echo "something went wrong* >&2
# exit 1
