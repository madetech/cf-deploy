require 'cf/deploy/version'
require 'cf/deploy/config'
require 'cf/deploy/env_config'
require 'cf/deploy/commands'
require 'rake'

module CF
  class Deploy
    class << self
      def rake_tasks!(&block)
        new(:config => Config.new(&block), :commands => Commands.new).rake_tasks!
      end
    end

    attr_accessor :config, :cf

    def initialize(config)
      @config = config[:config]
      @cf = config[:commands]
    end

    def rake_tasks!
      [define_login_task].concat(deploy_tasks)
    end

    def deploy_tasks
      config[:environments].map { |env| define_deploy_task(env) }
    end

    def define_login_task
      return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

      Rake::Task.define_task('cf:login') do
        cf.login(config)
      end
    end

    def define_deploy_task(env)
      blue_green_task(env) if env[:deployments].size > 1

      env[:deployments].each do |deployment|
        Rake::Task.define_task(deployment[:task_name] => env[:deps]) do
          deployment[:app_names].each do |app_name|
            cf.stop(app_name)
            unless cf.update(app_name)
              raise "Failed to deploy #{deployment}"
            end
            cf.start(app_name)
          end

          env[:routes].each do |route|
            deployment[:app_names].each do |app_name|
              cf.map_route(route, app_name)
            end
          end
        end
      end
    end

    def first_domain(env)
      if env[:routes].empty?
        raise 'Blue/green deploys require at least one route'
      end

      env[:routes].first.values_at(:host, :domain).compact.join('.')
    end

    def next_production(env)
      cf.current_production(first_domain(env)) != 'blue' ? 'blue' : 'green'
    end

    def blue_green_task(env)
      Rake::Task.define_task(env[:task_name] => env[:deps]) do
        task_name = EnvConfig.task_name("#{env[:name]}_#{next_production(env)}")
        Rake::Task[task_name].invoke
      end
    end
  end
end
