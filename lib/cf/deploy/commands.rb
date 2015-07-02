module CF
  class Deploy
    class Commands
      def login(config)
        login_cmd = ['cf login']

        login_cmd << Config::VALID_CF_KEYS
          .reject { |key| config[key].nil? }
          .map { |key| "-#{key.to_s[0]} '#{config[key]}'" }

        Kernel.system(login_cmd.flatten.join(' '))
      end

      def push(manifest)
        Kernel.system("cf push -f #{manifest}")
      end

      def stop(app_name)
        Kernel.system("cf stop #{app_name}")
      end

      def scale_memory(app_name, memory)
        Kernel.system("cf scale #{app_name} -m #{memory}")
      end

      def map_route(route, app_name)
        Kernel.system(route_cmd(:map, route, app_name))
      end

      def unmap_route(route, app_name)
        Kernel.system(route_cmd(:unmap, route, app_name))
      end

      def live_color(host)
        io = IO.popen("cf routes | grep '#{host}'")
        matches = /(blue|green)/.match(io.read)
        io.close
        return if matches.nil?
        matches[1].strip
      end

      private

      def route_cmd(method, route, app_name)
        map_cmd = "cf #{method}-route #{app_name} #{route[:domain]}"
        map_cmd = "#{map_cmd} -n #{route[:hostname]}" unless route[:hostname].nil?
        map_cmd
      end
    end
  end
end
