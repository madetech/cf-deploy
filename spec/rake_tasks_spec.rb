require 'spec_helper'
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
      expected_task_0 = Rake::Task.define_task('cf:login')
      expected_task_1 = Rake::Task.define_task('asset:precompile')
      expected_task_2 = Rake::Task.define_task(:clean)

      Dir.chdir('spec/') do
        described_class.rake_tasks! do
          environment staging: 'asset:precompile'
          environment test: ['asset:precompile', :clean]
          environment production: 'asset:precompile' do
            route 'app'
          end
        end
      end

      expect(Rake::Task['cf:deploy:staging'].prerequisite_tasks[1]).to be(expected_task_1)
      expect(Rake::Task['cf:deploy:test'].prerequisite_tasks[2]).to be(expected_task_2)
      expect(Rake::Task['cf:deploy:production'].prerequisite_tasks[1]).to be(expected_task_1)
      expect(Rake::Task['cf:deploy:production_blue'].prerequisite_tasks[1]).to be(expected_task_1)
      expect(Rake::Task['cf:deploy:production_green'].prerequisite_tasks[1]).to be(expected_task_1)
      expect(Rake::Task['cf:deploy:production:flip'].prerequisite_tasks[0]).to be(expected_task_0)
      expect(Rake::Task['cf:deploy:production:stop_idle'].prerequisite_tasks[0]).to be(expected_task_0)
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
end
