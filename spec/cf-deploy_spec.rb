require 'cf-deploy'
require 'rake'

describe CF::Deploy do
  context '.install_tasks!' do
    it 'should install task for each manifest' do
      Dir.chdir('spec/') do
        described_class.install_tasks!
      end

      expect(Rake::Task['cf:deploy:staging']).to be_a(Rake::Task)
      expect(Rake::Task['cf:deploy:production']).to be_a(Rake::Task)
    end

    it 'should install tasks with defined dependencies' do
      Rake::Task.define_task('asset:precompile')

      Dir.chdir('spec/') do
        described_class.install_tasks! do
          environment :staging => 'asset:precompile'
        end
      end

      expect(Rake::Task['cf:deploy:staging'].prerequisite_tasks[0].name).to eq('asset:precompile')
    end

    it 'should install login task' do
      Dir.chdir('spec/') do
        described_class.install_tasks!
      end

      expect(Rake::Task['cf:login']).to be_a(Rake::Task)
    end
  end
end
