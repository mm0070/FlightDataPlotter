#!/usr/bin/env bash

PACKAGE="skeleton"
VIRTVER="2.7"

# 0 = Keep existing virtualenv. 1 = Create a new virtualenv.
VIRTNEW=0

# 0 = Run Pyflakes. 1 = Run Pyflakes & Pyint
PYLINT=0

VIRTENV=${WORKSPACE}/.pyenv

# Delete previously built virtualenv
if [ ${VIRTNEW} -eq 1 ] && [ -d ${VIRTENV} ]; then
    rm -rf ${VIRTENV}
fi

# Create virtualenv, but only if doesn't exist
if [ ! -f ${VIRTENV}/bin/python${VIRTVER} ]; then
    virtualenv --python=python${VIRTVER} --no-site-packages --distribute ${VIRTENV}
fi

# Enter the virtualenv
. ${VIRTENV}/bin/activate
cd ${WORKSPACE}

# Update pip to the latest version and use the interna PyPI server
export PIP_INDEX_URL=http://pypi.flightdataservices.com/simple/
pip install --upgrade pip

# Install testing and code metric tools
#pip install --upgrade clonedigger pep8 pyflakes pylint sphinx

# Install requirements
#if [ -f requirements.txt ]; then
#    pip install --upgrade -r requirements.txt
#fi

#pip uninstall ${DISTRIBUTION}
pip install "file:///${WORKSPACE}#egg=Skeleton[coverage,doc,quality]"

#pip install --upgrade "file:///`pwd`#egg=Skeleton[doc]"

# Run any additional setup steps
if [ -x jenkins/setup-extra.sh ]; then
    jenkins/setup-extra.sh
fi

# Install runtime requirements.
if [ -f setup.py ]; then
    python setup.py develop
fi

# Remove existing output files
rm coverage.xml nosetests.xml pylint.log pep8.log cpd.xml sloccount.log

# Run the tests and coverage
if [ -f setup.py ]; then
    python setup.py coverage
fi

# Pyflakes code quality metric, in Pylint format
pyflakes ${PACKAGE} | awk -F\: '{printf "%s:%s: [E]%s\n", $1, $2, $3}' > pylint.log

# Pylint code quality tests
if [ ${PYLINT} -eq 1 ]; then
    pylint --output-format parseable --reports=y \
    --disable W0142,W0403,R0201,W0212,W0613,W0232,R0903,C0301,R0913,C0103,F0401,W0402,W0614,C0111,W0611 \
    ${PACKAGE} | tee --append pylint.log
fi

# PEP8 code quality metric
pep8 ${PACKAGE} > pep8.log || :

# Copy and Paste Detector code quality metric
clonedigger --fast --cpd-output --output=cpd.xml ${PACKAGE}

# Count lines of code
sloccount --duplicates --wide --details ${PACKAGE} > sloccount.log
