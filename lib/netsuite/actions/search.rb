module NetSuite
  module Actions
    class Search
      include Support::Requests

      def initialize(klass, options = { })
        # TODO
        # Fix this hack so that searching InventoryItems doesn't rely on using the class name,
        # since its an ItemSearch, there is no InventoryItemSearch
        if klass == NetSuite::Records::InventoryItem
          @klass = NetSuite::Records::Item
        else
          @klass = klass
        end
        @options = options
      end

      private

      def request
        # https://system.netsuite.com/help/helpcenter/en_US/Output/Help/SuiteCloudCustomizationScriptingWebServices/SuiteTalkWebServices/SettingSearchPreferences.html
        # https://webservices.netsuite.com/xsd/platform/v2012_2_0/messages.xsd

        preferences = NetSuite::Configuration.auth_header
        preferences = preferences.merge(
          (@options[:preferences] || {}).inject({'platformMsgs:SearchPreferences' => {}}) do |h, (k, v)|
            h['platformMsgs:SearchPreferences'][k.to_s.lower_camelcase] = v
            h
          end
        )

        api_version = NetSuite::Configuration.api_version

        NetSuite::Configuration.connection(
          namespaces: {
            'xmlns:platformMsgs' => "urn:messages_#{api_version}.platform.webservices.netsuite.com",
            'xmlns:platformCore' => "urn:core_#{api_version}.platform.webservices.netsuite.com",
            'xmlns:platformCommon' => "urn:common_#{api_version}.platform.webservices.netsuite.com",
            'xmlns:listAcct' => "urn:accounting_#{api_version}.lists.webservices.netsuite.com",
            'xmlns:listRel' => "urn:relationships_#{api_version}.lists.webservices.netsuite.com",
            'xmlns:tranSales' => "urn:sales_#{api_version}.transactions.webservices.netsuite.com",
            'xmlns:setupCustom' => "urn:customization_#{api_version}.setup.webservices.netsuite.com"
          },
          soap_header: preferences
        ).call (@options.has_key?(:search_id)? :search_more_with_id : :search), :message => request_body
      end

      # basic search XML

      # <soap:Body>
      # <platformMsgs:search>
      # <searchRecord xsi:type="ContactSearch">
      #   <customerJoin xsi:type="CustomerSearchBasic">
      #     <email operator="contains" xsi:type="platformCore:SearchStringField">
      #     <platformCore:searchValue>shutterfly.com</platformCore:searchValue>
      #     <email>
      #   <customerJoin>
      # </searchRecord>
      # </search>
      # </soap:Body>

      def request_body
        if @options.has_key?(:search_id)
          return {
            'pageIndex' => @options[:page_index],
            'searchId' => @options[:search_id],
          }
        end

        # columns is only needed for advanced search results
        columns = @options[:columns] || {}
        criteria = @options[:criteria] || @options

        # TODO find cleaner solution for pulling the namespace of the record, which is a instance method
        example_instance = @klass.new
        namespace = example_instance.record_namespace

        # extract the class name
        class_name = @klass.to_s.split("::").last

        criteria_structure = {}
        columns_structure = columns
        saved_search_id = criteria.delete(:saved)

        # TODO this whole thing needs to be refactored so we can apply some of the same logic to the
        #      column creation xml

        criteria.each_pair do |condition_category, conditions|
          criteria_structure["#{namespace}:#{condition_category}"] = conditions.inject({}) do |h, condition|
            element_name = "platformCommon:#{condition[:field]}"

            case condition[:field]
            when 'recType'
              # TODO this seems a bit brittle, look into a way to handle this better
              h[element_name] = {
                :@internalId => condition[:value].internal_id
              }
            when 'customFieldList'
              # === START CUSTOM FIELD

              # there isn't a clean way to do lists of the same element
              # Gyoku doesn't seem support the nice :@attribute and :content! syntax for lists of elements of the same name
              # https://github.com/savonrb/gyoku/issues/18#issuecomment-17825848

              # TODO with the latest version of savon we can easily improve the code here, should be rewritten with new attribute syntax

              custom_field_list = condition[:value].map do |h|
                if h[:value].is_a?(Array) && h[:value].first.respond_to?(:to_record)
                  {
                    "platformCore:searchValue" => h[:value].map(&:to_record),
                    :attributes! => {
                      'platformCore:searchValue' => {
                        'internalId' => h[:value].map(&:internal_id)
                      }
                    }
                  }
                elsif h[:value].respond_to?(:to_record)
                  {
                    "platformCore:searchValue" => {
                      :content! => h[:value].to_record,
                      :@internalId => h[:value].internal_id
                    }
                  }
                else
                  { "platformCore:searchValue" => h[:value] }
                end
              end

              h[element_name] = {
                'platformCore:customField' => custom_field_list,
                :attributes! => {
                  'platformCore:customField' => {
                    'internalId' => condition[:value].map { |h| h[:field] },
                    'operator' => condition[:value].map { |h| h[:operator] },
                    'xsi:type' => condition[:value].map { |h| "platformCore:#{h[:type]}" }
                  }
                }
              }

              # === END CUSTOM FIELD
            else
              if condition[:value].is_a?(Array) && condition[:value].first.respond_to?(:to_record)
                # TODO need to update to the latest savon so we don't need to duplicate the same workaround above again
                # TODO it's possible that this might break, not sure if platformCore:SearchMultiSelectField is the right type in every situation

                h[element_name] = {
                  '@operator' => condition[:operator],
                  '@xsi:type' => 'platformCore:SearchMultiSelectField',
                  "platformCore:searchValue" => {
                    :content! => condition[:value].map(&:to_record),
                    '@internalId' => condition[:value].map(&:internal_id),
                    '@xsi:type' => 'platformCore:RecordRef',
                    '@type' => 'account'
                  }
                }
              elsif condition[:value].is_a?(Array) && condition[:type] == 'SearchDateField'
                # date ranges are handled via searchValue (start range) and searchValue2 (end range)

                h[element_name] = {
                  '@operator' => condition[:operator],
                  "platformCore:searchValue" => condition[:value].first.to_s,
                  "platformCore:searchValue2" => condition[:value].last.to_s
                }
              else
                h[element_name] = {
                  :content! => { "platformCore:searchValue" => condition[:value] },
                }

                h[element_name][:@operator] = condition[:operator] if condition[:operator]
              end
            end

            h
          end
        end

        # TODO this needs to be DRYed up a bit

        if saved_search_id
          {
            'searchRecord' => {
              '@savedSearchId' => saved_search_id,
              '@xsi:type' => "#{namespace}:#{class_name}SearchAdvanced",
              :content! => {
                "#{namespace}:criteria" => criteria_structure
                # TODO need to optionally support columns here
              }
            }
          }
        elsif !columns_structure.empty?
          {
            'searchRecord' => {
              '@xsi:type' => "#{namespace}:#{class_name}SearchAdvanced",
              :content! => {
                "#{namespace}:criteria" => criteria_structure,
                "#{namespace}:columns" => columns_structure
              }
            }
          }
        else
          {
            'searchRecord' => {
              :content! => criteria_structure,
              '@xsi:type' => "#{namespace}:#{class_name}Search"
            }
          }
        end
      end

      def response_header
        @response_header ||= response_header_hash
      end

      def response_header_hash
        @response_header_hash = @response.header[:document_info]
      end

      def response_body
        @response_body ||= search_result
      end

      def search_result
        @search_result = if @response.body.has_key?(:search_more_with_id_response)
          @response.body[:search_more_with_id_response]
        else
          @response.body[:search_response]
        end[:search_result]
      end

      def success?
        @success ||= search_result[:status][:@is_success] == 'true'
      end

      protected
        def method_name

        end

      module Support
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def search(options = { })
            response = NetSuite::Actions::Search.call(self, options)

            if response.success?
              NetSuite::Support::SearchResult.new(response, self)
            else
              false
            end
          end
        end
      end
    end
  end
end
