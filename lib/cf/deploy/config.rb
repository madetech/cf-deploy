module CF
  class Deploy
    class Config < Hash
      VALID_CF_TARGET_KEYS = [:api]
      VALID_CF_LOGIN_KEYS = [:email, :password]

      attr_reader :environments_to_be_loaded

      def initialize(&block)
        @environments_to_be_loaded = []

        merge!(:manifest_glob => 'manifests/*',
               :api => nil,
               :email => nil,
               :password => nil,
               :organisation => nil,
               :space => nil)

        instance_eval(&block) if block_given?

        self[:environments] = environments(manifests_by_env)
      end

      def [](key)
        from_env(key) || super
      end

      def from_env(key)
        ENV["CF_#{key.upcase}"] if VALID_CF_LOGIN_KEYS.include?(key)
      end

      def manifests_by_env
        Dir[self[:manifest_glob]].reduce({}) do |envs, manifest|
          env = manifest_env(manifest)
          envs[env] ||= []
          envs[env] << manifest
          envs
        end
      end

      def manifest_env(manifest)
        if manifest =~ /_blue.yml$/
          File.basename(manifest, '_blue.yml').to_sym
        elsif manifest =~ /_green.yml$/
          File.basename(manifest, '_green.yml').to_sym
        else
          File.basename(manifest, '.yml').to_sym
        end
      end

      def environments(manifests_by_env)
        environments = []

        environments_to_be_loaded.each do |(env, block)|
          if env.is_a?(Hash)
            name, deps = env.first
            deps = (['cf:login'] << deps).flatten
          else
            name = env
            deps = ['cf:login']
          end

          manifests = manifests_by_env.delete(name) || []
          environments << EnvConfig.new(name, deps, manifests, &block)
        end

        manifests_by_env.each do |(name, manifests)|
          environments << EnvConfig.new(name, ['cf:login'], manifests)
        end

        environments
      end

      # Config setter methods
      #
      def manifest_glob(glob) self[:manifest_glob] = glob end
      def api(api) self[:api] = api end
      def email(email) self[:email] = email end
      def password(password) self[:password] = password end
      def organisation(organisation) self[:organisation] = organisation end
      def space(space) self[:space] = space end
      def environment(env, &block) @environments_to_be_loaded << [env, block] end
    end
  end
end
