# Rake tasks for deploying to CloudFoundry v6+

This gem provides the functionality you need to deploy your rails application to
a [CloudFoundry][CloudFoundry] provider like [Pivotal][Pivotal].

With `cf-deploy` you can:

 * Define your CloudFoundry connection details in your Rakefile or using
   environment variables
 * Implement blue/green deployment
 * Hook into your existing rake tasks for preparing deploys/syncing assets

## Basics

The functionality comes in the shape of generated rake tasks. You require this
gem in your `Rakefile` and call the `.rake_tasks!` setup method.

``` Rakefile
require 'cf-deploy'
CF::Deploy.rake_tasks!
```

By default tasks will be created for each manifest in your `manifests/` folder.
If you have a `staging.yml` and `production.yml` you can now run the following
commands:

``` sh
bundle exec rake cf:deploy:staging
bundle exec rake cf:deploy:production
```

This however mimics the commands `cf push -f manifests/staging.yml` and
`cf push -f manifests/staging/yml`. Things start to get more exciting when you
define your environments in your `Rakefile` along with their task dependencies
just like normal rake task syntax.

``` Rakefile
require 'cf-deploy'

CF::Deploy.rake_tasks! do
  environment :staging => 'assets:precompile'
  environment :production => [:clean, 'assets:precompile']
end
```

Now when running `cf:deploy:staging` and `cf:deploy:production` the defined
tasks will be run first.

And then things get super interesting when you start talking blue/green.

## What is blue/green deployment?

Simply put, blue/green deployment allows you to deploy a new version of your
app, test it on a private URL and then direct your traffic to the new version
when you are ready.

You have two applications for one environment, say production. One version is
called green, the other is blue. The first time you deploy your app you either
go to blue or green. Thereafter, any changes you want to deploy you send to the
color that doesn't have your production domain pointed at it. You test it on
a private URL and then when you're happy you flip your domain to point at that.
If something then goes wrong you can then flip your domain back to the last
working version.

This gem provides rake tasks for you to deploy using this methodology as well
as the standard single app deployment process on a CloudFoundry provider.

For example you might have a straight forward deployment for staging but use
the blue/green strategy for production. Here is what your Rakefile might look
like:

``` Rakefile
require 'cf-deploy'

CF::Deploy.rake_tasks! do
  environment :staging => 'assets:precompile'

  environment :production => 'assets:precompile' do
    blue 'example-app-blue'
    green 'example-app-green'
    route 'example-app.io'
  end
end
```

When you run `cf:deploy:production` for the first time (assuming neither
example-app-blue or example-app-green are deployed) your blue app will be
deployed and route setup.

Running `cf:deploy:production` thereafter will deploy which ever version isn't
currently deployed. Your route(s) will not be mapped automatically this time.
Nows your chance to checkout your new deployment using an alternate route. When
you're happy and want to map your route across run:

``` sh
bundle exec rake cf:deploy:production:flip
```

## Installation

You need the `cf` command installed already. Grab the latest release from
the [CloudFoundry CLI][cli] repo on github.

You then need to install this gem in your project's `Gemfile`:

``` Gemfile
gem 'cf-deploy', '0.1.0'
```

### Defining CloudFoundry details in your Rakefile

You can configure some or all of your CloudFoundry details when calling
`CF::Deploy.rake_tasks!`.

``` Rakefile
require 'cf-deploy'

CF::Deploy.rake_tasks! do
  api 'api.run.pivotal.io'
  username 'accounts@madebymade.co.uk'
  password 'SOMETHING'
  org 'Made'
  space 'development'

  environment :staging => 'assets:precompile'

  environment :production => 'assets:precompile' do
    blue 'example-app-blue'
    green 'example-app-green'
    route 'example-app.io'
  end
end
```

All are optional. If you do not provide any you will be prompted when running
the rake tasks.

### Defining CloudFoundry details using ENV variables

Instead of defining your CloudFoundry login details in your Rakefile and
committing then to your code repository you can instead provide them using
ENV variables on your command line:

``` sh
export CF_API=api.run.pivotal.io
export CF_USERNAME=accounts@madebymade.co.uk
export CF_PASSWORD=SOMETHING
export CF_ORG=Made
export CF_SPACE=development
```

Now you can run any of the `cf-deploy` rake tasks providing you have called
`CF::Deploy.rake_tasks!` in your `Rakefile`.

## Commands

### Deploying an environment

If you defined a staging environment in your Rakefile the following task will
have been created:

```
bundle exec rake cf:deploy:staging
```

Run this to deploy out your staging environment.

Any environment you define will have a task created named `cf:deploy:#{env}`.

### Deploy the next blue/green environment

If you defined blue and green app names in your Rakefile for the production
environment you will get blue/green deployment functionality.

```
bundle exec rake cf:deploy:production
```

Running the deploy task for an env with these two settings will trigger a lookup
to see which env is currently deployed. The task will then start deploying
the other production color, so if green is currently deployed then blue will be
deployed. If neither is currently deployed, blue will be deployed first.

Once deployed your routing will still be pointing to the *previous deployment*.
If you run the same task again, the same environment will be deployed. That is
if green was deployed, and then you run the task, blue will be deployed, if you
run the task again, blue will be deployed again. This is because we work out
the current deployment based on where your routes are pointing. *This isn't the
case for a first time deploy, your routes will be setup to your blue env*.

### Switch routes over to new production

In order to flip your routes from blue to green or vice-versa you need to run
the following task.

```
bundle exec rake cf:deploy:production:flip
```

This will go ahead and map routes to whatever color the routes aren't mapped to
and then unmap the other color. At this point your new production will be
deployed and live.

## Credits

[![made](https://s3-eu-west-1.amazonaws.com/made-assets/googleapps/google-apps.png)][made]

Developed and maintained by [Made][made]. Key contributions:

 * [Luke Morton](https://github.com/DrPheltRight)

## License

Copyright © 2014 Made by Made Ltd. It is free software, and may be
redistributed under the terms specified in the [MIT-LICENSE][license] file.

[CloudFoundry]: http://www.cloudfoundry.org/
[Pivotal]: https://run.pivotal.io/
[cli]: https://github.com/cloudfoundry/cli/releases
[made]: http://www.madetech.co.uk?ref=github&repo=ydtd_frontend
[license]: https://github.com/madebymade/cf-deploy/blob/master/LICENSE
