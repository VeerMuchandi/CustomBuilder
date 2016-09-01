## Creating Custom Builder

First we will learn how to create this Custom builder image in 3 steps:

#### Step 1: Create a Dockerfile

We will start by creating a Dockerfile for our custom builder. I am pulling this example from `https://github.com/openshift/origin/tree/master/images/builder/docker/custom-docker-builder` and further customizing it for our needs.

Note that this Dockerfile uses `openshift/origin-base` as the base image. This is a CentOS based image coming from here `https://github.com/openshift/origin/tree/master/images/base`. For enterprise use you would use a RHEL based image. 

Here is how your Dockerfile would look like: 


``` 
# This creates a custom docker builder image that invokes build.sh which includes
# the custom code to build your own image.
# this is a customization of example posted here:
# https://github.com/openshift/origin/tree/master/images/builder/docker/custom-docker-builder
#
# This image expects to have the Docker socket bind-mounted into the container.
# If "/root/.dockercfg" is bind mounted in, it will use that as authorization
# to a Docker registry.
#
#
FROM openshift/origin-base

RUN INSTALL_PKGS="gettext automake make docker" && \
    yum install -y $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all

LABEL io.k8s.display-name="OpenShift Custom Builder Example" \
      io.k8s.description="This is an example of a custom builder for use with OpenShift"
ENV HOME=/root
COPY build.sh /tmp/build.sh
CMD ["/tmp/build.sh"]
```

#### Step 2: Create a custom build script

This is where the meat of our customization is. The Dockerfile in the previous step would copy a file with name build.sh into /tmp and executes it when it runs. All our customization logic would be in this file.

Here is our build.sh script. This is a simple script.  I encourage you to read the comments at the beginning of the script and understand what it does as this is the key to our custom builder. This is just a sample script and written pretty raw. I may improve this further. The latest version of this script is checked into the github repository at [https://github.com/VeerMuchandi/CustomBuilder]()

```
#!/bin/bash

# This custom build script takes a Dockerfile as input from the source repository, runs a DockerBuild and pushes the resultant 
# image into a registry of choice. In addition, it also tarballs the image and saves the image in a target git repository
#
# This script expects expects the following parameters
#   OUTPUT_REGISTRY - the Docker registry URL to push this image to. This comes from the output tag in the buildConfig
#   OUTPUT_IMAGE - the name to tag the image with. Comes from the output tag in the buildConfig
#   SOURCE_REPOSITORY - the git repo to fetch the build context from. Comes from the source section of buildConfig
#   SOURCE_REF - a reference to pass to Git for which commit to use (optional). Comes from the source section of buildConfig
#   SOURCE_CONTEXT_DIR - Context directory (optional). Comes from the source section of buildConfig
# In addition, this script expects the following environment variables as part of buildConfig
#   TARGET_GIT_REPOSITORY - git repo uri to push the resultant image to
#   USER_NAME - User name to use for git config
#   USER_EMAIL - Email to use for git config
#
# The script also expects an sshkey to be able to push to the target repository to be set up as a "Secret"

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
```

Now that we have the build file, make sure that it is  executable:

```
chmod +x build.sh
```

#### Step 3: Build the Custom Builder to create a Custom builder image

This is a simple Docker Build process. You will use docker build process. Tag your image with whatever name you wish and push into a Docker Registry of your choice. In my case, I called it `customdockerbuilder` and I am pushing this to DockerHub into my user space. If you are pushing to DockerHub like I am doing here you would replace this image tag as `<yourid>/customdockerbuilder`. 

**Note** If you are using a RHEL based image as the base image in your Dockerfile in Step 1 above, you cannot push it to DockerHub. You will have to push into your private repository. Also RHEL based image can only be built on a RHEL boxed that is subscribed to Red Hat.

**Note** Also note that if you are pushing into a private registry, it must be accessible from the OpenShift Cluster.
 

So, run `docker build`  first as shown below

```
$ docker build -t "veermuchandi/customdockerbuilder" .
Sending build context to Docker daemon 24.58 kB
Step 1 : FROM openshift/origin-base
 ---> 7adf39ecb52a
Step 2 : RUN INSTALL_PKGS="gettext automake make docker" &&     yum install -y $INSTALL_PKGS &&     rpm -V $INSTALL_PKGS &&     yum clean all
 ---> Using cache
 ---> 700ffccc3da6
Step 3 : LABEL io.k8s.display-name "OpenShift Origin Custom Builder Example" io.k8s.description "This is an example of a custom builder for use with OpenShift Origin."
 ---> Using cache
 ---> 2c72f586f412
Step 4 : ENV HOME /root
 ---> Using cache
 ---> ff6f267c81cd
Step 5 : COPY build.sh /tmp/build.sh
 ---> 9c1f3dd76d5d
Removing intermediate container f10056f24eb2
Step 6 : CMD /tmp/build.sh
 ---> Running in 05c735f6dbcc
 ---> 9d5e6ee2cfdc
Removing intermediate container 05c735f6dbcc
Successfully built 9d5e6ee2cfdc
```

You can verify the images by running `docker images` on your workstation.  Now it is time to push this image to the registry by running `docker push`.


```
$ docker push veermuchandi/customdockerbuilder
```

Once `docker push` is complete verify your image is in the registry.

And that's it!! Your custom builder is ready to use :)

In the next chapter, we will discuss how to use this image.

