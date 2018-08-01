require 'rails_helper'

describe ::DiscourseFingerprint::Fingerprint do

  before do
    SiteSetting.fingerprint_enabled = true
    SiteSetting.max_fingerprints = 10
  end

  it 'saves a new fingerprint' do
    now = Time.now

    freeze_time(now)
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash', 'fp_data')

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(1)
    expect(fingerprints.size).to eq(1)
    expect(fingerprints.first[:type]).to eq('fp_type')
    expect(fingerprints.first[:hash]).to eq('fp_hash')
    expect(fingerprints.first[:data]).to eq('fp_data')
    expect(fingerprints.first[:first_time]).to eq(now.to_s)
    expect(fingerprints.first[:last_time]).to eq(now.to_s)
  end

  it 'saves by updating old fingerprints' do
    now = Time.now

    freeze_time(now - 10.minutes)
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash', 'fp_data_1')

    freeze_time(now)
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash', 'fp_data_2')

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(1)
    expect(fingerprints.size).to eq(1)
    expect(fingerprints.first[:data]).to eq('fp_data_2')
    expect(fingerprints.first[:first_time]).to eq((now - 10.minutes).to_s)
    expect(fingerprints.first[:last_time]).to eq(now.to_s)
  end

  it 'saves latest SiteSettings.max_fingerprints fingerprints' do
    now = Time.now

    # Create fingerprints for time +now + 0+, +now + 1+, +now + 2+, ... up to
    # +now + 2 * SiteSetting.max_fingerprints+. Expect only last
    # +SiteSetting.max_fingerprints+ to be returned.
    1.upto(2 * SiteSetting.max_fingerprints) do |i|
      freeze_time(now + i.minutes)
      DiscourseFingerprint::Fingerprint.add(1, 'fp_type', "fp_hash_#{i}", i)
    end

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(1)
    expect(fingerprints.size).to eq(SiteSetting.max_fingerprints)
    fingerprints.each { |f|
      expect(f[:data].to_i).to be >= SiteSetting.max_fingerprints
    }
  end

  it 'removes an existing fingerprint' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash', 'fp_data_1')
    DiscourseFingerprint::Fingerprint.remove(1,
      type: 'fp_type',
      hash: 'fp_hash',
    )

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(1)
    expect(fingerprints.size).to eq(0)
  end

  it 'loads all fingerprints' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_3', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(2, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(3, 'fp_type', 'fp_hash_2', 'fp_data')

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(1)
    expect(fingerprints.size).to eq(3)
    expect(fingerprints[0][:conflicts]).to match_array([2])
    expect(fingerprints[1][:conflicts]).to match_array([3])
    expect(fingerprints[2][:conflicts]).to match_array([])

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(3)
    expect(fingerprints.size).to eq(1)
    expect(fingerprints.first[:conflicts]).to match_array([1])

    conflicts = DiscourseFingerprint::Fingerprint.get_conflicts
    expect(conflicts).to match_array([[1, 2], [1, 3]])
  end

  it 'can ignore users' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_3', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(2, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(3, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.ignore(1, 3)

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(1)
    expect(fingerprints[1][:conflicts]).to match_array([])
    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(3)
    expect(fingerprints.first[:conflicts]).to match_array([])
  end

  it 'can remove ignore' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_3', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(2, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(3, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.ignore(1, 3)
    DiscourseFingerprint::Fingerprint.ignore(1, 3, false)

    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(1)
    expect(fingerprints[1][:conflicts]).to match_array([3])
    fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(3)
    expect(fingerprints.first[:conflicts]).to match_array([1])
  end

end
