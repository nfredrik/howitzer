require 'singleton'
require 'capybara'
require 'rspec/expectations'
require 'addressable/template'
require 'howitzer/web/capybara_methods_proxy'
require 'howitzer/web/page_validator'
require 'howitzer/web/element_dsl'
require 'howitzer/web/iframe_dsl'
require 'howitzer/web/page_dsl'
require 'howitzer/web/section_dsl'
require 'howitzer/exceptions'

module Howitzer
  module Web
    # This class represents a single web page. This is a parent class for all web pages
    class Page
      UnknownPage = Class.new
      include Singleton
      include CapybaraMethodsProxy
      include ElementDsl
      include IframeDsl
      include PageDsl
      include SectionDsl
      include PageValidator
      include ::RSpec::Matchers

      # This Ruby callback makes all inherited classes as singleton classes.
      # In additional it addes current page to page validator pages in case
      # if it has any defined validations.

      def self.inherited(subclass)
        subclass.class_eval { include Singleton }
        PageValidator.pages << subclass if subclass.validations.present?
      end

      # Opens a web page in browser
      # @note It tries to open the page twice and then raises the error if a validation is failed
      # @param validate [Boolean] if fase will skip current page validation (is opened)
      # @param params [Array] placeholder names and their values
      # @return [Page]

      def self.open(validate: true, **params)
        url = expanded_url(params)
        Howitzer::Log.info "Open #{name} page by '#{url}' url"
        retryable(tries: 2, logger: Howitzer::Log, trace: true, on: Exception) do |retries|
          Howitzer::Log.info 'Retry...' unless retries.zero?
          Capybara.current_session.visit(url)
        end
        given if validate
      end

      # Returns a singleton instance of the web page
      # @return [Page]

      def self.given
        displayed?
        instance
      end

      # Tries to identify current page name or raise the error if ambiguous page matching
      # @return [String] a page name
      # @raise [UnknownPage] when no any matched pages
      # @raise [AmbiguousPageMatchingError] when matched more than 1 page

      def self.current_page
        page_list = matched_pages
        return UnknownPage if page_list.count.zero?
        return page_list.first if page_list.count == 1
        raise Howitzer::AmbiguousPageMatchingError, ambiguous_page_msg(page_list)
      end

      # Waits until a web page is opened
      # @param time_out [Integer] time in seconds a required web page to be loaded
      # @return [Boolean]
      # @raise [IncorrectPageError] when timeout expired and the page is not displayed

      def self.displayed?(timeout = Howitzer.page_load_idle_timeout)
        end_time = ::Time.now + timeout
        until ::Time.now > end_time
          return true if opened?
          sleep(0.5)
        end
        raise Howitzer::IncorrectPageError, incorrect_page_msg
      end

      # @return [String] current page url from browser

      def self.current_url
        Capybara.current_session.current_url
      end

      # Returns an expanded page url for the page opening
      # @param params [Array] placeholders and their values
      # @return [String]
      # @raise [NoPathForPageError] if an url is not specified for the page

      def self.expanded_url(params = {})
        return "#{app_host}#{Addressable::Template.new(path_template).expand(params)}" unless path_template.nil?
        raise Howitzer::NoPathForPageError, "Please specify path for '#{self}' page. Example: path '/home'"
      end

      class << self
        protected

        # DSL to specify an relative path pattern for the page opening
        # @param value [String] a path pattern, for details please see Addressable gem
        # @see .site
        # @example
        #   class ArticlePage < Howitzer::Web::Page
        #     url '/articles/:id'
        #   end
        #   ArticlePage.open(id: 10)
        # @!visibility public

        def path(value)
          @path_template = value.to_s
        end

        # DSL to specify a site for the page opening
        # @note By default it specifies Howitzer.app_uri.site as a site
        # @param value [String] a site as combination of protocol, host and port
        # @example
        #   class AuthPage < Howitzer::Web::Page
        #     site 'https:/example.com'
        #   end
        #
        #   class LoginPage < AuthPage
        #     path '/login'
        #   end
        # @!visibility public

        def site(value)
          define_singleton_method(:app_host) { value }
          private_class_method :app_host
        end

        private

        attr_reader :path_template

        def incorrect_page_msg
          "Current page: #{current_page}, expected: #{self}.\n" \
                    "\tCurrent url: #{current_url}\n\tCurrent title: #{instance.title}"
        end

        def ambiguous_page_msg(page_list)
          "Current page matches more that one page class (#{page_list.join(', ')}).\n" \
                    "\tCurrent url: #{current_url}\n\tCurrent title: #{instance.title}"
        end
      end

      site Howitzer.app_uri.site

      def initialize
        check_validations_are_defined!
        current_window.maximize if Howitzer.maximized_window
      end

      # Reloads current page in a browser

      def reload
        Howitzer::Log.info "Reload '#{current_url}'"
        visit current_url
      end

      # Returns capybara context as current session

      def capybara_context
        Capybara.current_session
      end
    end
  end
end