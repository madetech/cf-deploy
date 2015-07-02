describe CF::Deploy::EnvConfig do
  let(:env_config) { described_class.new(:staging, 'assets:precompile', ['spec/manifests/staging_with_runtime.yml']) }

  context 'when reading application names' do
    subject { env_config[:deployments].first[:app_names] }
    it { is_expected.to include('staging-app') }
  end

  context 'when reading application level config' do
    subject { env_config[:deployments].first[:apps] }
    it { is_expected.to include(a_hash_including(name: 'staging-app', runtime_memory: '256M')) }
  end
end
