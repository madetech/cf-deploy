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

        define_deployment_task
        define_flip_task
        define_stop_idle_task
      end

      private

      def define_deployment_task
        Rake::Task.define_task(env[:task_name] => env[:deps]) do
          task_name = EnvConfig.task_name("#{env[:name]}_#{idle_color(env)}")
          Rake::Task[task_name].invoke
        end
      end

      def define_flip_task
        Rake::Task.define_task("#{env[:task_name]}:flip" => 'cf:login') do
          live_app_name = app_name_from_color(live_color(env))
          idle_app_name = app_name_from_color(idle_color(env))

          flip_routes(env).each do |route|
            cf.map_route(route, idle_app_name)
            cf.unmap_route(route, live_app_name)
          end
        end
      end

      def define_stop_idle_task
        Rake::Task.define_task("#{env[:task_name]}:stop_idle" => 'cf:login') do
          env.app_names_for_colour(idle_color(env)).each do |app_name|
            cf.stop(app_name)
          end
        end
      end

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

      def live_color(env)
        cf.live_color(match_flip_route_grep(env))
      end

      def idle_color(env)
        if live_color(env) != 'blue'
          'blue'
        else
          'green'
        end
      end
    end
  end
end
