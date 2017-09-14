#!/bin/bash
if [ "${TRAVIS_SECURE_ENV_VARS}" == "true" ]; then
  #export AWS_TEST_DRIVER=$AWS_TRAVIS_DRIVER
  echo "AWS_TEST_DRIVER set to ${AWS_TEST_DRIVER}"
else
  unset AWS_TEST_DRIVER
  echo "Unset AWS_TEST_DRIVER"
fi
