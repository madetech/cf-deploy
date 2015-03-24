require 'spec_helper'
require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  context 'Flip production environments' do
    let :rake_tasks! do
      described_class.rake_tasks! do
        environment :production do
          route 'yourwebsite.com', flip: true
          route 'yourwebsite.com', 'www', flip: true
          route 'yourwebsite.com', 'www-origin', flip: true
        end
      end
    end

    it 'should map to blue if green is currently mapped' do
      Dir.chdir('spec/') do
        rake_tasks!
        expect(Kernel).to receive(:system).with('cf login').ordered

        expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(:read => 'production-green-app', :close => nil) }
        expect(Kernel).to receive(:system).with('cf map-route production-blue-app yourwebsite.com').ordered
        expect(Kernel).to receive(:system).with('cf unmap-route production-green-app yourwebsite.com').ordered

        expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(:read => 'production-green-app', :close => nil) }
        expect(Kernel).to receive(:system).with('cf map-route production-blue-app yourwebsite.com -n www').ordered
        expect(Kernel).to receive(:system).with('cf unmap-route production-green-app yourwebsite.com -n www').ordered

        expect(Kernel).to receive(:system).with('cf map-route production-blue-app yourwebsite.com -n www-origin').ordered
        expect(Kernel).to receive(:system).with('cf unmap-route production-green-app yourwebsite.com -n www-origin').ordered

        Rake::Task['cf:deploy:production:flip'].invoke
      end
    end

    it 'should map to green if blue is currently mapped' do
      Dir.chdir('spec/') do
        rake_tasks!
        expect(Kernel).to receive(:system).with('cf login').ordered

        expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(:read => 'production-blue-app', :close => nil) }
        expect(Kernel).to receive(:system).with('cf map-route production-green-app yourwebsite.com').ordered
        expect(Kernel).to receive(:system).with('cf unmap-route production-blue-app yourwebsite.com').ordered

        expect(IO).to receive(:popen).with("cf routes | grep 'yourwebsite.com'") { double(:read => 'production-blue-app', :close => nil) }
        expect(Kernel).to receive(:system).with('cf map-route production-green-app yourwebsite.com -n www').ordered
        expect(Kernel).to receive(:system).with('cf unmap-route production-blue-app yourwebsite.com -n www').ordered

        expect(Kernel).to receive(:system).with('cf map-route production-green-app yourwebsite.com -n www-origin').ordered
        expect(Kernel).to receive(:system).with('cf unmap-route production-blue-app yourwebsite.com -n www-origin').ordered
        Rake::Task['cf:deploy:production:flip'].invoke
      end
    end
  end
end
