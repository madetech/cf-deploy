require 'spec_helper'
require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  let :rake_tasks! do
    Dir.chdir('spec/') do
      described_class.rake_tasks! do
        manifest_glob 'manifests/canary/*.yml'

        environment :canary do
          route 'canary.yourwebsite.com'
          route 'canary.yourwebsite.com', 'www'
        end

        environment :production do
          route 'yourwebsite.com'
          route 'yourwebsite.com', 'www'
        end
      end
    end
  end

  context 'Canary deployment task' do
    it 'should unmap any existing production routes and then deploy' do
      rake_tasks!

      expect(Kernel).to receive(:system).with('cf login').ordered

      expect(Kernel).to receive(:system).with('cf unmap-route canary-app yourwebsite.com').ordered
      expect(Kernel).to receive(:system).with('cf unmap-route canary-app yourwebsite.com -n www').ordered

      expect(Kernel).to receive(:system).with('cf push -f manifests/canary/canary.yml').and_return(true).ordered

      expect(Kernel).to receive(:system).with('cf map-route canary-app canary.yourwebsite.com').ordered
      expect(Kernel).to receive(:system).with('cf map-route canary-app canary.yourwebsite.com -n www').ordered

      Rake::Task['cf:deploy:canary'].invoke
    end
  end

  context 'Canary trial task' do
    it 'should add production routes to the canary app' do
      rake_tasks!

      expect(Kernel).to receive(:system).with('cf login').ordered

      expect(Kernel).to receive(:system).with('cf map-route canary-app yourwebsite.com').ordered
      expect(Kernel).to receive(:system).with('cf map-route canary-app yourwebsite.com -n www').ordered

      Rake::Task['cf:canary:trial'].invoke
    end
  end

  context 'Canary release task' do
    it 'should add production routes to the canary app' do
      rake_tasks!

      expect(Kernel).to receive(:system).with('cf login').ordered

      expect(Kernel).to receive(:system).with('cf scale canary-app -i 2')

      expect(Kernel).to receive(:system).with('cf delete -f production-app')
      expect(Kernel).to receive(:system).with('cf rename canary-app production-app')

      expect(Kernel).to receive(:system).with('cf map-route production-app cfapps.io -n production-app')
      expect(Kernel).to receive(:system).with('cf unmap-route production-app cfapps.io -n canary-app')

      expect(Kernel).to receive(:system).with('cf unmap-route production-app canary.yourwebsite.com').ordered
      expect(Kernel).to receive(:system).with('cf unmap-route production-app canary.yourwebsite.com -n www').ordered

      Rake::Task['cf:canary:release'].invoke
    end
  end

  context 'Canary fail task' do
    it 'should delete the canary app' do
      rake_tasks!

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf delete -f canary-app').ordered

      Rake::Task['cf:canary:fail'].invoke
    end
  end
end
