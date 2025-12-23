# frozen_string_literal: true

require 'spec_helper'
require 'markymark'

RSpec.describe Markymark::Org::IdGenerator do
  subject(:generator) { described_class.new }

  describe '#heading_id' do
    it 'prefers CUSTOM_ID when present' do
      heading = double(custom_id: 'my-custom-id', text: 'Heading Text')

      id = generator.heading_id(heading)

      expect(id).to eq('my-custom-id')
    end

    it 'slugifies heading text when no CUSTOM_ID' do
      heading = double(custom_id: nil, text: 'Hello World')

      id = generator.heading_id(heading)

      expect(id).to eq('hello-world')
    end

    it 'generates unique IDs for duplicate headings' do
      heading1 = double(custom_id: nil, text: 'Same Heading')
      heading2 = double(custom_id: nil, text: 'Same Heading')

      id1 = generator.heading_id(heading1)
      id2 = generator.heading_id(heading2)

      expect(id1).to eq('same-heading')
      expect(id2).to eq('same-heading-1')
    end

    it 'handles special characters in heading text' do
      heading = double(custom_id: nil, text: 'Hello! @World# $2024')

      id = generator.heading_id(heading)

      expect(id).to eq('hello-world-2024')
    end

    it 'builds path from ancestors' do
      parent = double(text: 'Parent')
      child = double(custom_id: nil, text: 'Child')

      id = generator.heading_id(child, ancestors: [parent])

      expect(id).to eq('parent--child')
    end

    it 'handles empty heading text' do
      heading = double(custom_id: nil, text: '')

      id = generator.heading_id(heading)

      expect(id).to eq('heading')
    end
  end

  describe '#block_id' do
    it 'generates ID for named block' do
      id = generator.block_id('my-block-name')

      expect(id).to eq('block-my-block-name')
    end

    it 'returns nil for nil name' do
      expect(generator.block_id(nil)).to be_nil
    end

    it 'returns nil for empty name' do
      expect(generator.block_id('')).to be_nil
    end
  end

  describe '#footnote_id' do
    it 'generates ID for footnote label' do
      id = generator.footnote_id('1')

      expect(id).to eq('fn-1')
    end

    it 'handles named labels' do
      id = generator.footnote_id('note')

      expect(id).to eq('fn-note')
    end
  end

  describe '#footnote_backref_id' do
    it 'generates backref ID for footnote label' do
      id = generator.footnote_backref_id('1')

      expect(id).to eq('fnref-1')
    end
  end

  describe '#reset!' do
    it 'clears seen IDs allowing duplicates' do
      heading = double(custom_id: nil, text: 'Test')

      id1 = generator.heading_id(heading)
      generator.reset!
      id2 = generator.heading_id(heading)

      expect(id1).to eq('test')
      expect(id2).to eq('test')
    end
  end
end
