require 'spec_helper'
require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  context 'Rake::Task[cf:deploy:XX]' do
    it 'should run a manifest' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/staging.yml').and_return(true).ordered
      Rake::Task['cf:deploy:staging'].invoke
    end

    it 'should setup a route if defined after pushing manifest' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :test do
            route 'testexample.com'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/test.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app testexample.com').ordered
      Rake::Task['cf:deploy:test'].invoke
    end

    it 'should setup a route with a hostname if defined' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :test do
            route 'example.com', 'test'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/test.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app example.com -n test')
      Rake::Task['cf:deploy:test'].invoke
    end

    it 'should setup multiple routes if defined' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :test do
            route 'example.com'
            route 'example.com', '2'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/test.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app example.com').ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app example.com -n 2').ordered
      Rake::Task['cf:deploy:test'].invoke
    end

    it 'should change memory after deployment if runtime_memory specified in manifest' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :staging
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/staging_with_runtime.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf scale staging-app -f -m 256M').and_return(true).ordered
      Rake::Task['cf:deploy:staging_with_runtime'].invoke
    end

    it 'should change memory after deployment if runtime_memory specified in cf:deploy config' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :staging_with_runtime do
            runtime_memory '512M'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/staging_with_runtime.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf scale staging-app -f -m 512M').and_return(true).ordered
      Rake::Task['cf:deploy:staging_with_runtime'].invoke
    end

    it 'should not map routes if push command fails' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :test do
            route 'example.com'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/test.yml').and_return(nil)
      expect(Kernel).to_not receive(:system).with('cf map-route test-app example.com')
      expect do
        Rake::Task['cf:deploy:test'].invoke
      end.to raise_error
    end

    it 'should not map routes if push command returns non-zero status' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :test do
            route 'example.com'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/test.yml').and_return(false)
      expect(Kernel).to_not receive(:system).with('cf map-route test-app example.com')
      expect do
        Rake::Task['cf:deploy:test'].invoke
      end.to raise_error
    end

    it 'should throw decent error if manifest does not exist' do
      expect do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :undefined
        end
      end.to raise_error
    end

    it 'should throw decent error if manifest invalid' do
      expect do
        described_class.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :invalid_manifest do
            manifest 'spec/spec_helper.rb'
          end
        end
      end.to raise_error
    end

    it 'should allow individual manifest to be specified' do
      Dir.chdir('spec/') do
        CF::Deploy.rake_tasks! do
          manifest_glob 'manifests/shared/*.yml'

          environment :custom_manifest do
            manifest 'manifests/shared/staging.yml'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/shared/staging.yml').and_return(true).ordered
      Rake::Task['cf:deploy:custom_manifest'].invoke
    end
  end
end
