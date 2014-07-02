require 'yaml'

module CF
  class Deploy
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
        app_names = self[:manifests].reduce({}) do |app_names, manifest_path|
          manifest = YAML.load_file(manifest_path)

          if manifest.has_key?('applications')
            app_names.merge(manifest_path => manifest['applications'].map { |a| a['name'] })
          else
            app_names
          end
        end

        merge!(:app_names => app_names)
      end
    end
  end
end
