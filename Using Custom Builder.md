## Using Custom Builder

In the last chapter we have learnt how to create a custom builder and pushed it into a registry. In this chapter we will learn to use that custom builder to build a docker image.

If you remember our custom builder takes a Dockerfile as input from a git repository, runs a container build and pushes the resultant container image to a registry of your choice as configured in output section of the build config. In addition our builder also tarballs the resultant image and saves it to a git destination of your choice (also configured inside the build configuration).

Let us discuss this in a few steps:

#### Step 1: Create a new project

Log into your OpenShift cluster and create a new project by running commands

``` oc login <<your cluster url>>:<<port>> ```

and

```oc new-project customdemo```

I named my project customdemo.


#### Step 2: Add your SSH Key as a Secret 

In order for our custom builder to be able to push to a git repository your custom builder needs to know your SSH Key. In this step we will add your SSH key to the project as a secret.

**Note** In this example, we assume that you have already configured your git repository to use the SSH key, so that git push does not prompt you for username and password. If you want to know how to do this please refer to the help available at this link [https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/]()
If you are using a different kind of git repository, the instructions may be different.
 
Use `oc secrets` command shown below to add the privatekey as the secret to OpenShift. The script expects the key to be mounted as `scmsecret` and the key named as `ssh-privatekey` 

Usually your keys are in `.ssh` folder in your home directory. So you will replace the home directory in the command below.

```
oc secrets new scmsecret ssh-privatekey=<yourhome>/.ssh/id_rsa
```

Now if you verify `oc get secrets` in your project, the `scmsecret` you just added should show up.


#### Step 3: Create a build configuration file

In this step we will create a new build configuration an make some minor tweaks to be able to set it up for a custom build.

I am trying to build a Dockerfile in the repository [git://github.com/VeerMuchandi/time.git](), within the context directory `busybox`. You can use the same. If you go to this repository you will notice that there is a Dockerfile that uses `busybox` base image and just invokes a script that simply displays date and time. Our intent is to build a container image using this Dockerfile using our custom builder. The custom builder pushes the resultant container image to a registry as well as tarballs it and pushes into a git repository.

We will use `oc new-build` command to create this build config. But redirect the output this build config as a json file, that we will first save and make some tweaks in the next step.


```

oc new-build git://github.com/VeerMuchandi/time.git --context-dir=busybox --docker-image=veermuchandi/customdockerbuilder --build-secret=scmsecret --env TARGET_GIT_REPOSITORY='git@github.com:VeerMuchandi/tmpdocimages.git',USER_NAME='Veer Muchandi',USER_EMAIL='veer@example.com',OPENSHIFT_CUSTOM_BUILD_BASE_IMAGE=veermuchandi/customdockerbuilder -o json > build.json

```

Notice that I have included the environment variables TARGET_GIT_REPOSITORY, USER_NAME, USER_EMAIL. **Replace** these with your own values.  
* TARGET_GIT_REPOSITORY is the location of the git repo where you want the output tarball of the container image to be pushed
* USER_NAME and USER_EMAIL are the values to assign to the git config

Also note the `build-secret` parameter points to the secret that you loaded before.

We are passing the docker-image parameter to use the custom docker builder that we built in the last chapter. **Replace** this value to your own custom docker builder.


If you have successfully run the above command you should see a `build.json` file on your workstation with the contents similar to this

```
{
    "kind": "List",
    "apiVersion": "v1",
    "metadata": {},
    "items": [
        {
            "kind": "ImageStream",
            "apiVersion": "v1",
            "metadata": {
                "name": "customdockerbuilder",
                "creationTimestamp": null,
                "labels": {
                    "build": "time"
                },
                "annotations": {
                    "openshift.io/generated-by": "OpenShiftNewBuild"
                }
            },
            "spec": {
                "tags": [
                    {
                        "name": "latest",
                        "annotations": {
                            "openshift.io/imported-from": "veermuchandi/customdockerbuilder"
                        },
                        "from": {
                            "kind": "DockerImage",
                            "name": "veermuchandi/customdockerbuilder"
                        },
                        "generation": null,
                        "importPolicy": {}
                    }
                ]
            },
            "status": {
                "dockerImageRepository": ""
            }
        },
        {
            "kind": "ImageStream",
            "apiVersion": "v1",
            "metadata": {
                "name": "time",
                "creationTimestamp": null,
                "labels": {
                    "build": "time"
                },
                "annotations": {
                    "openshift.io/generated-by": "OpenShiftNewBuild"
                }
            },
            "spec": {},
            "status": {
                "dockerImageRepository": ""
            }
        },
        {
            "kind": "BuildConfig",
            "apiVersion": "v1",
            "metadata": {
                "name": "time",
                "creationTimestamp": null,
                "labels": {
                    "build": "time"
                },
                "annotations": {
                    "openshift.io/generated-by": "OpenShiftNewBuild"
                }
            },
            "spec": {
                "triggers": [
                    {
                        "type": "GitHub",
                        "github": {
                            "secret": "Fi1tDlzuD-a_2B38b2nt"
                        }
                    },
                    {
                        "type": "Generic",
                        "generic": {
                            "secret": "VX1uYr4hCgL5-_M0FgMr"
                        }
                    },
                    {
                        "type": "ConfigChange"
                    },
                    {
                        "type": "ImageChange",
                        "imageChange": {}
                    }
                ],
                "source": {
                    "type": "Git",
                    "git": {
                        "uri": "git://github.com/VeerMuchandi/time.git"
                    },
                    "contextDir": "busybox",
                    "secrets": [
                        {
                            "secret": {
                                "name": "scmsecret"
                            },
                            "destinationDir": "."
                        }
                    ]
                },
                "strategy": {
                    "type": "Source",
                    "sourceStrategy": {
                        "from": {
                            "kind": "ImageStreamTag",
                            "name": "customdockerbuilder:latest"
                        },
                        "env": [
                            {
                                "name": "OPENSHIFT_CUSTOM_BUILD_BASE_IMAGE",
                                "value": "veermuchandi/customdockerbuilder"
                            },
                            {
                                "name": "TARGET_GIT_REPOSITORY",
                                "value": "git@github.com:VeerMuchandi/tmpdocimages.git"
                            },
                            {
                                "name": "USER_EMAIL",
                                "value": "veer@example.com"
                            },
                            {
                                "name": "USER_NAME",
                                "value": "Veer Muchandi"
                            }
                        ]
                    }
                },
                "output": {
                    "to": {
                        "kind": "ImageStreamTag",
                        "name": "time:latest"
                    }
                },
                "resources": {},
                "postCommit": {}
            },
            "status": {
                "lastVersion": 0
            }
        }
    ]
}

```



**Note** that at this point we only have build configuration as a file. Build configuration object is not created in your project yet. Your project is still empty. For convenience I am also checking in my build.json as an example into the git repository  [https://github.com/VeerMuchandi/CustomBuilder]()



#### Step 4: Edit the build configuration

Open the `build.json` file that we created in the previous step and we will make a couple of changes to this build configuration:

* **Strategy** Locate the strategy section and change `type` to `Custom` and the label `sourceStrategy` to `customStrategy`.

* **Expose Docker Socket** Right after that, add  ExposeDockerSocket variable and set it to true

* **Temporary Change** At the time of writing this article, due to DockerHub suddenly changing the version, there is an incompatibility issue with older manifests versions. This leads to unrecognized manifest errors when you run a build. In order to avoid this error, we have a temporary workaround.  Locate the `from` section in the `strategy` and change the kind from `ImageStreamTag` to `DockerImage` and the `name` to point to the custom builder image from your registry (in my case it is on DockerHub `veermuchandi/customdockerbuilder:latest`). This change would not be needed in the future once the manifest incompatibility issue is taken care of.


Once the above changes are made, the strategy section would look as in this code snippet:

```
                "strategy": {
                    "type": "Custom",
                    "customStrategy": {
                        "from": {
                            "kind": "DockerImage",
                            "name": "veermuchandi/customdockerbuilder:latest"
                        },
                        "exposeDockerSocket": true,
                        .......
                        .......

```

Now our build configuration is ready to be used. This sample edited build.json file is uploaded to my github for your reference.


####Step 5: Create and Initiate the Build

We will now use the build.json file that was edited in the previous step to create a build configuration in your project by running `oc create` as shown below:            
            
            
```
$ oc create -f build.json
imagestream "customdockerbuilder" created
imagestream "time" created
buildconfig "time" created
```
You will notice that both `imagestreams` and `buildconfig` are created by the above command

It will immediately initiate a new build as well. Verify this by running

```
$ oc get builds

NAME      TYPE      FROM      STATUS    STARTED   DURATION
time-1    Custom    Git       Pending
```

Once the build config is created, anytime you want to initiate the build yourself, you can run `oc start-build time` and it will start a new build for you.

You can watch the build logs by running

```
oc logs time-1-build -f
```
Use the right pod name above in your situation. It will show you the progress of the build.

At the end of the build you can check your git repository where you wanted the tarball image to be pushed. In my example above, I had set it to [https://github.com/VeerMuchandi/tmpdocimages]() and can find the image tarball pushed there.

This is how your custom builder can be used.

Now the next step is just to complete the flow, although not relevant to using custom builder and you don't have to do the next step.

####Step 6: Deploying and using the application

While we already tested the custom builder in the last step, just for completeness, if you want to deploy the application you just built run

```
$ oc new-app time
--> Found image b24366f (4 weeks old) in image stream time under tag "latest" for "time"

    * This image will be deployed in deployment config "time"
    * Port 8080/tcp will be load balanced by service "time"
      * Other containers can access this service through the hostname "time"
    * WARNING: Image "time" runs as the 'root' user which may not be permitted by your cluster administrator

--> Creating resources with label app=time ...
    deploymentconfig "time" created
    service "time" created
--> Success
    Run 'oc status' to view your app.
```

Note that I matched the name of the application to the name of the build config and the image stream that was created before in step 3, so that the deployment config that it generates points to the image stream where the application image created by the custom builder is pushed to.

Next I will expose the service to create a route

```
$ oc expose svc time
route "time" exposed

$ oc get route
NAME      HOST/PORT                                  PATH      SERVICE         TERMINATION   LABELS
time      time-customdemo.apps.testv3.osecloud.com             time:8080-tcp                 app=time
```

And test the application 

```
$ curl time-customdemo.apps.testv3.osecloud.com
Thu Sep  1 20:22:27 UTC 2016
```


And that's it!!!!


###Summary:
In this two section series you have learnt to create a custom builder and use the same on OpenShift.