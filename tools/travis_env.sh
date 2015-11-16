#!/bin/bash
[ "${TRAVIS_SECURE_ENV_VARS}" == "false" ] && exit 0;

export AWS_TEST_DRIVER=$AWS_TRAVIS_DRIVER
echo "AWS_TEST_DRIVER set to ${AWS_TEST_DRIVER}"
