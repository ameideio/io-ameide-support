require 'rails_helper'

RSpec.describe OmniAuth::Strategies::AmeideOidc do
  it 'is available under OmniAuth for provider lookup' do
    expect(OmniAuth::Strategies::AmeideOidc).to be(described_class)
  end
end
