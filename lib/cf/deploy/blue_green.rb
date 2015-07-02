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
        task_name = EnvConfig.task_name("#{env[:name]}_#{idle_color(env)}")

        task = Rake::Task.define_task(env[:task_name] => env[:deps]) do
          Rake::Task[task_name].invoke
        end

        task.add_description(Rake::Task[task_name].full_comment)
      end

      def define_flip_task
        live_app_name = app_name_from_color(live_color(env))
        idle_app_name = app_name_from_color(idle_color(env))

        task = Rake::Task.define_task("#{env[:task_name]}:flip" => 'cf:login') do
          flip_routes(env).each do |route|
            cf.map_route(route, idle_app_name)
            cf.unmap_route(route, live_app_name)
          end
        end

        task.add_description("Flip routes to point at #{idle_app_name}")
      end

      def define_stop_idle_task
        idle_apps = env.app_names_for_colour(idle_color(env))

        task = Rake::Task.define_task("#{env[:task_name]}:stop_idle" => 'cf:login') do
          idle_apps.each do |app_name|
            cf.stop(app_name)
          end
        end

        task.add_description("Stop #{idle_apps.join(', ')} since they are idle")
      end

      def app_name_from_color(colour)
        env.app_name_for_colour(colour)
      end

      def flip_routes(env)
        env[:routes].select { |r| r[:flip] == true }
      end

      def flip_routes_sorted_by_hostname(env)
        flip_routes(env).sort do |a, b|
          a[:hostname] && a[:hostname].length > 0 ? -1 : 1
        end
      end

      def match_flip_route_grep(env)
        if flip_routes(env).empty?
          raise 'Blue/green deploys require at least one flip_route'
        end

        flip_routes_sorted_by_hostname(env).first.values_at(:hostname, :domain).compact.join(' *')
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
