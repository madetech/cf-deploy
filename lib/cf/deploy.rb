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
      def self.task_name(name)
        "cf:deploy:#{name}"
      end

      def initialize(env, &block)
        if env.is_a?(Hash)
          name, deps = env.first
          deps = (['cf:login'] << deps).flatten
        else
          name = env
          deps = ['cf:login']
        end

        merge!({:name => name,
                :task_name => EnvConfig.task_name(name),
                :deps => deps,
                :routes => [],
                :app_names => []})

        instance_eval(&block) if block_given?
      end

      def manifests(manifests)
        self[:manifests] = manifests
        extract_apps!
      end

      def route(domain, hostname = nil)
        self[:routes] << {:domain => domain, :hostname => hostname}
      end

      def extract_apps!
        app_names = self[:manifests].reduce([]) do |app_names, manifest_path|
          manifest = YAML.load_file(manifest_path)

          if manifest.has_key?('applications')
            app_names.concat(manifest['applications'].map { |a| a['name'] })
          else
            app_names
          end
        end

        merge!(:app_names => app_names)
      end
    end

    class Config < Hash
      VALID_CF_KEYS = [:api, :username, :password, :organisation, :space]

      def initialize
        self[:manifest_glob] = 'manifests/*'
        self[:environments] = {}
      end

      def [](key)
        from_env(key) || super
      end

      def from_env(key)
        ENV["CF_#{key.upcase}"] if VALID_CF_KEYS.include?(key)
      end

      def environment_config(env)
        if self[:environments].has_key?(env)
          self[:environments][env]
        else
          EnvConfig.new(env)
        end
      end

      def environment_config_for_manifest(manifest)
        env = File.basename(manifest, '.yml').to_sym
        env_config = environment_config(env)
        env_config.manifests([manifest])
        env_config
      end

      def environment_config_for_blue_green(env, manifests)
        env_config = environment_config(env)
        env_config.manifests(manifests)
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

    def blue_green
      manifests = Dir["#{config[:manifest_glob]}{_blue,_green}.yml"].reduce({}) do |envs, manifest|
        if manifest =~ /_blue.yml$/
          env = File.basename(manifest, '_blue.yml').to_sym
        elsif manifest =~ /_green.yml$/
          env = File.basename(manifest, '_green.yml').to_sym 
        else
          return envs
        end

        envs[env] ||= []
        envs[env] << manifest
        envs
      end
    end

    def tasks
      [login_task].concat(manifests.map { |manifest| deploy_task(manifest) })
                  .concat(blue_green.map { |(env, manifests)| blue_green_task(env, manifests) })
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
      env = config.environment_config_for_manifest(manifest)

      Rake::Task.define_task(env[:task_name] => env[:deps]) do
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

    def blue_green_task(env, manifests)
      env = config.environment_config_for_blue_green(env, manifests)

      Rake::Task.define_task(env[:task_name] => env[:deps]) do
        task_name = EnvConfig.task_name("#{env[:name]}_#{next_production(env)}")
        Rake::Task[task_name].invoke
      end
    end
  end
end
