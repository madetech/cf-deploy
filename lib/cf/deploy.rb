require 'cf/deploy/version'
require 'cf/deploy/config'
require 'cf/deploy/env_config'
require 'cf/deploy/commands'
require 'cf/deploy/blue_green'
require 'cf/deploy/canary'
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
      config[:environments].map { |env| define_deploy_tasks(env, config[:environments]) }
    end

    def define_login_task
      return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

      task = Rake::Task.define_task('cf:login') { cf.login(config) }
      task.add_description('Login to cf command line')
    end

    def define_deploy_tasks(current_env, environments)
      if Canary.canary_defined?(environments) and Canary.is_canary_environment?(current_env)
        Canary.new(current_env, config_task, environments)
      elsif BlueGreen.is_blue_green_environment?(current_env)
        BlueGreen.new(current_env, config_task)
      end

      current_env[:deployments].each do |deployment|
        define_deploy_task(current_env, deployment)
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
        end
      end

      task.add_description("Deploy #{deployment[:app_names].join(', ')}")
    end
  end
end
