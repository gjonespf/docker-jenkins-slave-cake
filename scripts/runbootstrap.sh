#!/bin/bash

if [ -d "/home/jenkins/init/" ]
then
    run-parts --regex '.*sh$' /home/jenkins/init/
fi
