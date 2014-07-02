require 'cf/deploy/version'
require 'cf/deploy/config'
require 'cf/deploy/env_config'
require 'cf/deploy/commands'
require 'rake'

module CF
  class Deploy
    class << self
      def rake_tasks!(&block)
        config = Config.new
        config.instance_eval(&block) if block_given?
        new(config).tasks
      end
    end

    include Commands
    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def manifests
      Dir[config[:manifest_glob]].reduce({}) do |envs, manifest|
        if manifest =~ /_blue.yml$/
          env = File.basename(manifest, '_blue.yml').to_sym
        elsif manifest =~ /_green.yml$/
          env = File.basename(manifest, '_green.yml').to_sym
        else
          env = File.basename(manifest, '.yml').to_sym
        end

        envs[env] ||= []
        envs[env] << manifest
        envs
      end
    end

    def tasks
      [define_login_task].concat(deploy_tasks)
    end

    def deploy_tasks
      manifests.map { |(env, manifests)| define_deploy_task(env, manifests) }
    end

    def define_login_task
      return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

      Rake::Task.define_task('cf:login') do
        login(config)
      end
    end

    def define_deploy_task(env, manifests)
      env = config.environment_config(env, manifests)

      blue_green_task(env) if manifests.size > 1

      manifests.each do |manifest|
        task_name = EnvConfig.task_name(File.basename(manifest, '.yml').to_sym)

        Rake::Task.define_task(task_name => env[:deps]) do
          push(manifest)

          env[:routes].each do |route|
            env[:app_names][manifest].each do |app_name|
              map_route(route, app_name)
            end
          end
        end
      end
    end

    def first_domain(env)
      env[:routes].first.values_at(:host, :domain).compact.join('.')
    end

    def next_production(env)
      current_production(first_domain(env)) != 'blue' ? 'blue' : 'green'
    end

    def blue_green_task(env)
      Rake::Task.define_task(env[:task_name] => env[:deps]) do
        task_name = EnvConfig.task_name("#{env[:name]}_#{next_production(env)}")
        Rake::Task[task_name].invoke
      end
    end
  end
end
