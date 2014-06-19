require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  before :each do
    Rake::Task.clear
  end

  context '.rake_tasks!' do
    it 'should install task for each manifest' do
      Dir.chdir('spec/') do
        described_class.rake_tasks!
      end

      expect(Rake::Task['cf:deploy:staging']).to be_a(Rake::Task)
      expect(Rake::Task['cf:deploy:test']).to be_a(Rake::Task)
    end

    it 'should install login task' do
      Dir.chdir('spec/') do
        described_class.rake_tasks!
      end

      expect(Rake::Task['cf:login']).to be_a(Rake::Task)
    end

    it 'should install a login task as a prerequisite for deploy tasks' do
      Dir.chdir('spec/') do
        described_class.rake_tasks!
      end

      expect(Rake::Task['cf:deploy:staging'].prerequisite_tasks[0]).to be(Rake::Task['cf:login'])
    end

    it 'should install tasks with prerequisites' do
      expected_task_1 = Rake::Task.define_task('asset:precompile')
      expected_task_2 = Rake::Task.define_task(:clean)

      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment :staging => 'asset:precompile'
          environment :test => ['asset:precompile', :clean]
        end
      end

      expect(Rake::Task['cf:deploy:staging'].prerequisite_tasks[1]).to be(expected_task_1)
      expect(Rake::Task['cf:deploy:test'].prerequisite_tasks[2]).to be(expected_task_2)
    end

    it 'should have a configurable manifest glob options' do
      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          manifest_glob 'manifests/staging.yml'
        end
      end

      expect(Rake::Task.tasks.count).to eq(2)
    end
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

      expect(Kernel).to receive(:system).with('cf login -a api.run.pivotal.io')
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

      expect(Kernel).to receive(:system).with('cf login -a api -u test -p pass -o org -s space')
      Rake::Task['cf:login'].invoke
    end

    it 'should include all details provided in ENV' do
      {'CF_API' => 'api',
       'CF_USERNAME' => 'test',
       'CF_PASSWORD' => 'pass',
       'CF_ORGANISATION' => 'org',
       'CF_SPACE' => 'space'}.each do |(k, v)|
        expect(ENV).to receive(:[]).with(k).and_return(v).at_least(:once)
      end

      expect(Kernel).to receive(:system).with('cf login -a api -u test -p pass -o org -s space')
      described_class.rake_tasks!
      Rake::Task['cf:login'].invoke
    end

    it 'should mix and match ENV and defined details with ENV having precedence' do
      {'CF_API' => nil,
       'CF_USERNAME' => 'test',
       'CF_PASSWORD' => 'pass',
       'CF_ORGANISATION' => 'org',
       'CF_SPACE' => nil}.each do |(k, v)|
        expect(ENV).to receive(:[]).with(k).and_return(v).at_least(:once)
      end

      expect(Kernel).to receive(:system).with('cf login -a api -u test -p pass -o org')

      described_class.rake_tasks! do
        api 'api'
        organisation 'will be overridden by ENV[CF_ORGANISATION]'
      end

      Rake::Task['cf:login'].invoke
    end
  end

  context 'Rake::Task[cf:deploy:XX]' do
    it 'should run a manifest' do
      Dir.chdir('spec/') do
        described_class.rake_tasks!
      end

      expect(Kernel).to receive(:system).with('cf login').ordered
      expect(Kernel).to receive(:system).with('cf push -f manifests/staging.yml').ordered
      Rake::Task['cf:deploy:staging'].invoke
    end
  end
end
