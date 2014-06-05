require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  context '.install_tasks!' do
    before :each do
      Rake::Task.clear
    end

    it 'should install task for each manifest' do
      Dir.chdir('spec/') do
        described_class.install_tasks!
      end

      expect(Rake::Task['cf:deploy:staging']).to be_a(Rake::Task)
      expect(Rake::Task['cf:deploy:production']).to be_a(Rake::Task)
    end

    it 'should install login task' do
      Dir.chdir('spec/') do
        described_class.install_tasks!
      end

      expect(Rake::Task['cf:login']).to be_a(Rake::Task)
    end

    it 'should install a login task as a prerequisite for deploy tasks' do
      Dir.chdir('spec/') do
        described_class.install_tasks!
      end

      expect(Rake::Task['cf:deploy:staging'].prerequisite_tasks[0]).to be(Rake::Task['cf:login'])
    end

    it 'should install tasks with prerequisites' do
      expected_task_1 = Rake::Task.define_task('asset:precompile')
      expected_task_2 = Rake::Task.define_task(:clean)

      Dir.chdir('spec/') do
        described_class.install_tasks! do
          environment :staging => 'asset:precompile'
          environment :production => ['asset:precompile', :clean]
        end
      end

      expect(Rake::Task['cf:deploy:staging'].prerequisite_tasks[1]).to be(expected_task_1)
      expect(Rake::Task['cf:deploy:production'].prerequisite_tasks[2]).to be(expected_task_2)
    end
  end
end
