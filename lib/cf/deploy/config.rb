module CF
  class Deploy
    class Config < Hash
      VALID_CF_KEYS = [:api, :username, :password, :organisation, :space]

      def initialize
        self[:manifest_glob] = 'manifests/*'
        self[:environments] = {}
      end

      def [](key)
        from_env(key) || super
      end

      def from_env(key)
        ENV["CF_#{key.upcase}"] if VALID_CF_KEYS.include?(key)
      end

      def environment_config(env, manifests)
        if self[:environments].has_key?(env)
          env_config = self[:environments][env]
        else
          env_config = EnvConfig.new(env)
        end

        env_config.manifests(manifests)
        env_config
      end

      def manifest_glob(glob) self[:manifest_glob] = glob end
      def api(api) self[:api] = api end
      def username(username) self[:username] = username end
      def password(password) self[:password] = password end
      def organisation(organisation) self[:organisation] = organisation end
      def space(space) self[:space] = space end

      def environment(env, &block)
        env_config = EnvConfig.new(env, &block)
        self[:environments].merge!(env_config[:name] => env_config)
      end
    end
  end
end
