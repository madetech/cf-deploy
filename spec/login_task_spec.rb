require 'spec_helper'
require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  context 'Rake::Task[cf:login]' do
    it 'should run `cf login` without arguments if none provided' do
      described_class.rake_tasks!
      expect(Kernel).to receive(:system).with('cf login')
      Rake::Task['cf:login'].invoke
    end

    it 'should include defined details' do
      described_class.rake_tasks! do
        api 'api.run.pivotal.io'
      end

      expect(Kernel).to receive(:system).with("cf login -a 'api.run.pivotal.io'")
      Rake::Task['cf:login'].invoke
    end

    it 'should include all defined details' do
      described_class.rake_tasks! do
        api 'api'
        username 'test'
        password 'pass'
        organisation 'org'
        space 'space'
      end

      expect(Kernel).to receive(:system).with("cf login -a 'api' -u 'test' -p 'pass' -o 'org' -s 'space'")
      Rake::Task['cf:login'].invoke
    end

    it 'should accept extra args' do
      described_class.rake_tasks! do
        api 'api'
        username 'test'
        password 'pass'
        organisation 'org'
        space 'space'
        extra_args '--myarg1 --myarg2'
      end

      expect(Kernel).to receive(:system).with("cf login -a 'api' -u 'test' -p 'pass' -o 'org' -s 'space' --myarg1 --myarg2")
      Rake::Task['cf:login'].invoke
    end

    it 'should include all details provided in ENV' do
      {'CF_API' => 'api',
       'CF_USERNAME' => 'test',
       'CF_PASSWORD' => 'pass',
       'CF_ORGANISATION' => 'org',
       'CF_SPACE' => 'space',
       'CF_EXTRA_ARGS' => '--myarg1 --myarg2'}.each do |(k, v)|
        expect(ENV).to receive(:[]).with(k).and_return(v).at_least(:once)
      end

      expect(Kernel).to receive(:system).with("cf login -a 'api' -u 'test' -p 'pass' -o 'org' -s 'space' --myarg1 --myarg2")
      described_class.rake_tasks!
      Rake::Task['cf:login'].invoke
    end

    it 'should mix and match ENV and defined details with ENV having precedence' do
      {'CF_API' => nil,
       'CF_USERNAME' => 'test',
       'CF_PASSWORD' => 'pass',
       'CF_ORGANISATION' => 'org',
       'CF_SPACE' => nil,
       'CF_EXTRA_ARGS' => nil}.each do |(k, v)|
        expect(ENV).to receive(:[]).with(k).and_return(v).at_least(:once)
      end

      expect(Kernel).to receive(:system).with("cf login -a 'api' -u 'test' -p 'pass' -o 'org'")

      described_class.rake_tasks! do
        api 'api'
        organisation 'will be overridden by ENV[CF_ORGANISATION]'
      end

      Rake::Task['cf:login'].invoke
    end
  end
end
