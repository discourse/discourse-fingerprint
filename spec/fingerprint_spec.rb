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

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(1)
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

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(1)
    expect(fingerprints.size).to eq(1)
    expect(fingerprints.first[:data]).to eq('fp_data_2')
    expect(fingerprints.first[:first_time]).to eq((now - 10.minutes).to_s)
    expect(fingerprints.first[:last_time]).to eq(now.to_s)
  end

  it 'saves at most SiteSettings.max_fingerprints fingerprints' do
    1.upto(2 * SiteSetting.max_fingerprints) do |i|
      DiscourseFingerprint::Fingerprint.add(1, 'fp_type', "fp_hash_#{i}", 'fp_data')
    end

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(1)
    expect(fingerprints.size).to eq(SiteSetting.max_fingerprints)
  end

  it 'removes an existing fingerprint' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash', 'fp_data_1')
    DiscourseFingerprint::Fingerprint.remove(1,
      type: 'fp_type',
      hash: 'fp_hash',
    )

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(1)
    expect(fingerprints.size).to eq(0)
  end

  it 'loads all fingerprints' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_3', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(2, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(3, 'fp_type', 'fp_hash_2', 'fp_data')

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(1)
    expect(fingerprints.size).to eq(3)
    expect(fingerprints[0][:conflicts]).to eq([2])
    expect(fingerprints[1][:conflicts]).to eq([3])
    expect(fingerprints[2][:conflicts]).to eq([])

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(3)
    expect(fingerprints.size).to eq(1)
    expect(fingerprints.first[:conflicts]).to eq([1])

    conflicts = DiscourseFingerprint::Fingerprint.getConflicts()
    expect(conflicts).to eq([[1, 2], [1, 3]])
  end

  it 'can ignore users' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_3', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(2, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(3, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.ignore(1, 3)

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(1)
    expect(fingerprints[1][:conflicts]).to eq([])
    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(3)
    expect(fingerprints.first[:conflicts]).to eq([])
  end

  it 'can remove ignore' do
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(1, 'fp_type', 'fp_hash_3', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(2, 'fp_type', 'fp_hash_1', 'fp_data')
    DiscourseFingerprint::Fingerprint.add(3, 'fp_type', 'fp_hash_2', 'fp_data')
    DiscourseFingerprint::Fingerprint.ignore(1, 3)
    DiscourseFingerprint::Fingerprint.ignore(1, 3, false)

    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(1)
    expect(fingerprints[1][:conflicts]).to eq([3])
    fingerprints = DiscourseFingerprint::Fingerprint.getFingerprints(3)
    expect(fingerprints.first[:conflicts]).to eq([1])
  end

end
