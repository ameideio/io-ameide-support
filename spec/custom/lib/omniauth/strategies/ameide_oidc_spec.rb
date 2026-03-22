require 'rails_helper'

RSpec.describe Omniauth::Strategies::AmeideOidc do
  it 'aliases the custom strategy into OmniAuth for provider lookup' do
    expect(OmniAuth::Strategies::AmeideOidc).to be(described_class)
  end
end
