require 'yaml'
require 'pathname'

module CF
  class Deploy
    class EnvConfig < Hash
      def self.task_name(name)
        "cf:deploy:#{name}"
      end

      def initialize(name, deps, manifests, &block)
        merge!(name: name,
               task_name: EnvConfig.task_name(name),
               deps: deps,
               routes: [],
               runtime_memory: nil,
               manifests: manifests)

        instance_eval(&block) if block_given?

        raise "No manifests found for #{name}" if manifests.empty?

        self[:deployments] = deployments
      end

      def deployments
        self[:manifests].map { |manifest| deployment_for_manifest(manifest) }
      end

      def deployment_for_manifest(manifest)
        { task_name: deployment_task_name(manifest),
          manifest: manifest,
          app_names: app_names_for_manifest(manifest),
          apps: apps_for_manifest(manifest) }
      end

      def deployment_task_name(manifest)
        if self[:manifests].size > 1
          EnvConfig.task_name(File.basename(manifest, '.yml').to_sym)
        else
          self[:task_name]
        end
      end

      def apps_for_manifest(manifest)
        config = YAML.load_file(manifest)

        if config['applications'].nil?
          raise "No applications defined in YAML manifest #{manifest}"
        end

        config['applications'].map do |app|
          app.reduce({}) { |app, (k, v)| app.merge(k.to_sym => v) }
        end
      end

      def app_names_for_manifest(manifest)
        apps_for_manifest(manifest).map { |a| a[:name] }
      end

      def app_name_for_colour(colour)
        self[:manifests].map do |manifest|
          name = app_names_for_manifest(File.expand_path(manifest.to_s)).first
          return name if name.include?(colour)
        end
      end

      def app_names_for_colour(colour)
        self[:manifests].flat_map do |manifest|
          names = app_names_for_manifest(File.expand_path(manifest.to_s))
          names if names.first.include?(colour)
        end.compact
      end

      # Environment config setter methods
      #
      def manifest(manifest)
        self[:manifests] << manifest
      end

      def manifests(manifests)
        self[:manifests].concat(manifests)
      end

      def runtime_memory(memory)
        self[:runtime_memory] = memory
      end

      def route(domain, hostname_or_options = nil, options = nil)
        if options.nil?
          if hostname_or_options.nil?
            hostname = nil
            options = {}
          elsif hostname_or_options.is_a?(String)
            hostname = hostname_or_options
            options = {}
          else
            hostname = nil
            options = hostname_or_options
          end
        else
          hostname = hostname_or_options
        end

        self[:routes] << { domain: domain, hostname: hostname }.merge(options)
      end

      def flip_route(domain, hostname = nil)
        self[:routes] << { domain: domain, hostname: hostname, flip: true }
      end
    end
  end
end
