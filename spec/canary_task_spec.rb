require 'spec_helper'
require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  context 'Canary deployment task' do
    let :rake_tasks! do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
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

    it 'should unmap any existing production routes' do
      rake_tasks!

      expect(Kernel).to receive(:system).with('cf login').ordered

      expect(Kernel).to receive(:system).with('cf unmap-route canary-app yourwebsite.com').ordered
      expect(Kernel).to receive(:system).with('cf unmap-route canary-app yourwebsite.com -n www').ordered

      expect(Kernel).to receive(:system).with('cf push -f manifests/canary.yml').and_return(true).ordered

      expect(Kernel).to receive(:system).with('cf map-route canary-app canary.yourwebsite.com').ordered
      expect(Kernel).to receive(:system).with('cf map-route canary-app canary.yourwebsite.com -n www').ordered

      Rake::Task['cf:deploy:canary'].invoke
    end
  end
end
