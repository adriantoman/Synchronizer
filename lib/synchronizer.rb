require 'rforce'


module Synchronizer

  class SalesForce


    attr_reader :rforce_binding,:output

    def initialize(login,pass,options = {})
        url = options[:url] || 'https://www.salesforce.com/services/Soap/u/20.0'
        @rforce_binding = RForce::Binding.new url
        @rforce_binding.login login, pass
        @output = Array.new
    end


    def query(query, options)
      values = options[:values]
      as_hash = options[:as_hash]


      fail "If you want to return array you need to specify fields in values key" if !as_hash && values.nil?

      rforce_binding = @rforce_binding
      answer = rforce_binding.query({:queryString => query})

      if answer[:queryResponse].nil? || answer[:queryResponse][:result].nil?
        fail answer[:Fault][:faultstring] if answer[:Fault] && answer[:Fault][:faultstring]
        fail "An unknown error occured while querying salesforce."
      end


      if answer[:queryResponse][:result][:size].to_i > 0 then
        answer[:queryResponse][:result][:records].each do |row|
          @output << (as_hash ? row : row.values_at(*values))
        end
      end


      more_locator = answer[:queryResponse][:result][:queryLocator]

      while more_locator do
        answer_more = rforce_binding.queryMore({:queryLocator => more_locator})
        answer_more[:queryMoreResponse][:result][:records].each do |row|

          @output << (as_hash ? row : row.values_at(*values))
        end
        more_locator = answer_more[:queryMoreResponse][:result][:queryLocator]
      end

      puts "We have loaded #{@output.count} from SF"
    end

    def getValueByField(fieldName,value)
      list = @output.find_all do |q|
          if (q[fieldName].class.to_s == "Array") then
            q[fieldName].first.casecmp(value) == 0 ? true : false

          else
            return q[fieldName].casecmp(value) == 0 ? true : false
          end
      end
    end

    def filter(value)
      @output = @output.find_all do |s|
          s[:StageName] == value
      end
    end

    def filter_out(value)
      @output.find_all do |s|
        if (s[:X1st_year_Services_Total__c].nil?) or (s[:PS_Hours__c].nil?)
          false
        else
          s[:StageName] == value and Float(s[:X1st_year_Services_Total__c]) > 0 and Float(s[:PS_Hours__c]) > 0
        end
      end
    end

    def filter_out_without_control(value)
      @output.find_all do |s|
        if (s[:X1st_year_Services_Total__c].nil?) or (s[:PS_Hours__c].nil?)
          false
        else
          s[:StageName] == value and Float(s[:X1st_year_Services_Total__c]) > 0 and Float(s[:PS_Hours__c]) == 0
        end
      end
    end


    def notAlreadyCreated(array)
      @output = @output.find_all do |s|
        projects = array.find_all {|p| p["DE:Salesforce ID"].casecmp(s[:Id].first) == 0 ? true : false}
        if (projects != nil and projects.count > 0) then
          false
        else
          true
        end
      end
    end

    def notAlreadyCreated_out(output,array)
      output.find_all do |s|
        projects = array.find_all {|p| p["DE:Salesforce ID"].casecmp(s[:Id].first) == 0 ? true : false}
        if (projects != nil and projects.count > 0) then
          false
        else
          true
        end
      end
    end


  end

end