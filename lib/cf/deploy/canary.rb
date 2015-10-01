module CF
  class Deploy
    class Canary
      def self.canary_defined?(environments)
        environments.each do |env|
          return true if env[:name] == :canary
        end
      end

      def self.is_canary_environment?(env)
        env[:name] == :canary
      end

      attr_accessor :env, :config_task, :config, :cf, :environments

      def initialize(env, config_task, environments)
        @env = env
        @config_task = config_task
        @config = config_task[:config]
        @cf = config_task[:commands]
        @environments = environments

        define_canary_clean_task
        define_canary_trial_task

        env[:deps] << 'cf:canary:clean'
      end

      private

      def define_canary_clean_task
        task = Rake::Task.define_task('cf:canary:clean' => env[:deps]) do
          production_environment[:routes].each do |route|
            env[:deployments].each do |deployment|
              deployment[:app_names].each do |app_name|
                cf.unmap_route(route, app_name)
              end
            end
          end
        end

        task.add_description("Unmap production routes from new canary")
      end

      def define_canary_trial_task
        task = Rake::Task.define_task('cf:canary:trial' => env[:deps]) do
          production_environment[:routes].each do |route|
            env[:deployments].each do |deployment|
              deployment[:app_names].each do |app_name|
                cf.map_route(route, app_name)
              end
            end
          end
        end

        task.add_description("Map production routes to new canary")
      end

      def production_environment
        environments.select { |env| env[:name] == :production }.first
      end
    end
  end
end
