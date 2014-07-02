require 'cf/deploy/version'
require 'cf/deploy/config'
require 'cf/deploy/env_config'
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
      [define_login_task].concat(manifests.map { |(env, manifests)| define_deploy_task(env, manifests) })
    end

    def define_login_task
      return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

      Rake::Task.define_task('cf:login') do
        login_cmd = ['cf login']

        login_cmd << Config::VALID_CF_KEYS
          .reject { |key| config[key].nil? }
          .map { |key| "-#{key.to_s[0]} #{config[key]}" }

        Kernel.system(login_cmd.flatten.join(' '))
      end
    end

    def define_deploy_task(env, manifests)
      env = config.environment_config(env, manifests)

      blue_green_task(env) if manifests.size > 1

      manifests.each do |manifest|
        task_name = EnvConfig.task_name(File.basename(manifest, '.yml').to_sym)

        Rake::Task.define_task(task_name => env[:deps]) do
          Kernel.system("cf push -f #{manifest}")

          env[:routes].each do |route|
            env[:app_names][manifest].each do |app_name|
              map_cmd = "cf map-route #{app_name} #{route[:domain]}"
              map_cmd = "#{map_cmd} -n #{route[:hostname]}" unless route[:hostname].nil?
              Kernel.system(map_cmd)
            end
          end
        end
      end
    end

    def current_production(env)
      domain = env[:routes].first.values_at(:host, :domain).compact.join('.')
      io = IO.popen("cf routes | grep #{domain}")
      matches = /(blue|green)/.match(io.read)
      io.close
      return if matches.nil?
      matches[1].strip
    end

    def next_production(env)
      current_production(env) != 'blue' ? 'blue' : 'green'
    end

    def blue_green_task(env)
      Rake::Task.define_task(env[:task_name] => env[:deps]) do
        task_name = EnvConfig.task_name("#{env[:name]}_#{next_production(env)}")
        Rake::Task[task_name].invoke
      end
    end
  end
end
