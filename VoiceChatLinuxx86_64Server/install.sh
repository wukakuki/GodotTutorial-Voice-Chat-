#!/bin/bash

sudo mv ./EmbeddedVoiceChatServer.service /etc/systemd/system/EmbeddedVoiceChatServer.service
sudo chmod u+x ./EmbeddedVoiceChatServer
sudo mv ./EmbeddedVoiceChatServer /usr/local/bin/EmbeddedVoiceChatServer
sudo mv ./EmbeddedVoiceChatServer.conf /usr/local/etc/EmbeddedVoiceChatServer.conf
sudo systemctl enable EmbeddedVoiceChatServer.service

