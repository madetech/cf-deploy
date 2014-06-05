require 'cf/deploy/version'
require 'rake'

module CF
  class Deploy
    class << self
      include Rake::DSL

      def install_tasks!(&block)
        config = Config.new
        config.instance_eval(&block) if block_given?

        new(config).tasks.each do |(name, deps)|
          task(name => deps)
        end
      end
    end

    class Config < Hash
      def initialize
        self[:environments] = {}
      end

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
      [login_task].concat(manifests.map { |manifest| build_task(manifest) })
    end

    def login_task
      task_block = Proc.new do
        login_cmd = ['cf login']

        login_cmd << [:api, :organisation, :space, :username, :password].map { |detail|
          "-#{detail.to_s[0]} #{value}" if value = config.send(detail)
        }.reject(&:nil?)

        system(login_cmd.flatten.join(' '))
      end

      ['cf:login', [], task_block]
    end

    def build_task(manifest)
      env = File.basename(manifest, '.yml').to_sym
      task_name = "cf:deploy:#{env}"

      if config[:environments].has_key?(env)
        task_deps = config[:environments][env][:deps]
      else
        task_deps = []
      end

      task_block = Proc.new do
      end

      [task_name, (['cf:login'] << task_deps).flatten]
    end

    def manifests
      Dir['manifests/*.yml']
    end
  end
end
