module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      class Helper #:nodoc:
        attr_reader :fields
        class_inheritable_accessor :service_url
        class_inheritable_hash :mappings
        class_inheritable_accessor :country_format
        self.country_format = :alpha2
        
        # The application making the calls to the gateway
        # Useful for things like the PayPal build notation (BN) id fields
        class_inheritable_accessor :application_id
        self.application_id = 'ActiveMerchant'

        def initialize(order, account, options = {})
          options.assert_valid_keys([:amount, :currency, :test, :credential2, :credential3, :credential4])
          @fields = {}
          @raw_html_fields = []
          self.order       = order
          self.account     = account
          self.amount      = options[:amount]
          self.currency    = options[:currency]
          self.credential2 = options[:credential2]
          self.credential3 = options[:credential3]
          self.credential4 = options[:credential4]
        end

        def self.mapping(attribute, options = {})
          self.mappings ||= {}
          self.mappings[attribute] = options
        end

        def add_field(name, value)
          return if name.blank? || value.blank?
          @fields[name.to_s] = value.to_s
        end

        def add_fields(subkey, params = {})
          params.each do |k, v|
            field = mappings[subkey][k]
            add_field(field, v) unless field.blank?
          end
        end


        # call to add a field that has characters that CGI::escape would mangle
        # note this may mean you may want to call CGI::escape on some of your own elements before passing them in here
        # this call allows for multiple fields with the same name
        # so it can work for line items
        def add_raw_html_field(name, value)
          @raw_html_fields << [name, value]
        end
        
        def raw_html_fields
          @raw_html_fields
        end

        def billing_address(params = {})
          add_address(:billing_address, params)
        end
        
        def shipping_address(params = {})
          add_address(:shipping_address, params)
        end
        
        def form_fields
          @fields
        end

        private
        
        def add_address(key, params)
          return if mappings[key].nil?
          
          code = lookup_country_code(params.delete(:country))
          add_field(mappings[key][:country], code) 
          add_fields(key, params)
        end
        
        def lookup_country_code(name_or_code)
          country = Country.find(name_or_code)
          country.code(country_format).to_s
        rescue InvalidCountryCodeError
          name_or_code
        end

        def method_missing(method_id, *args)
          method_id = method_id.to_s.gsub(/=$/, '').to_sym
          # Return and do nothing if the mapping was not found. This allows 
          # For easy substitution of the different integrations 
          return if mappings[method_id].nil?

          mapping = mappings[method_id]

          case mapping
          when Array
            mapping.each{ |field| add_field(field, args.last) }
          when Hash
            options = args.last.is_a?(Hash) ? args.pop : {}

            mapping.each{ |key, field| add_field(field, options[key]) }
          else
            add_field(mapping, args.last)
          end
        end
      end
    end
  end
end
