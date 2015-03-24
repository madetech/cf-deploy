require 'spec_helper'
require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  context 'Blue/green deployment task' do
    let :rake_tasks! do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :production do
            route 'yourwebsite.com', flip: true
            route 'yourwebsite.com', 'www', flip: true
            route 'yourwebsite.com', 'www-origin', flip: true
          end
        end
      end
    end

    it 'should exist if *_blue.yml and *_green.yml manifests exist' do
      rake_tasks!
      expect(Rake::Task['cf:deploy:production']).to be_a(Rake::Task)
    end

    it 'should deploy blue if not currently deployed' do
      rake_tasks!
      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(read: '', close: nil) }
      expect(Kernel).to receive(:system).with('cf push -f manifests/production_blue.yml').and_return(true).ordered
      Rake::Task['cf:deploy:production'].invoke
    end

    it 'should deploy blue if green currently deployed' do
      rake_tasks!
      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(read: 'production-green-app', close: nil) }
      expect(Kernel).to receive(:system).with('cf push -f manifests/production_blue.yml').and_return(true).ordered
      Rake::Task['cf:deploy:production'].invoke
    end

    it 'should deploy green if blue currently deployed' do
      rake_tasks!
      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(read: 'production-blue-app', close: nil) }
      expect(Kernel).to receive(:system).with('cf push -f manifests/production_green.yml').and_return(true).ordered
      Rake::Task['cf:deploy:production'].invoke
    end

    it 'should ignore flip_routes' do
      rake_tasks!
      expect(Kernel).to_not receive(:system).with('cf map-route production-blue-app yourwebsite.com -n www')
      expect(Kernel).to_not receive(:system).with('cf map-route production-blue-app yourwebsite.com -n www-origin')
    end

    it 'should throw exception if no routes defined for blue/green task' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :production
        end
      end

      allow(Kernel).to receive(:system)
      expect { Rake::Task['cf:deploy:production'].invoke }.to raise_error
    end

    it 'should run prerequisite tasks' do
      rake_tasks!
    end
  end
end
