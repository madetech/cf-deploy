require 'spec_helper'
require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  context 'Suspend idle app' do
    let :rake_tasks! do
      described_class.rake_tasks! do
        environment :production do
          route 'yourwebsite.com', flip: true
        end
      end
    end

    it 'should stop green if green is currently mapped' do
      Dir.chdir('spec/') do
        rake_tasks!
        expect(Kernel).to receive(:system).with('cf login').ordered
        expect(Kernel).to receive(:system).with('cf stop production-blue-app').ordered
        Rake::Task['cf:deploy:production:stop_idle'].invoke
      end
    end

    it 'should stop to blue if blue is currently mapped' do
      Dir.chdir('spec/') do
        rake_tasks!
        expect(Kernel).to receive(:system).with('cf login').ordered
        expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(:read => 'production-blue-app', :close => nil) }
        expect(Kernel).to receive(:system).with('cf stop production-green-app').ordered
        Rake::Task['cf:deploy:production:stop_idle'].invoke
      end
    end
  end
end
