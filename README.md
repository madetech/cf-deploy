# Rake tasks for deploying to CloudFoundry v6+

[![Code Climate](https://codeclimate.com/github/madebymade/cf-deploy/badges/gpa.svg)](https://codeclimate.com/github/madebymade/cf-deploy)
[![Build Status](https://travis-ci.org/madebymade/cf-deploy.svg?branch=master)](https://travis-ci.org/madebymade/cf-deploy)
[![Test Coverage](https://codeclimate.com/github/madebymade/cf-deploy/badges/coverage.svg)](https://codeclimate.com/github/madebymade/cf-deploy)

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

``` ruby
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
`cf push -f manifests/production.yml`. Not really anything helpful or new.
Things start to get more exciting when you define your environments in your
`Rakefile` along with their task dependencies just like normal rake task syntax.

``` ruby
require 'cf-deploy'

CF::Deploy.rake_tasks! do
  environment :staging => 'assets:precompile'
  environment :production => [:clean, 'assets:precompile']
end
```

Now when running `cf:deploy:staging` and `cf:deploy:production` the prerequisite
tasks will be run first.

The next thing to talk about is route mapping. You can define a route in a an
environment block like so:

``` ruby
require 'cf-deploy'

CF::Deploy.rake_tasks! do
  environment :staging => 'assets:precompile' do
    route 'example.com', 'staging'
  end

  environment :production => [:clean, 'assets:precompile'] do
    route 'example.com'
    route 'example.com', 'admin'
    flip_route 'yourwebsite.com', 'www'
    flip_route 'yourwebsite.com', 'www-origin'
  end
end
```

As soon as an environment with routes is pushed successfully each of it's routes
will be mapped to all the applications defined in the environment's manifest.

And then things get super interesting when you start talking blue/green.

## What is blue/green deployment?

Simply put, blue/green deployment allows you to deploy a new version of your
app, test it on a private URL and then direct your traffic to the new version
when you are ready.

You have two applications for one environment, say production. One version is
called green, the other is blue. The first time you deploy your environment
either green or blue can be deployed. Thereafter, any changes you want to deploy
you deploy to the color that doesn't have your production domain pointed at it.
You test it on a private URL and then when you're happy you flip your domain to
point at that. If something then goes wrong you can then flip your domain back
to the last working version.

This gem provides rake tasks for you to deploy using this methodology as well
as the standard single app deployment process on a CloudFoundry provider.

### An example of blue/green

Examples always help and this example is probably the most common use case. You
might have a straight forward deployment for staging but use the blue/green
strategy for production. Here is what your Rakefile might look like:

``` ruby
require 'cf-deploy'

CF::Deploy.rake_tasks! do
  environment :staging => 'assets:precompile'

  environment :production => 'assets:precompile' do
    route 'example-app.io'
    flip_route 'yourwebsite.com', 'www'
    flip_route 'yourwebsite.com', 'www-origin'
  end
end
```

You should also have three manifests defined:

 - `manifests/staging.yml`
 - `manifests/production_blue.yml`
 - `manifests/production_green.yml`

When you run `cf:deploy:production` for the first time (assuming neither
`production_blue.yml` or `production_green.yml` are deployed) your blue app will
be deployed and route setup.

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

``` ruby
gem 'cf-deploy', '0.1.1'
```

### Defining CloudFoundry details in your Rakefile

You can configure some or all of your CloudFoundry details when calling
`CF::Deploy.rake_tasks!`.

``` ruby
require 'cf-deploy'

CF::Deploy.rake_tasks! do
  api 'api.run.pivotal.io'
  username 'example@example.com'
  password 'SOMETHING'
  organisation 'Made'
  space 'development'

  environment :staging => 'assets:precompile'

  environment :production => 'assets:precompile' do
    flip_route 'yourwebsite.com', 'www'
  end
end
```

All are optional. If you do not provide any you will be prompted when running
the rake tasks.

### Defining CloudFoundry details using ENV variables

Instead of defining your CloudFoundry login details in your Rakefile and
committing them to your code repository you can instead provide them using
ENV variables on your command line:

``` sh
export CF_API=api.run.pivotal.io
export CF_USERNAME=example@example.com
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

If you have defined CloudFoundry manifest files matching `manifests/*_blue.yml`
and `manifests/*_green.yml` you will be able to call `rake cf:deploy:*` without
the `_blue` or `_green`. For example with `production_blue.yml` and
`production_green.yml` you can call the following:

```
bundle exec rake cf:deploy:production
```

Running the deploy task for an env with blue and green manifests will trigger a
lookup to see which env is currently deployed. The task will then start
deploying the other production color, so if green is currently deployed then
blue will be deployed. If neither is currently deployed, blue will be deployed
first.

Once deployed your routing will still be pointing to the *previous deployment*.
If you run the same task again, the same environment will be deployed. That is
if green was deployed, and then you run the task, blue will be deployed, if you
run the task again, blue will be deployed again. This is because we work out
the current deployment based on where your routes are pointing and since the
deploy command for blue green environments doesn't map routes the current
deployment will not change.

#### First time proviso

This isn't the case for a first time deploy. The first time you deploy your
blue environment will be deployed and any defined routes will be mapped to all
apps defined in your blue manifest.

### Switch routes over to new environment

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

Developed and maintained by [Made Tech][made]. Key contributions:

 * [Luke Morton](https://github.com/DrPheltRight)

## License

Copyright © 2014 Made Tech Ltd. It is free software, and may be
redistributed under the terms specified in the [MIT-LICENSE][license] file.

[CloudFoundry]: http://www.cloudfoundry.org/
[Pivotal]: https://run.pivotal.io/
[cli]: https://github.com/cloudfoundry/cli/releases
[made]: http://www.madetech.co.uk?ref=github&repo=cf-deploy
[license]: https://github.com/madebymade/cf-deploy/blob/master/LICENSE
