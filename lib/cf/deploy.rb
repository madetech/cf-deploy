require 'cf/deploy/version'
require 'rake'
require 'yaml'

module CF
  class Deploy
    class << self
      def rake_tasks!(&block)
        config = Config.new
        config.instance_eval(&block) if block_given?
        new(config).tasks
      end
    end

    class EnvConfig < Hash
      def initialize(env, &block)
        if env.is_a?(Hash)
          name, deps = env.first
          deps = (['cf:login'] << deps).flatten
        else
          name = env
          deps = ['cf:login']
        end

        merge!({:name => name,
                :deps => deps,
                :routes => [],
                :app_names => []})

        instance_eval(&block) if block_given?
      end

      def manifest(manifest)
        self[:manifest] = manifest
        extract_apps!
      end

      def route(domain, hostname = nil)
        self[:routes] << {:domain => domain, :hostname => hostname}
      end

      def extract_apps!
        manifest = YAML.load_file(self[:manifest])

        if manifest.has_key?('applications')
          merge!(:app_names => manifest['applications'].map { |a| a['name'] })
        end
      end
    end

    class Config < Hash
      VALID_CF_KEYS = [:api, :username, :password, :organisation, :space]

      def initialize
        self[:manifest_glob] = 'manifests/*.yml'
        self[:environments] = {}
      end

      def [](key)
        from_env(key) || super
      end

      def from_env(key)
        ENV["CF_#{key.upcase}"] if VALID_CF_KEYS.include?(key)
      end

      def environment_config(manifest)
        env = File.basename(manifest, '.yml').to_sym

        if self[:environments].has_key?(env)
          env_config = self[:environments][env]
        else
          env_config = EnvConfig.new(env)
        end

        env_config.manifest(manifest)
        env_config
      end

      def manifest_glob(glob) self[:manifest_glob] = glob end
      def api(api) self[:api] = api end
      def username(username) self[:username] = username end
      def password(password) self[:password] = password end
      def organisation(organisation) self[:organisation] = organisation end
      def space(space) self[:space] = space end

      def environment(env, &block)
        env_config = EnvConfig.new(env, &block)
        self[:environments].merge!(env_config[:name] => env_config)
      end
    end

    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def manifests
      Dir[config[:manifest_glob]]
    end

    def tasks
      [login_task].concat(manifests.map { |manifest| deploy_task(manifest) })
    end

    def login_task
      return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

      Rake::Task.define_task('cf:login') do
        login_cmd = ['cf login']

        login_cmd << Config::VALID_CF_KEYS
          .reject { |key| config[key].nil? }
          .map { |key| "-#{key.to_s[0]} #{config[key]}" }

        Kernel.system(login_cmd.flatten.join(' '))
      end
    end

    def deploy_task(manifest)
      env = config.environment_config(manifest)
      task_name = "cf:deploy:#{env[:name]}"

      Rake::Task.define_task(task_name => env[:deps]) do
        Kernel.system("cf push -f #{manifest}")

        env[:routes].each do |route|
          env[:app_names].each do |app_name|
            map_cmd = "cf map-route #{app_name} #{route[:domain]}"
            map_cmd = "#{map_cmd} -n #{route[:hostname]}" unless route[:hostname].nil?
            Kernel.system(map_cmd)
          end
        end
      end
    end
  end
end
