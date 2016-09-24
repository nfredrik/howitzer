require 'howitzer/web/capybara_methods_proxy'
require 'howitzer/web/element_dsl'
require 'howitzer/web/iframe_dsl'
require 'howitzer/web/section_dsl'

module Howitzer
  module Web
    # This class holds base functinality for sections
    class BaseSection
      include CapybaraMethodsProxy
      include ElementDsl
      include SectionDsl
      include IframeDsl

      attr_reader :parent, :capybara_context

      class << self
        attr_reader :default_finder_args
      end

      def initialize(parent, context)
        @parent = parent
        @capybara_context = context
      end
    end
  end
end