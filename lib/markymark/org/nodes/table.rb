# frozen_string_literal: true

require_relative 'base'

module Markymark
  module Org
    module Nodes
      # Table container
      class Table < Base
        attr_reader :name

        def initialize(children: [], name: nil)
          super(children: children)
          @name = name
        end

        def header_row
          children.find { |row| row.is_a?(TableRow) && row.header? }
        end

        def ==(other)
          super && other.name == name
        end
      end

      # Table row
      class TableRow < Base
        attr_reader :header

        def initialize(children: [], header: false)
          super(children: children)
          @header = header
        end

        def header?
          @header
        end

        def separator?
          false
        end

        def ==(other)
          super && other.header == header
        end
      end

      # Table separator row (|---+---|)
      class TableSeparator < Base
        def initialize
          super(children: [])
        end

        def separator?
          true
        end
      end

      # Table cell
      class TableCell < Base
        attr_reader :content

        def initialize(content:, children: [])
          super(children: children)
          @content = content
        end

        def ==(other)
          super && other.content == content
        end
      end
    end
  end
end
