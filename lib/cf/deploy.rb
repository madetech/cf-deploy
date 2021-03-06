require 'cf/deploy/version'
require 'cf/deploy/config'
require 'cf/deploy/env_config'
require 'cf/deploy/commands'
require 'cf/deploy/blue_green'
require 'rake'

module CF
  class Deploy
    class << self
      def rake_tasks!(&block)
        new(config: Config.new(&block), commands: Commands.new).rake_tasks!
      end
    end

    attr_accessor :config_task, :config, :cf

    def initialize(config_task)
      @config_task = config_task
      @config = config_task[:config]
      @cf = config_task[:commands]
    end

    def rake_tasks!
      [define_login_task].concat(deploy_tasks)
    end

    def deploy_tasks
      config[:environments].map { |env| define_deploy_tasks(env) }
    end

    def define_login_task
      return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

      task = Rake::Task.define_task('cf:login') { cf.login(config) }
      task.add_description('Login to cf command line')
    end

    def define_deploy_tasks(env)
      BlueGreen.new(env, config_task) if env[:deployments].size > 1

      env[:deployments].each do |deployment|
        define_deploy_task(env, deployment)
      end
    end

    def define_deploy_task(env, deployment)
      task = Rake::Task.define_task(deployment[:task_name] => env[:deps]) do
        unless cf.push(deployment[:manifest])
          raise "Failed to deploy #{deployment}"
        end

        env[:routes].reject { |r| r[:flip] == true }.each do |route|
          deployment[:app_names].each do |app_name|
            cf.map_route(route, app_name)
          end
        end

        deployment[:apps].each do |app|
          unless env[:runtime_memory].nil? and app[:runtime_memory].nil?
            cf.scale_memory(app[:name], env[:runtime_memory] || app[:runtime_memory])
          end

          unless env[:runtime_instances].nil? and app[:runtime_instances].nil?
            cf.scale_instances(app[:name], env[:runtime_instances] || app[:runtime_instances])
          end
        end
      end

      task.add_description("Deploy #{deployment[:app_names].join(', ')}")
    end
  end
end
