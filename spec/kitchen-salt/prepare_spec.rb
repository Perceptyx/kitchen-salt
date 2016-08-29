require 'spec_helper'
require 'kitchen-salt/util'
require 'kitchen-salt/prepare'

describe Kitchen::Salt::Prepare do
  let(:klass) { Class.new.extend(Kitchen::Salt::Prepare) }
  let(:salt_config) { '/etc/salt' }
  let(:grains) { nil }
  let(:sandbox_path) { Dir.mktmpdir }
  let(:config) do
    {
      grains: grains,
      salt_config: salt_config,
    }
  end

  before { klass.extend(Kitchen::Salt::Util) }
  before { allow(klass).to receive(:debug) }
  before { allow(klass).to receive(:info) }
  before { allow(klass).to receive(:config).and_return(config) }
  before { allow(klass).to receive(:sandbox_path).and_return(sandbox_path) }

  describe '#prepare_grains' do
    subject { klass.send(:prepare_grains) }

    context 'when grains is nil' do
      let(:grains) { nil }
      xit { is_expected.to eq false }
    end

    context 'when grains is not nil' do
      let(:grains) { {} }
      xit { is_expected.to eq false }
    end
  end
end
