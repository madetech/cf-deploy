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
        described_class.rake_tasks!
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/staging.yml').and_return(true).ordered
      Rake::Task['cf:deploy:staging'].invoke
    end

    it 'should setup a route if defined after pushing manifest' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :test do
            route 'testexample.com'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/test.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app testexample.com').ordered
      Rake::Task['cf:deploy:test'].invoke
    end

    it 'should setup a route with a hostname if defined' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :test do
            route 'example.com', 'test'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/test.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app example.com -n test')
      Rake::Task['cf:deploy:test'].invoke
    end

    it 'should setup multiple routes if defined' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :test do
            route 'example.com'
            route 'example.com', '2'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/test.yml').and_return(true).ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app example.com').ordered
      expect(Kernel).to receive(:system).with('cf map-route test-app example.com -n 2').ordered
      Rake::Task['cf:deploy:test'].invoke
    end

    it 'should not map routes if push command fails' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :test do
            route 'example.com'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf push -f manifests/test.yml').and_return(nil)
      expect(Kernel).to_not receive(:system).with('cf map-route test-app example.com')
      expect do
        Rake::Task['cf:deploy:test'].invoke
      end.to raise_error
    end

    it 'should not map routes if push command returns non-zero status' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :test do
            route 'example.com'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf push -f manifests/test.yml').and_return(false)
      expect(Kernel).to_not receive(:system).with('cf map-route test-app example.com')
      expect do
        Rake::Task['cf:deploy:test'].invoke
      end.to raise_error
    end

    xit 'should throw decent error if manifest does not exist' do
    end

    xit 'should throw decent error if manifest invalid' do
    end

    it 'should allow individual manifest to be specified' do
      Dir.chdir('spec/') do
        CF::Deploy.rake_tasks! do
          environment :custom_manifest do
            manifest 'manifests/staging.yml'
          end
        end
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/staging.yml').and_return(true).ordered
      Rake::Task['cf:deploy:custom_manifest'].invoke
    end
  end
end
