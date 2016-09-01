## Custom Builder With OpenShift Container Platform

The Custom build strategy allows developers to define a specific builder image responsible for the entire build process. Using your own builder image allows you to customize your build process. A Custom builder image is a plain Docker image embedded with build process logic, for example for building RPMs or base Docker images. 

OpenShift documentation here explains more about the custom builder: [https://docs.openshift.com/enterprise/3.2/creating_images/custom.html]()

Here we will learn to create and use an OpenShift Custom Builder with an example. 


**What customization are we doing in this exercise?** 

In this exercise, we will create a custom builder that will take a Dockerfile as input and execute a Docker Build on OpenShift. The resultant DockerImage will put pushed to a Container Registry of your choice. In addition, we will also tarball the image and push it to a git repository. 


1. [Learn to create a custom builder](Creating Custom Builder.md)
2. [Learn to use the custom builder to build an application](Using Custom Builder.md)





