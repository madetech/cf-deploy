module CF
  class Deploy
    class Commands

      def target(config)
        target_cmd = ['vmc target']
        target_cmd << Config::VALID_CF_TARGET_KEYS
          .reject { |key| config[key].nil? }
          .map { |key| "#{config[key]}" }

        Kernel.system(target_cmd.flatten.join(' '))
      end

      def login(config)
        target(config)

        login_cmd = ['vmc login']
        login_cmd << Config::VALID_CF_LOGIN_KEYS
          .reject { |key| config[key].nil? }
          .map { |key| "--#{key} #{config[key]}" }

        Kernel.system(login_cmd.flatten.join(' '))
      end

      def update(app_name)
        Kernel.system("vmc update #{app_name}")
      end

      def stop(app_name)
        Kernel.system("vmc stop #{app_name}")
      end

      def start(app_name)
        Kernel.system("vmc start #{app_name}")
      end

      def map_route(route, app_name)
        map_cmd = "vmc map #{app_name} #{route[:domain]}"
        map_cmd = "#{map_cmd} -n #{route[:hostname]}" unless route[:hostname].nil?
        Kernel.system(map_cmd)
      end

      def current_production(domain)
        io = IO.popen("vmc routes | grep #{domain}")
        matches = /(blue|green)/.match(io.read)
        io.close
        return if matches.nil?
        matches[1].strip
      end
    end
  end
end
