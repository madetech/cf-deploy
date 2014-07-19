require 'yaml'

module CF
  class Deploy
    class EnvConfig < Hash
      def self.task_name(name)
        "cf:deploy:#{name}"
      end

      def initialize(name, deps, manifests, &block)
        merge!(:name => name,
               :task_name => EnvConfig.task_name(name),
               :deps => deps,
               :routes => [],
               :manifests => manifests)

        instance_eval(&block) if block_given?

        self[:deployments] = deployments
      end

      def deployments
        self[:manifests].map { |manifest| deployment_for_manifest(manifest) }
      end

      def deployment_for_manifest(manifest)
        if self[:manifests].size > 1
          task_name = EnvConfig.task_name(File.basename(manifest, '.yml').to_sym)
        else
          task_name = self[:task_name]
        end

        {:task_name => task_name,
         :manifest => manifest,
         :app_names => app_names_for_manifest(manifest)}
      end

      def app_names_for_manifest(manifest)
        YAML.load_file(manifest)['applications'].map { |a| a['name'] }
      end

      # Environment config setter methods
      #
      def manifest(manifest)
        self[:manifests] << manifest
      end

      def manifests(manifests)
        self[:manifests].concat(manifests)
      end

      def route(domain, hostname = nil)
        self[:routes] << {:domain => domain, :hostname => hostname}
      end
    end
  end
end
