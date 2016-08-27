#!/bin/bash
set -o pipefail
IFS=$'\n\t'

DOCKER_SOCKET=/var/run/docker.sock


if [ ! -e "${DOCKER_SOCKET}" ]; then
  echo "Docker socket missing at ${DOCKER_SOCKET}"
  exit 1
fi

if [ -n "${OUTPUT_IMAGE}" ]; then
  TAG="${OUTPUT_REGISTRY}/${OUTPUT_IMAGE}"
fi

if [[ "${SOURCE_REPOSITORY}" != "git://"* ]] && [[ "${SOURCE_REPOSITORY}" != "git@"* ]]; then
  URL="${SOURCE_REPOSITORY}"
  if [[ "${URL}" != "http://"* ]] && [[ "${URL}" != "https://"* ]]; then
    URL="https://${URL}"
  fi
  curl --head --silent --fail --location --max-time 16 $URL > /dev/null
  if [ $? != 0 ]; then
    echo "Could not access source url: ${SOURCE_REPOSITORY}"
    exit 1
  fi
fi

# Build a docker image and push into a docker registry as defined in the TAG

if [ -n "${SOURCE_REF}" ]; then
  BUILD_DIR=$(mktemp --directory)
  git clone --recursive "${SOURCE_REPOSITORY}" "${BUILD_DIR}"
  if [ $? != 0 ]; then
    echo "Error trying to fetch git source: ${SOURCE_REPOSITORY}"
    exit 1
  fi
  pushd "${BUILD_DIR}"
  git checkout "${SOURCE_REF}"
  if [ $? != 0 ]; then
    echo "Error trying to checkout branch: ${SOURCE_REF}"
    exit 1
  fi
  popd
  docker build --rm -t "${TAG}" "${BUILD_DIR}"
else
  if [ -n "${SOURCE_CONTEXT_DIR}" ]; then
    docker build --rm -t "${TAG}" "${SOURCE_REPOSITORY}#:${SOURCE_CONTEXT_DIR}" 
  else
     docker build --rm -t "${TAG}" "${SOURCE_REPOSITORY}"
  fi
fi

if [[ -d /var/run/secrets/openshift.io/push ]] && [[ ! -e /root/.dockercfg ]]; then
  cp /var/run/secrets/openshift.io/push/.dockercfg /root/.dockercfg
fi

if [ -n "${OUTPUT_IMAGE}" ] || [ -s "/root/.dockercfg" ]; then
  docker push "${TAG}"
fi

mkdir -p /tmp/.ssh
cp /var/run/secrets/openshift.io/build/scmsecret/ssh-privatekey  /tmp/.ssh
ls /tmp/.ssh

SSH_KEY_LOC=/tmp/.ssh
SSH_KEY=/tmp/.ssh/ssh-privatekey
chmod 0700 "${SSH_KEY_LOC}"
chmod 0600 "${SSH_KEY}"
mkdir -p /root/.ssh
ssh-keyscan -H github.com >> ~/.ssh/known_hosts

## This code converts the resultant docker image into a tar file  
## and pushes it into a Git Repository
 
if [ -n "${OUTPUT_IMAGE}" ] && [ -n "${TARGET_GIT_REPOSITORY}" ] ; then
	TMP_DIR=$(mktemp --directory)
	echo $TMP_DIR
	pushd "${TMP_DIR}"
                
	git init

        if [ -n "${USER_EMAIL}" ] ; then 
          git config --global user.email "${USER_EMAIL}"
        fi

        
        if [ -n "${USER_NAME}" ] ; then 
	  git config --global user.name "${USER_NAME}"
        fi

	git remote add origin "${TARGET_GIT_REPOSITORY}" 
        ssh-agent /bin/bash -c 'ssh-add /tmp/.ssh/ssh-privatekey; git pull -u origin master'
	git rm *
	git commit -m "removed old files"
        ssh-agent /bin/bash -c 'ssh-add /tmp/.ssh/ssh-privatekey; git push -u origin master'
        TAR_NAME=$(echo $OUTPUT_IMAGE| cut -d':' -f 1| cut -d'/' -f 2)
	docker save -o "${TAR_NAME}".tar "${OUTPUT_IMAGE}" 
	git add .
	git commit -m "added new tar"
        ssh-agent /bin/bash -c 'ssh-add /tmp/.ssh/ssh-privatekey; git push -u origin master'
	popd
	rm -rf "${TMP_DIR}"
fi


