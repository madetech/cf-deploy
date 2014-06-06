require 'cf/deploy/version'
require 'rake'

module CF
  class Deploy
    class << self
      def install_tasks!(&block)
        config = Config.new
        config.instance_eval(&block) if block_given?
        new(config).tasks
      end
    end

    class Config < Hash
      VALID_KEYS = [:api, :username, :password, :organisation, :space]

      def initialize
        self[:manifest_glob] = 'manifests/*.yml'
        self[:environments] = {}
      end

      def [](key)
        super || from_env(key)
      end

      def from_env(key)
        raise "Invalid key #{key}" unless VALID_KEYS.include?(key)
        ENV["CF_#{key.upcase}"]
      end

      def manifest_glob(glob) self[:manifest_glob] = glob end
      def api(api) self[:api] = api end
      def username(username) self[:username] = username end
      def password(password) self[:password] = password end
      def organisation(organisation) self[:organisation] = organisation end
      def space(space) self[:space] = space end

      def environment(env)
        if env.is_a?(Hash)
          name, deps = env.first
          self[:environments][name] = {:name => name, :deps => deps}
        end
      end
    end

    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def tasks
      [login_task].concat(manifests.map { |manifest| deploy_task(manifest) })
    end

    def login_task
      return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

      Rake::Task.define_task('cf:login') do
        login_cmd = ['cf login']

        login_cmd << Config::VALID_KEYS
          .reject { |key| config[key].nil? }
          .map { |key| "-#{key.to_s[0]} #{config[key]}" }

        Kernel.system(login_cmd.flatten.join(' '))
      end
    end

    def deploy_task(manifest)
      env = File.basename(manifest, '.yml').to_sym

      task_name = "cf:deploy:#{env}"
      task_deps = ['cf:login']

      if config[:environments].has_key?(env)
        task_deps << config[:environments][env][:deps]
      end

      Rake::Task.define_task(task_name => task_deps.flatten) do
        Kernel.system("cf push -f #{manifest}")
      end
    end

    def manifests
      Dir[config[:manifest_glob]]
    end
  end
end
