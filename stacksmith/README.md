# Build and test your Stacksmith application locally

Local environments are available for download after you select your Stack
Template, enabling you to test packaging your application and scripts locally.
Each local environment includes an example demonstrating packaging and testing
a working application.

When you click on the "download a local environment" link your browser will
download an archive containing the local environment for that specific template,
which you should extract to an empty directory on your computer.

This directory contains an environment that can be used to test your custom
application scripts locally before packaging your application with Stacksmith.
See the
[Stacksmith template documentation](https://stacksmith.bitnami.com/support/choosing-a-stack-template)
for more details about specific templates.

Testing your scripts locally requires [docker](https://www.docker.com/) and
[docker-compose](https://docs.docker.com/compose/install/). Although the
environment strives to be the same as a virtual machine, certain aspects may cause
differences such as:

* the docker environment does not run systemd so any scripts that interact
  with systemd directly will not work in this environment,
* scripts which rely on SELinux enablement or enforcement may not work as
  expected as the container host controls the SELinux rules.

## Getting Started from an example

You can start from an example application to familiarize yourself with the
local build environment. First, ensure you are in the directory to which you
extracted the local build environment, then download the example application and
related scripts with:

```
./download-example-app.sh
```

You can then test the Stacksmith packaging of your app right away with:

```
docker-compose build
```

This will take some time whenever the contents of the `user-uploads` directory
changes, but will be fast afterwards as you iterate on any user scripts and
rebuild.

## Updating your build script and rebuilding

In the `./user-scripts` directory are some scripts: `build.sh`, `boot.sh`
and possibly a `run.sh`. Depending on the Stacksmith template
you are using, one or more of these can be customized. Update the
`user-scripts/build.sh` so that it does something different than the default:

```
  echo "yum install -y figlet && figlet 'Stacksmith User Build'" >> user-scripts/build.sh
```

Note figlet is just an ascii-art rendering tool. Now rebuild:

```
  docker-compose build
```

You should see the ascii-art from your `build.sh` in the resulting output.

You can edit and rebuild your app locally until you are happy with the result.

## Testing the running of your application

Most Stacksmith templates are for multi-tier applications which depend on other
services (such as a database or other storage) and therefore your run-time
scripts may depend on these other services. With this in mind, the included
docker-compose file sets up the other tiers for the chosen template:

```
  docker-compose up
```

This will start any other services (such as a database) together with your
application and show the output. Once running, you can test your application
by opening a browser at `http://localhost:8080`

NOTE: if your application runs on a non-standard port, you will need to update
the ports specified for your app in the `docker-compose.yaml`.

## Debugging run-time errors in scripts

Let's introduce an error in our runtime script. Use CTRL-C to stop the local
environment, and then:

```
  echo "figlet 'Bang' && exit 1" >> ./user-scripts/boot.sh
```

Rebuild your application and run again with:

```
  docker-compose build
  docker-compose up
```

You will now see that your script exited (after some nice ascii art). You can
get a terminal to debug your application with:

```
docker-compose run --entrypoint bash app
```

Now you can run the boot script directly to see the error:

```
  /boot.sh
```

Use your favourite text editor on the container to edit the user boot script:

```
  vi /opt/stacksmith/user-scripts/boot.sh
```

and remove the last line which we added above. You can then re-run the
`/boot.sh` to see it now complete successfully. Exit the container, edit
the local file with the changes from your debugging (removing the last line),
rebuild and run to see the app working again.

## Creating or updating your Stacksmith application

Once you are satisfied with the result you can create (or update) an app in
Stacksmith. Upload all the files from `user-uploads` as application files, and
the corresponding scripts that you've worked on from `user-scripts/` then click
on Create to start your packaging!
