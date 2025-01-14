#!/bin/bash

set -e -x

PY_MAJOR=${PYTHON_VERSION%%.*}
PY_MINOR=${PYTHON_VERSION#*.}

ML_PYTHON_VERSION="cp${PY_MAJOR}${PY_MINOR}-cp${PY_MAJOR}${PY_MINOR}m"

# Compile wheels
PYTHON="/opt/python/${ML_PYTHON_VERSION}/bin/python"
PIP="/opt/python/${ML_PYTHON_VERSION}/bin/pip"
"${PIP}" install --upgrade setuptools pip wheel~=0.31.1
cd "${GITHUB_WORKSPACE}"
make clean
"${PYTHON}" setup.py bdist_wheel

# Bundle external shared libraries into the wheels.
for whl in "${GITHUB_WORKSPACE}"/dist/*.whl; do
    auditwheel repair $whl -w "${GITHUB_WORKSPACE}"/dist/
    rm "${GITHUB_WORKSPACE}"/dist/*-linux_*.whl
done
