module CF
  class Deploy
    class Commands
      def login(config)
        login_cmd = ['cf login']

        login_cmd << Config::VALID_CF_KEYS
          .reject { |key| config[key].nil? }
          .map { |key| "-#{key.to_s[0]} #{config[key]}" }

        Kernel.system(login_cmd.flatten.join(' '))
      end

      def push(manifest)
        Kernel.system("cf push -f #{manifest}")
      end

      def stop(app_name)
        Kernel.system("cf stop #{app_name}")
      end

      def map_route(route, app_name)
        map_cmd = "cf map-route #{app_name} #{route[:domain]}"
        map_cmd = "#{map_cmd} -n #{route[:hostname]}" unless route[:hostname].nil?
        Kernel.system(map_cmd)
      end

      def unmap_route(route, app_name)
        unmap_cmd = "cf unmap-route #{app_name} #{route[:domain]}"
        unmap_cmd = "#{unmap_cmd} -n #{route[:hostname]}" unless route[:hostname].nil?
        Kernel.system(unmap_cmd)
      end

      def current_production(host)
        io = IO.popen("cf routes | grep '#{host}'")
        matches = /(blue|green)/.match(io.read)
        io.close
        return if matches.nil?
        matches[1].strip
      end
    end
  end
end
