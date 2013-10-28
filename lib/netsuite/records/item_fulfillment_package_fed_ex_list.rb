module NetSuite
  module Records
    class ItemFulfillmentPackageFedExList
      include Support::Fields
      include Namespaces::TranSales

      fields :packages

      def initialize(attributes = {})
        initialize_from_attributes_hash(attributes)
      end

      def package=(packages)
        case packages
        when Hash
          self.packages << ItemFulfillmentPackageFedEx.new(packages)
        when Array
          packages.each { |package| self.packages << ItemFulfillmentPackageFedEx.new(package) }
        end
      end

      def packages
        @packages ||= []
      end

      def to_record
        { "#{record_namespace}:packageFedEx" => packages.map(&:to_record) }
      end

    end
  end
end
