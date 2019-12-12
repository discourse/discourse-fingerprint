# frozen_string_literal: true

require 'rails_helper'

describe ::DiscourseFingerprint do
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }

  it 'can add, get and remove ignores' do
    expect(described_class::get_ignores(user1)).to contain_exactly(user1.id)
    expect(described_class::get_ignores(user2)).to contain_exactly(user2.id)

    described_class::ignore(user1, user2)
    described_class::ignore(user2, user1)
    expect(described_class::get_ignores(user1)).to contain_exactly(user1.id, user2.id)
    expect(described_class::get_ignores(user2)).to contain_exactly(user1.id, user2.id)

    described_class::ignore(user1, user3)
    described_class::ignore(user3, user1)
    expect(described_class::get_ignores(user1)).to contain_exactly(user1.id, user2.id, user3.id)
    expect(described_class::get_ignores(user2)).to contain_exactly(user1.id, user2.id)
    expect(described_class::get_ignores(user3)).to contain_exactly(user1.id, user3.id)

    described_class::ignore(user1, user2, add: false)
    described_class::ignore(user2, user1, add: false)
    expect(described_class::get_ignores(user1)).to contain_exactly(user1.id, user3.id)
    expect(described_class::get_ignores(user2)).to contain_exactly(user2.id)
    expect(described_class::get_ignores(user3)).to contain_exactly(user1.id, user3.id)
  end
end
