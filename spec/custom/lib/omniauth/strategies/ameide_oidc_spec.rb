require 'rails_helper'

RSpec.describe OmniAuth::Strategies::AmeideOidc do
  it 'defines the Zeitwerk-compatible Omniauth alias for eager loading' do
    expect(Omniauth::Strategies::AmeideOidc).to be(described_class)
  end
end
