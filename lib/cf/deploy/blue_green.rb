require 'yaml'

module CF
  class Deploy
    class BlueGreen
      attr_accessor :env, :config_task, :config, :cf

      def initialize(env, config_task)
        @env = env
        @config_task = config_task
        @config = config_task[:config]
        @cf = config_task[:commands]

        Rake::Task.define_task(env[:task_name] => env[:deps]) do
          task_name = EnvConfig.task_name("#{env[:name]}_#{next_production_colour(env)}")
          Rake::Task[task_name].invoke
        end

        Rake::Task.define_task('cf:deploy:production:flip') do
          cf.login(config)

          current_app_in_production = app_name_from_color(current_production_colour(env))
          next_app_in_production = app_name_from_color(next_production_colour(env))

          flip_routes(env).each do |route|
            cf.map_route(route, "#{next_app_in_production}")
            cf.unmap_route(route, "#{current_app_in_production}")
          end
        end
      end

      private

      def app_name_from_color(colour)
        env.app_name_for_colour(colour)
      end

      def flip_routes(env)
        env[:routes].select { |r| r[:flip] == true }
      end

      def match_flip_route_grep(env)
        if flip_routes(env).empty?
          raise 'Blue/green deploys require at least one flip_route'
        end

        flip_routes(env).first.values_at(:hostname, :domain).compact.join(' *')
      end

      def current_production_colour(env)
        cf.current_production(match_flip_route_grep(env))
      end

      def next_production_colour(env)
        if current_production_colour(env) != 'blue'
          'blue'
        else
          'green'
        end
      end
    end
  end
end
