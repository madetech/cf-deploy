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
          task_name = EnvConfig.task_name("#{env[:name]}_#{next_production(env)}")
          Rake::Task[task_name].invoke
        end

        Rake::Task.define_task("cf:deploy:production:flip") do
          cf.login(config)

          current_env = app_name_from_color(current_production(env))
          next_env = app_name_from_color(next_production(env))

          env[:flip_routes].each do |route|
            cf.map_route(route, "#{next_env}")
            cf.unmap_route(route, "#{current_env}")
          end
        end
      end

      def define_login_task
        return Rake::Task['cf:login'] if Rake::Task.task_defined?('cf:login')

        Rake::Task.define_task('cf:login') do
          cf.login(config)
        end
      end

      def app_name_from_color(colour)
        env.app_name_for_colour(colour)
      end

      def match_flip_route_grep(env)
        if env[:flip_routes].empty?
          raise 'Blue/green deploys require at least one flip_route'
        end

        env[:flip_routes].first.values_at(:hostname, :domain).compact.join(' *')
      end

      def current_production(env)
        cf.current_production(match_flip_route_grep(env))
      end

      def next_production(env)
        current_production(env) != 'blue' ? 'blue' : 'green'
      end

    end
  end
end
