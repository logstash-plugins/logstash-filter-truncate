# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/truncate"
require "flores/random"
require "flores/rspec"

RSpec.configure do |config|
  Flores::RSpec.configure(config)
end


describe LogStash::Filters::Truncate do
  analyze_results

  context "with hash fields" do
    let(:data) {
      {
        "foo" => { "bar" => Flores::Random.text(0..1000) },
        "one" => { "two" => { "three" => Flores::Random.text(0..1000) } },
        "baz" => Flores::Random.text(0..1000),
      }
    }
    let(:length) { Flores::Random.integer(0..1000) }
    subject { described_class.new("length_bytes" => length) }
    let(:event) { LogStash::Event.new(data) }

    before { subject.filter(event) }

    stress_it "should truncate all strings in the hash" do
      expect(event.get("[foo][bar]").bytesize).to be <= length
      if event.get("[foo][bar]").bytesize > length
        expect(subject).to receive(:filter_matched).once
      else
        expect(subject).not_to receive(:filter_matched)
      end

      expect(event.get("[one][two][three]").bytesize).to be <= length
      if event.get("[one][two][three]").bytesize > length
        expect(subject).to receive(:filter_matched).once
      else
        expect(subject).not_to receive(:filter_matched)
      end

      expect(event.get("baz").bytesize).to be <= length
      if event.get("baz").bytesize > length
        expect(subject).to receive(:filter_matched).once
      else
        expect(subject).not_to receive(:filter_matched)
      end
    end
  end

  context "with string fields" do
    let(:text) { Flores::Random.text(0..1000) }
    let(:length) { Flores::Random.integer(0..1000) }
    subject { described_class.new("length_bytes" => length, "fields" => [ "example" ]) }
    let(:event) { LogStash::Event.new("message" => text, "example" => text) }

    before do
      subject.filter(event)
    end

    stress_it "should truncate the requested field" do
      expect(event.get("example").bytesize).to be <= length
    end

    stress_it "should remain valid UTF-8" do
      expect(event.get("example")).to be_valid_encoding
    end

    it "should not modify `message`" do
      expect(event.get("message")).to be == text
    end

    stress_it "should only call filter_matched if a field was truncated" do
      if event.get("example").bytesize > length
        expect(subject).to receive(:filter_matched).once
      else
        expect(subject).not_to receive(:filter_matched)
      end
    end
  end

  context "with non-string fields" do
    let(:number) { Flores::Random.integer(-500.. 500) }
    let(:length) { Flores::Random.integer(0..1000) }
    subject { described_class.new("length_bytes" => length, "fields" => [ "example" ]) }
    let(:event) { LogStash::Event.new("example" => number) }


    stress_it "should do nothing" do
      expect(event.get("example")).to be == number
      expect(subject).not_to receive(:filter_matched)
    end
  end

  context "with array fields" do
    let(:count) { Flores::Random.integer(0..20) }
    let(:list) { count.times.map { Flores::Random.text(0..1000) } }
    let(:length) { Flores::Random.integer(0..1000) }
    subject { described_class.new("length_bytes" => length, "fields" => [ "example" ]) }
    let(:event) { LogStash::Event.new("example" => list) }

    before { subject.filter(event) }

    stress_it "should truncate all elements in a list" do
      count.times do |i| 
        expect(event.get("[example][#{i}]").bytesize).to be <= length

        if event.get("[example][#{i}]").bytesize > length
          expect(subject).to receive(:filter_matched).once
        else
          expect(subject).not_to receive(:filter_matched)
        end
      end
    end
  end
end
