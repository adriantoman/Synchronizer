#!/usr/bin/env ruby
# 1.9 adds realpath to resolve symlinks; 1.8 doesn't
# have this method, so we add it so we get resolved symlinks
# and compatibility
require 'rubygems'
require 'bundler/setup'
require 'gli'
require 'pp'
require 'date'
require 'chronic'
require 'fastercsv'
require 'date'
require "attask"
require 'cgi'
require 'active_support/all'
require 'logger'
require "pony"
require "csv"
require "zlib"
require "lib/synchronizer.rb"
require "lib/helper.rb"
require "lib/google_downloader.rb"
require "lib/s3_loader.rb"
require 'date'
#require "databasedotcom"
include GLI

program_desc 'Program for synchronizing task'


desc 'Tests'
command :test do |c|
#  c.desc 'Execute only for one entity.'
#  c.default_value false
#  c.flag [:o, :only]
  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]

  c.desc 'S3 access key'
  c.flag [:s3_access]

  s.desc 'S3 secret key'
  c.flag [:s3_secret]


  c.action do |global_options,options,args|
    at_username = options[:at_username]
    at_password = options[:at_password]
    s3_access = options[:s3_access]
    s3_secret = options[:s3_secret]


    attask = Attask.client("gooddata",at_username,at_password)


    s3 = Synchronizer::S3.new(s3_access,s3_secret,"gooddata_com_attask",@log)
    s3.download_file("pd_timesheet.csv")





    #pp attask.project.search


    #"APT"





    #project = Attask::Project.new()
    #project.ID =  "511cacee0002e569b972734795337efc"
    #attask.project.exec_function(project,"calculateFinance")


  end
end



desc 'SFDC -> Attask Update'
command :update do |c|
#  c.desc 'Execute only for one entity.'
#  c.default_value false
#  c.flag [:o, :only]

  c.desc 'Username to SF account'
  c.flag [:sf_username]

  c.desc 'Password + token to SF account'
  c.flag [:sf_password]

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|

    sf_username = options[:sf_username]
    sf_password = options[:sf_password]
    at_username = options[:at_username]
    at_password = options[:at_password]


    @mapping = {
        "Intern" => "50f73f80002b9038434b0b21c00abb01",
        "Solution Architect" => "50eaa2290009eeba6d208a473efbb83d",
        "Practice Manager" => "50eaa298000a530cb7ba2ce1bf82bab1",
        "Consultant" => "50ad5628000469c57167f54cb5289999",
        "Architect" => "50eaa26e0009eed64d1aa82aa78b82ac",
        "Director" => "50eaa2380009eec4c88cd0b565099749",
        "SE Team Lead" => "50eaa20c0009ee98166e57ccc6c187b5",
        "Solution Engineer" => "50eaa1f60009ee8d8f23380a8a050c9b",
        "Contractor" => "50f02f810002afbea77b8672f462c330",
        "Customer Success Manager" => "50f54dfe00033ea4189871c0c749bc49"
    }

    attask = Attask.client("gooddata",at_username,at_password)
    #attask = Attask.client("gooddata",at_username,at_password,{:sandbox => true})

    #users = attask.user.search({:fields => "ID,name",:customFields => ""})
    projects = attask.project.search({:fields => "ID,companyID,groupID,status,condition,conditionType,budget,categoryID",:customFields => "DE:Salesforce ID,DE:Project Type,DE:Salesforce Type,DE:Practice Group,DE:Service Type,DE:Salesforce Name,DE:Product ID,DE:Billing Type,DE:Total Service Hours,DE:MRR"})

    salesforce = Synchronizer::SalesForce.new( sf_username,sf_password)
    salesforce.query("SELECT Amount, Id, Name, Type,x1st_year_services_total__c,ps_hours__c, Services_Type__c, Services_Type_Subcategory__c, Practice_Group__c,Celigo_Trigger_Amount__c FROM Opportunity",{:values => [:Id,:Amount,:Name,:x1st_year_services_total__c,:ps_hours__c,:Services_Type__c,:Services_Type_Subcategory__c,:Practice_Group__c,:Type,:Celigo_Trigger_Amount],:as_hash => true})

    count = 0

    projects = projects.find_all{|p| (p["DE:Salesforce ID"] != "N/A" and p["DE:Salesforce ID"] != nil) and (p["DE:Product ID"] == nil or p["DE:Product ID"] == "" or p["DE:Product ID"] == p["DE:Salesforce ID"]) }

    projects.each do |project|

    helper = Synchronizer::Helper.new(project["ID"],project["name"],"project")

    sfdc_object = salesforce.getValueByField(:Id,project["DE:Salesforce ID"])

    if sfdc_object.first != nil then

        sfdc_object = sfdc_object.first

        # UPDATE CONDITIONS -> Every time
        project[CGI.escape("DE:Salesforce Type")] = sfdc_object[:Type] unless helper.comparerString(project["DE:Salesforce Type"],sfdc_object[:Type],"Salesforce Type")
        project[CGI.escape("DE:Salesforce Name")] = sfdc_object[:Name] unless helper.comparerString(project["DE:Salesforce Name"],sfdc_object[:Name],"Salesforce Name")
        project[CGI.escape("DE:MRR")] = sfdc_object[:Celigo_Trigger_Amount__c] unless helper.comparerString(project["DE:MRR"],sfdc_object[:Celigo_Trigger_Amount__c],"MRR")

        # Additional Project Information - Type of Custome Fields
        if (project["categoryID"] == "50f5a7ee000d0278de51cc3a4d803e62") then
          project[CGI.escape("DE:Billing Type")] = sfdc_object[:Services_Type__c] unless helper.comparerString(project["DE:Billing Type"],sfdc_object[:Services_Type__c],"Billing Type")
          project[CGI.escape("DE:Service Type")] = sfdc_object[:Services_Type_Subcategory__c] unless helper.comparerString(project["DE:Service Type"],sfdc_object[:Services_Type_Subcategory__c],"Service Type")
          project[CGI.escape("DE:Product ID")] = sfdc_object[:Id] unless helper.comparerString(project["DE:Product ID"],sfdc_object[:Id],"Product ID")
        end

        if (project["DE:Project Type"] == "Implementation")
          project[CGI.escape("DE:Total Service Hours")] = sfdc_object[:PS_Hours__c] unless helper.comparerString(project["DE:Total Service Hours"],sfdc_object[:PS_Hours__c],"Total Service Hours")
        end


        # STATUS == Awaiting Sign-off then Condition Type = Manual and Status = On Target
        #if (project["status"] == "ASO") then
        #  project["condition"] = "ON" unless helper.comparerString(project["condition"],"ON","condition") # On-Target
        #  project["conditionType"] = "MN" unless helper.comparerString(project["conditionType"],"MN","conditionType") # Manual
        #end

        # Update budget if there is only one project with specific SFDC_ID
        duplicated_sfdc = projects.find_all{|p| p["DE:Salesforce ID"] != nil and project["DE:Salesforce ID"] != nil and project["DE:Project Type"] != "Maintenance" and p["DE:Salesforce ID"].casecmp(project["DE:Salesforce ID"]) == 0 ? true : false}

        if (duplicated_sfdc.count == 1 and sfdc_object[:X1st_year_Services_Total__c] != nil and project["DE:Project Type"] != "Maintenance") then
          project.budget = sfdc_object[:X1st_year_Services_Total__c] unless helper.comparerFloat(project.budget,sfdc_object[:X1st_year_Services_Total__c],"budget")
        end

        # To fix problem with escaping
        # All the values are present if needed, but with URL escaping
        #pp project

        project.delete("DE:Salesforce ID")
        project.delete("DE:Project Type")
        project.delete("DE:Salesforce Type")
        project.delete("DE:Salesforce Name")
        project.delete("DE:Service Type")
        project.delete("DE:Practice Group")
        project.delete("DE:Billing Type")
        project.delete("DE:Product ID")
        project.delete("DE:Total Service Hours")

        attask.project.update(project) if helper.changed
        helper.printLog(@log) if helper.changed
        @work_done = true if helper.changed


        if (sfdc_object[:X1st_year_Services_Total__c] != nil and Float(sfdc_object[:X1st_year_Services_Total__c]) != 0 and sfdc_object[:PS_Hours__c] != nil and  Float(sfdc_object[:PS_Hours__c]) != 0 and project["DE:Project Type"] != "Maintenance") then
          budget = Float(sfdc_object[:X1st_year_Services_Total__c])
          hours = Float(sfdc_object[:PS_Hours__c])
          rateValue = budget / hours if hours > 0

          rates = attask.rate.search({},{:projectID => project.ID})
          recalculate = false

          @mapping.each_pair do |k,v|
            #Check if rate is in system
            rate = rates.find{|r| r.roleID == v}
            if (rate != nil)
              oldValue = Float(rate.rateValue)
              oldValue = oldValue.round(2)
              newValue =   Float(rateValue)
              newValue = newValue.round(2)
              if oldValue !=  newValue
                  rate.rateValue = newValue
                  attask.rate.update(rate)
                  helper.getProjectInfo(@log) if recalculate == false
                  @log.info "We are updating rate from #{oldValue} to #{newValue} (#{rate.roleID}) for project #{project["ID"]}"
                  recalculate = true
              end
            else
               rate = Attask::Rate.new()
               rate["projectID"] = project.ID
               rate["roleID"] = v
               rate["rateValue"] = rateValue.round(2)
               helper.getProjectInfo(@log) if recalculate == false
               @log.info "We are adding rate #{rateValue.round(2)} (#{v}) for project #{project["ID"]}"
               attask.rate.add(rate)
               recalculate = true
            end
            attask.project.exec_function(project,"calculateFinance") if recalculate == true
            if recalculate == true then
              @work_done = true
              @log.info "------------------------------------------"
            end

          end
        end
        end
      end
    end
 end



desc 'SFDC -> Attask Update'
command :update_product do |c|
#  c.desc 'Execute only for one entity.'
#  c.default_value false
#  c.flag [:o, :only]

  c.desc 'Username to SF account'
  c.flag [:sf_username]

  c.desc 'Password + token to SF account'
  c.flag [:sf_password]

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|

    sf_username = options[:sf_username]
    sf_password = options[:sf_password]
    at_username = options[:at_username]
    at_password = options[:at_password]


    #@mapping = {
    #    "Intern" => "50f73f80002b9038434b0b21c00abb01",
    #    "Solution Architect" => "50eaa2290009eeba6d208a473efbb83d",
    #    "Practice Manager" => "50eaa298000a530cb7ba2ce1bf82bab1",
    #    "Consultant" => "50ad5628000469c57167f54cb5289999",
    #    "Architect" => "50eaa26e0009eed64d1aa82aa78b82ac",
    #    "Director" => "50eaa2380009eec4c88cd0b565099749",
    #    "SE Team Lead" => "50eaa20c0009ee98166e57ccc6c187b5",
    #    "Solution Engineer" => "50eaa1f60009ee8d8f23380a8a050c9b",
    #    "Contractor" => "50f02f810002afbea77b8672f462c330",
    #    "Customer Success Manager" => "50f54dfe00033ea4189871c0c749bc49"
    #}



    attask = Attask.client("gooddata",at_username,at_password)
    #attask = Attask.client("gooddata",at_username,at_password,{:sandbox => true})

    #users = attask.user.search({:fields => "ID,name",:customFields => ""})
    projects = attask.project.search({:fields => "ID,companyID,groupID,status,condition,conditionType,budget,categoryID,name",:customFields => "DE:Salesforce ID,DE:Project Type,DE:Salesforce Type,DE:Service Type,DE:Salesforce Name,DE:Product ID,DE:Billing Type,DE:Total Service Hours,DE:Budget Hours,DE:Hours per Period,DE:Number of Periods,DE:Expiration Period,DE:Total Service Hours,DE:MRR,DE:Investment Hours,DE:Investment Reason"})

    @mapping = attask.role.search({:fields => "ID,name"}).map{|r| {r["name"] => r["ID"]}}


    salesforce = Synchronizer::SalesForce.new(sf_username,sf_password)
    salesforce.query("SELECT Amount, Id, Type,x1st_year_services_total__c,ps_hours__c, Services_Type__c, Services_Type_Subcategory__c, Practice_Group__c,StageName, Name,AccountId,Celigo_Trigger_Amount__c FROM Opportunity",{:values => [:Id,:Amount,:x1st_year_services_total__c,:ps_hours__c,:Services_Type__c,:Services_Type_Subcategory__c,:Practice_Group__c,:Type,:StageName,:Name,:AccountId,:Celigo_Trigger_Amount],:as_hash => true})

    account = Synchronizer::SalesForce.new(sf_username,sf_password)
    account.query("SELECT Id, Name FROM Account",{:values => [:Id,:Name],:as_hash => true})

    pricebookentry = Synchronizer::SalesForce.new(sf_username,sf_password)
    pricebookentry.query("SELECT Id, Product2Id FROM PricebookEntry",{:values => [:Id,:Product2Id],:as_hash => true})
    pricebookentry = pricebookentry.output

    products = Synchronizer::SalesForce.new(sf_username,sf_password)
    products.query("SELECT Id,Name FROM Product2",{:values => [:Id,:Name],:as_hash => true})
    products = products.output

    opportunityLineItem = Synchronizer::SalesForce.new(sf_username,sf_password)
    opportunityLineItem.query("SELECT Expiration_Period__c,Id,Number_of_Periods__c,Service_Hours_per_Period__c,OpportunityId,Product_Family__c,TotalPrice,Total_Service_Hours__c,PricebookEntryId,Service_Type__c,Services_Billing_Type__c,Approved_Investment_Hours__c,Investment_Reason__c FROM OpportunityLineItem",{:values => [:Expiration_Period__c,:Id,:Number_of_Periods__c,:Service_Hours_per_Period__c,:OpportunityId,:Product_Family__c,:TotalPrice,:Total_Service_Hours__c,:PricebookEntryId,:Service_Type__c,:Services_Billing_Type__c,:Approved_Investment_Hours__c,:Investment_Reason__c],:as_hash => true})
    opportunityLineItem_data = opportunityLineItem.output


    #opportunityLineItem_data = opportunityLineItem_data.find_all {|li| li[:Product_Family__c] == "Service" and Float(li[:TotalPrice]) > 0 and Float(li[:Total_Service_Hours__c]) > 0 }

    #salesforce.filter("6 - CLOSED WON")
    salesforce_data = salesforce.output



    opportunityLineItem_data.each do |li|
      s = salesforce_data.find{|s| s[:Id] == li[:OpportunityId]}

      li[:Opportunity] = s
      pe = pricebookentry.find do |e|
        e[:Id] == li[:PricebookEntryId]
      end
      product = products.find do |p|
        p[:Id] == pe[:Product2Id]
      end
      li[:Product] = product
    end

    count = 0

    projects = projects.find_all{|p| (p["DE:Product ID"] != nil and p["DE:Product ID"] != "" and p["DE:Product ID"] != p["DE:Salesforce ID"]) }

    projects.each do |project|

      helper = Synchronizer::Helper.new(project["ID"],project["name"],"project")

      sfdc_object = opportunityLineItem_data.find {|li| li[:Id] == project["DE:Product ID"]}


      if (!sfdc_object.nil?)

        project[CGI.escape("DE:Salesforce Type")] = sfdc_object[:Opportunity][:Type] unless helper.comparerString(project["DE:Salesforce Type"],sfdc_object[:Opportunity][:Type],"Salesforce Type")
        project[CGI.escape("DE:Salesforce Name")] = sfdc_object[:Opportunity][:Name] unless helper.comparerString(project["DE:Salesforce Name"],sfdc_object[:Opportunity][:Name],"Salesforce Name")
        project[CGI.escape("DE:MRR")] = sfdc_object[:Opportunity][:Celigo_Trigger_Amount__c] unless helper.comparerString(project["DE:MRR"],sfdc_object[:Opportunity][:Celigo_Trigger_Amount__c],"MRR")





        # Additional Project Information - Type of Custome Fields
        if (project["categoryID"] == "50f5a7ee000d0278de51cc3a4d803e62") then

          #project.name =  (sfdc_object[:Opportunity][:Name].match(/^[^->]*/)[0].strip + " " + sfdc_object[:Product][:Name]) unless helper.comparerString(project["name"],(sfdc_object[:Opportunity][:Name].match(/^[^->]*/)[0].strip + " " + sfdc_object[:Product][:Name]),"name")
          project[CGI.escape("DE:Service Type")] = sfdc_object[:Service_Type__c] unless helper.comparerString(project["DE:Service Type"],sfdc_object[:Service_Type__c],"Service Type")
          project[CGI.escape("DE:Billing Type")] = sfdc_object[:Services_Billing_Type__c] unless helper.comparerString(project["DE:Billing Type"],sfdc_object[:Services_Billing_Type__c],"Billing Type")
          project[CGI.escape("DE:Hours per Period")] = sfdc_object[:Service_Hours_per_Period__c] unless helper.comparerString(project["DE:Hours per Period"],sfdc_object[:Service_Hours_per_Period__c],"Hours per Period")
          project[CGI.escape("DE:Number of Periods")] = sfdc_object[:Number_of_Periods__c] unless helper.comparerString(project["DE:Number of Periods"],sfdc_object[:Number_of_Periods__c],"Number of Periods")
          project[CGI.escape("DE:Expiration Period")] = sfdc_object[:Expiration_Period__c] unless helper.comparerString(project["DE:Expiration Period"],sfdc_object[:Expiration_Period__c],"Expiration Period")
          project[CGI.escape("DE:Investment Hours")] = sfdc_object[:Approved_Investment_Hours__c] unless helper.comparerString(project["DE:Investment Hours"],sfdc_object[:Approved_Investment_Hours__c],"Investment Hours")
          project[CGI.escape("DE:Investment Reason")] = sfdc_object[:Investment_Reason__c] unless helper.comparerString(project["DE:Investment Reason"],sfdc_object[:Investment_Reason__c],"Investment Reason")
        end

        if (project["DE:Project Type"] == "Implementation")
          project[CGI.escape("DE:Total Service Hours")] = sfdc_object[:Total_Service_Hours__c] unless helper.comparerString(project["DE:Total Service Hours"],sfdc_object[:Total_Service_Hours__c],"Total Service Hours")
        end

        # STATUS == Awaiting Sign-off then Condition Type = Manual and Status = On Target
        #if (project["status"] == "ASO") then
        #  project["condition"] = "ON" unless helper.comparerString(project["condition"],"ON","condition") # On-Target
        #  project["conditionType"] = "MN" unless helper.comparerString(project["conditionType"],"MN","conditionType") # Manual
        #end

        # Update budget if there is only one project with specific SFDC_ID
        duplicated_sfdc = projects.find_all{|p| p["DE:Product ID"] != nil and project["DE:Product ID"] != nil and project["DE:Project Type"] == "Implementation" and p["DE:Product ID"].casecmp(project["DE:Product ID"]) == 0 ? true : false}

        if (duplicated_sfdc.count == 1 and sfdc_object[:Service_Hours_per_Period__c] != nil and !sfdc_object[:Number_of_Periods__c].nil? and project["DE:Project Type"] != "Maintenance") then
          #project[CGI.escape("DE:Budget Hours")] =  sfdc_object[:Total_Service_Hours__c] unless helper.comparerString(project["DE:Budget Hours"],sfdc_object[:Total_Service_Hours__c],"Budget Hours")
          # Per request from M.H. the Budget Hour will be calculated as Number of Periods * Hours Per Period (9.10.2014)
          budget_hours = Float(sfdc_object[:Service_Hours_per_Period__c]) *  Float(sfdc_object[:Number_of_Periods__c])
          project[CGI.escape("DE:Budget Hours")] =  budget_hours unless helper.comparerFloat(project["DE:Budget Hours"],budget_hours.to_s,"Budget Hours")
          project.budget =  sfdc_object[:TotalPrice] unless helper.comparerString(project["budget"],sfdc_object[:TotalPrice],"budget")
        end


        # For martin request there is action connected to Execute field in Attask
        # In case that Execute! is enabled and task has statul CPL or Planned Hours < Actual Hours we will put Actual Hours to Planned hours
        #if (project["DE:Align Planned hours with Actual"] == "Execute!")
        #  #tasks = attask.task.search({:fields => "ID,status,workRequired,actualWork,durationType",:customFields => ""},{:projectID => project.ID})
        #
        #  tasks = attask.task.search({:fields => "ID,status,workRequired,actualWork,durationType",:customFields => ""},{:ID => "532c3d9300251222f4e6fbd725c98911"})
        #
        #
        #  tasks.each do |task|
        #    pp task
        #    puts "------------------------------------------"
        #    if (task["status"] == "CPL")
        #      puts "THIS IS COMPLETED LEAF"
        #      #task["status"] = "INP"
        #      #attask.task.update(task)
        #      task["workRequired"] = 180
        #      #task["status"] = "CPL"
        #      task["durationType"] = "A"
        #      attask.task.update(task)
        #    elsif (task["workRequired"] < task["actualWork"]*60)
        #      puts "THIS IS REQUIRED < ACTUAL LEAF"
        #      pp task
        #      task["workRequired"] = (task["actualWork"] * 60).to_i
        #      task["durationType"] = "A"
        #      attask.task.update(task)
        #    end
        #  end
        #
        #  fail "kokos"
        #
        #  project[CGI.escape("DE:Align Planned hours with Actual")] = ""
        #end


        project.delete("DE:Salesforce ID")
        project.delete("DE:Project Type")
        project.delete("DE:Salesforce Type")
        project.delete("DE:Salesforce Name")
        project.delete("DE:Service Type")
        project.delete("DE:Budget Hours")
        project.delete("DE:Service Type")
        project.delete("DE:Billing Type")
        project.delete("DE:Total Service Hours")
        project.delete("DE:Product ID")
        project.delete("DE:Hours per Period")
        project.delete("DE:Number of Periods")
        project.delete("DE:Expiration Period")
        project.delete("DE:Total Service Hours")
        project.delete("DE:Investment Hours")
        project.delete("DE:Investment Reason")
        #project.delete("DE:Align Planned hours with Actual")

        attask.project.update(project) if helper.changed

        helper.printLog(@log) if helper.changed
        @work_done = true if helper.changed


        if (sfdc_object[:TotalPrice] != nil and Float(sfdc_object[:TotalPrice]) != 0 and !sfdc_object[:Service_Hours_per_Period__c].nil? and !sfdc_object[:Number_of_Periods__c].nil? and project["DE:Project Type"] != "Maintenance") then
          hours = Float(sfdc_object[:Service_Hours_per_Period__c]) *  Float(sfdc_object[:Number_of_Periods__c])
          #hours = Float(sfdc_object[:Total_Service_Hours__c])
          # Per request from M.H. the Budget Hour will be calculated as Number of Periods * Hours Per Period (9.10.2014)
          #hours = Integer(sfdc_object[:Service_Hours_per_Period__c]) *  Integer(sfdc_object[:Number_of_Periods__c])
          budget = Float(sfdc_object[:TotalPrice])
          rateValue = budget / hours if hours > 0

          rates = attask.rate.search({},{:projectID => project.ID})
          recalculate = false

          @mapping.each do |v|
            #Check if rate is in system
            rate = rates.find{|r| r.roleID == v.values.first}
            if (rate != nil)
              oldValue = Float(rate.rateValue)
              oldValue = oldValue.round(2)
              newValue =   Float(rateValue)
              newValue = newValue.round(2)
              if oldValue !=  newValue
                rate.rateValue = newValue
                attask.rate.update(rate)
                helper.getProjectInfo(@log) if recalculate == false
                @log.info "We are updating rate from #{oldValue} to #{newValue} (#{rate.roleID}) for project #{project["ID"]}"
                recalculate = true
              end
            else
              rate = Attask::Rate.new()
              rate["projectID"] = project.ID
              rate["roleID"] = v.values.first
              rate["rateValue"] = rateValue.round(2)
              helper.getProjectInfo(@log) if recalculate == false
              @log.info "We are adding rate #{rateValue.round(2)} (#{v.values.first}) for project #{project["ID"]}"
              attask.rate.add(rate)
              recalculate = true
            end
            attask.project.exec_function(project,"calculateFinance") if recalculate == true
            if recalculate == true then
              @work_done = true
              @log.info "------------------------------------------"
            end

          end
        end








      end

    end
  end
end



desc 'Generate metadata'
command :generate_metadata do |c|

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]

  c.desc 'Export path'
  c.flag [:export]


  c.action do |global_options,options,args|
    at_username = options[:at_username]
    at_password = options[:at_password]
    export = options[:export]

    attask = Attask.client("gooddata",at_username,at_password)


    pp attask.project.metadata["data"]

    main = Hash.new

    main["assigment"] = createHash(attask.assigment.metadata["data"])
    main["baseline"] = createHash(attask.baseline.metadata["data"])
    main["baselinetask"] = createHash(attask.baselinetask.metadata["data"])
    main["category"] = createHash(attask.category.metadata["data"])
    main["company"] = createHash(attask.company.metadata["data"])
    main["expense"] = createHash(attask.expense.metadata["data"])
    main["expensetype"] = createHash(attask.expensetype.metadata["data"])
    main["group"] = createHash(attask.group.metadata["data"])
    main["hour"] = createHash(attask.hour.metadata["data"])
    main["hourtype"] = createHash(attask.hourtype.metadata["data"])
    main["issue"] = createHash(attask.issue.metadata["data"])
    main["resourcepool"] = createHash(attask.resourcepool.metadata["data"])
    main["risk"] = createHash(attask.risk.metadata["data"])
    main["risktype"] = createHash(attask.risktype.metadata["data"])
    main["role"] = createHash(attask.role.metadata["data"])
    main["schedule"] = createHash(attask.schedule.metadata["data"])
    main["task"] = createHash(attask.task.metadata["data"])
    main["team"] = createHash(attask.team.metadata["data"])
    main["timesheet"] = createHash(attask.timesheet.metadata["data"])
    main["user"] = createHash(attask.user.metadata["data"])
    main["project"] = createHash(attask.project.metadata["data"])
    main["milestone"] = createHash(attask.milestone.metadata["data"])

    File.open(export + "metadata.json","w") do |f|
      f.write(JSON.pretty_generate(main))
    end
  end
end


desc 'Init ES'
command :init do |c|

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]

  c.desc 'Export path'
  c.flag [:export]

  c.desc 'S3 access key'
  c.flag [:s3_access]

  s.desc 'S3 secret key'
  c.flag [:s3_secret]





  c.action do |global_options,options,args|

    at_username = options[:at_username]
    at_password = options[:at_password]
    export = options[:export]
    s3_access = options[:s3_access]
    s3_secret = options[:s3_secret]

    attask = Attask.client("gooddata",at_username,at_password)

    attask.project.exportToCsv({:filename => "project.csv",:filepath => export,:gzip => true})
    attask.assigment.exportToCsv({:filename => "assigment.csv",:filepath => export,:gzip => true})
    attask.baseline.exportToCsv({:filename => "baseline.csv",:filepath => export,:gzip => true})
    attask.baselinetask.exportToCsv({:filename => "baselinetask.csv",:filepath => export,:gzip => true})
    attask.category.exportToCsv({:filename => "category.csv",:filepath => export,:gzip => true})
    attask.company.exportToCsv({:filename => "company.csv",:filepath => export,:gzip => true})
    attask.expense.exportToCsv({:filename => "expense.csv",:filepath => export,:gzip => true})
    attask.expensetype.exportToCsv({:filename => "expensetype.csv",:filepath => export,:gzip => true})
    attask.group.exportToCsv({:filename => "group.csv",:filepath => export,:gzip => true})
    attask.hour.exportToCsv({:filename => "hour.csv",:filepath => export,:gzip => true})
    attask.hourtype.exportToCsv({:filename => "hourtype.csv",:filepath => export,:gzip => true})
    attask.issue.exportToCsv({:filename => "issue.csv",:filepath => export,:gzip => true})
    ###attask.rate.exportToCsv({:filename => "rate.csv",:filepath => "/home/adrian.toman/export/"})
    attask.resourcepool.exportToCsv({:filename => "resourcepool.csv",:filepath => export,:gzip => true})
    attask.risk.exportToCsv({:filename => "risk.csv",:filepath => export,:gzip => true})
    attask.risktype.exportToCsv({:filename => "risktype.csv",:filepath => export,:gzip => true})
    attask.role.exportToCsv({:filename => "role.csv",:filepath => export,:gzip => true})
    attask.schedule.exportToCsv({:filename => "schedule.csv",:filepath => export,:gzip => true})
    attask.task.exportToCsv({:filename => "task.csv",:filepath => export,:gzip => true})
    attask.team.exportToCsv({:filename => "team.csv",:filepath => export,:gzip => true})
    attask.timesheet.exportToCsv({:filename => "timesheet.csv",:filepath => export,:gzip => true})
    attask.user.exportToCsv({:filename => "user.csv",:filepath => export,:gzip => true})
    attask.milestone.exportToCsv({:filename => "milestone.csv",:filepath => export,:gzip => true})

    attask.project.exportToCsv({
                                  :fields => "actualCompletionDate,actualStartDate,description,ID,ownerID,percentComplete,status,lastUpdateDate,plannedStartDate,plannedCompletionDate,projectedStartDate,projectedCompletionDate,name",
                                  :customFields => "DE:Project PID,DE:Project Type,DE:Salesforce ID,DE:Salesforce Type,DE:Solution Architect,DE:Solution Engineer,DE:Salesforce Name",
                                  :filename => "project_fix.csv",
                                  :filepath => export,
                                  :gzip => true
                               })

    # Generate Metadata
    main = Hash.new
    main["assigment"] = createHash(attask.assigment.metadata["data"])
    main["baseline"] = createHash(attask.baseline.metadata["data"])
    main["baselinetask"] = createHash(attask.baselinetask.metadata["data"])
    main["category"] = createHash(attask.category.metadata["data"])
    main["company"] = createHash(attask.company.metadata["data"])
    main["expense"] = createHash(attask.expense.metadata["data"])
    main["expensetype"] = createHash(attask.expensetype.metadata["data"])
    main["group"] = createHash(attask.group.metadata["data"])
    main["hour"] = createHash(attask.hour.metadata["data"])
    main["hourtype"] = createHash(attask.hourtype.metadata["data"])
    main["issue"] = createHash(attask.issue.metadata["data"])
    main["resourcepool"] = createHash(attask.resourcepool.metadata["data"])
    main["risk"] = createHash(attask.risk.metadata["data"])
    main["risktype"] = createHash(attask.risktype.metadata["data"])
    main["role"] = createHash(attask.role.metadata["data"])
    main["schedule"] = createHash(attask.schedule.metadata["data"])
    main["task"] = createHash(attask.task.metadata["data"])
    main["team"] = createHash(attask.team.metadata["data"])
    main["timesheet"] = createHash(attask.timesheet.metadata["data"])
    main["user"] = createHash(attask.user.metadata["data"])
    main["project"] = createHash(attask.project.metadata["data"])
    main["milestone"] = createHash(attask.milestone.metadata["data"])

    File.open(export + "metadata.json","w") do |f|
      f.write(JSON.pretty_generate(main))
    end

    s3 = Synchronizer::S3.new(s3_access,s3_secret,"gooddata_com_attask",@log)
    s3.store_to_s3(export)



  end
end

desc 'Add new projects to SF'
command :add do |c|

  c.desc 'Username to SF account'
  c.flag [:sf_username]

  c.desc 'Password + token to SF account'
  c.flag [:sf_password]

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|
    sf_username = options[:sf_username]
    sf_password = options[:sf_password]
    at_username = options[:at_username]
    at_password = options[:at_password]

    #attask = Attask.client("gooddata",at_username,at_password,{:sandbox => true})
    attask = Attask.client("gooddata",at_username,at_password)

    @user = {
        "West" => "gautam.kher@gooddata.com",
        "Partner" => "gautam.kher@gooddata.com",
        "East" => "matt.maudlin@gooddata.com",
        "Europe" => "martin.hapl@gooddata.com"
    }


    projects = attask.project.search({:fields => "ID,name,DE:Salesforce ID,DE:Product ID",:customFields => ""})
    #projects = attask.project.search({:fields => "ID,name,DE:Salesforce ID",:customFields => ""})
    users = attask.user.search()
    companies = attask.company.search(({:fields => "ID,name"}))

    salesforce = Synchronizer::SalesForce.new(sf_username,sf_password)
    salesforce.query("SELECT Amount, Id, Type,x1st_year_services_total__c,ps_hours__c, Services_Type__c, Services_Type_Subcategory__c, Practice_Group__c,StageName, Name,AccountId FROM Opportunity",{:values => [:Id,:Amount,:x1st_year_services_total__c,:ps_hours__c,:Services_Type__c,:Services_Type_Subcategory__c,:Practice_Group__c,:Type,:StageName,:Name,:AccountId],:as_hash => true})

    account = Synchronizer::SalesForce.new(sf_username,sf_password)
    account.query("SELECT Id, Name FROM Account",{:values => [:Id,:Name],:as_hash => true})

    pricebookentry = Synchronizer::SalesForce.new(sf_username,sf_password)
    pricebookentry.query("SELECT Id, Product2Id FROM PricebookEntry",{:values => [:Id,:Product2Id],:as_hash => true})
    pricebookentry = pricebookentry.output

    products = Synchronizer::SalesForce.new(sf_username,sf_password)
    products.query("SELECT Id,Name FROM Product2",{:values => [:Id,:Name],:as_hash => true})
    products = products.output


    opportunityLineItem = Synchronizer::SalesForce.new(sf_username,sf_password)
    opportunityLineItem.query("SELECT Expiration_Period__c,Id,Number_of_Periods__c,Service_Hours_per_Period__c,OpportunityId,Product_Family__c,TotalPrice,Total_Service_Hours__c,PricebookEntryId,Approved_Investment_Hours__c,Service_Type__c FROM OpportunityLineItem",{:values => [:Expiration_Period__c,:Id,:Number_of_Periods__c,:Service_Hours_per_Period__c,:OpportunityId,:Product_Family__c,:TotalPrice,:Total_Service_Hours__c,:PricebookEntryId,:Approved_Investment_Hours__c,:Service_Type__c],:as_hash => true})
    opportunityLineItem_data = opportunityLineItem.output

    salesforce.filter("6 - CLOSED WON")
    salesforce_data = salesforce.output



    opportunityLineItem_data.each do |li|
      s = salesforce_data.find{|s| s[:Id] == li[:OpportunityId]}
      li[:Opportunity] = s
      pe = pricebookentry.find do |e|
        e[:Id] == li[:PricebookEntryId]
      end

      product = products.find do |p|
        p[:Id] == pe[:Product2Id]
      end
      li[:Product] = product
    end

    opportunityLineItem_data = opportunityLineItem_data.find_all {|li| (li[:Product_Family__c] == "Service" and Float(li[:TotalPrice]) > 0 and Float(li[:Total_Service_Hours__c]) > 0) or (li[:Product_Family__c] == "Service" and Float(li[:Total_Service_Hours__c]) > 0 and Float(li[:Total_Service_Hours__c]) == Float(li[:Approved_Investment_Hours__c])) or ( (li[:Product][:Name] == 'GD-ENT-EOR' or li[:Product][:Name] == 'EOR-CST') and Float(li[:Total_Service_Hours__c]) > 0)}
    opportunityLineItem_data = opportunityLineItem_data.find_all {|li| li[:Opportunity] != nil}

    #and Float(li[:TotalPrice]) > 0
    # Find all product which were not created already
    opportunityLineItem_data = opportunityLineItem_data.find_all do |li|
      project = projects.find {|p| !p["DE:Product ID"].nil? and p["DE:Product ID"].casecmp(li[:Id]) == 0 ? true : false}
      if (project.nil?)
        true
      else
        false
      end
    end

    count = 0

    opportunityLineItem_data.each do |li|


      notification_to = {}

      accountName = account.output.find{|a| a[:Id] == li[:Opportunity][:AccountId]}[:Name]

      company = companies.find{|c| c.name.casecmp(accountName) == 0 ? true : false}
      if (company == nil) then
         company = Attask::Company.new
         company["name"] = accountName
         @log.info "Creating company #{company["name"]}"
         company = attask.company.add(company).first
      end

      user = users.find{|u| u.emailAddr == "miloslav.zientek@gooddata.com"}

      project = Attask::Project.new()
      project[CGI.escape("DE:Product ID")] = li[:Id]
      project.name =  li[:Opportunity][:Name].match(/^[^->]*/)[0].strip + " " + li[:Product][:Name]
      project[CGI.escape("DE:Total Service Hours")] = li[:Total_Service_Hours__c]
      project.status = "IDA"


      if ((!li[:Opportunity][:Services_Type_Subcategory__c].nil? and li[:Opportunity][:Services_Type_Subcategory__c] == "EOR") or (li[:Product][:Name] == 'GD-ENT-EOR') or (li[:Product][:Name] == 'EOR-CST'))
        #project.ownerID = users.find{|u| u.username == "tom.kolich@gooddata.com"}.ID
        project.ownerID = users.find{|u| u.username == "jiri.stovicek@gooddata.com"}.ID
        project["groupID"] = "50f73e62002b7f7a9d0196eba05bf1b1"
        notification_to = {:to => "tom.kolich@gooddata.com"}
        notification_to[:cc] = ["jiri.stovicek@gooddata.com"]
      elsif (li[:Opportunity][:Type] == "Powered by")
        if (li[:Service_Type__c] == "PS")
          project.ownerID = users.find{|u| u.username == "jiri.stovicek@gooddata.com"}.ID
          project["programID"] = "52e01c390038a885fa659dea5d3b2e3b"
        elsif (li[:Service_Type__c] == "PSOR")
          project.ownerID = users.find{|u| u.username == "jiri.stovicek@gooddata.com"}.ID
          project["programID"] = "5420533b006eb9feac3c40df0f8b0178"
        elsif (li[:Service_Type__c] == "EOR" or li[:Service_Type__c] == "CSM")
          project.ownerID = users.find{|u| u.username == "tom.kolich@gooddata.com"}.ID
          project["programID"] = "542124640019e2476c1e1c49dc2b315f"
        end

        notification_to[:to] = 'martin.hapl@gooddata.com'
        notification_to[:cc] = ['karel.novak@gooddata.com','michal.hauzirek@gooddata.com','jan.cisar@gooddata.com',"jiri.stovicek@gooddata.com","tom.kolich@gooddata.com"]
        project["groupID"] = "51dece1700022dc5b57063720458e8d2"
      elsif (li[:Opportunity][:Type] == "Direct")
        if (li[:Service_Type__c] == "PS")
          project.ownerID = users.find{|u| u.username == "emily.rugaber@gooddata.com"}.ID
          project["programID"] = "542052f6006eb1df6f2aa25578bf00de"
        elsif
          project.ownerID = users.find{|u| u.username == "emily.rugaber@gooddata.com"}.ID
          project["programID"] = "542124960019e2cb8e42fcb1e9bd0796"
        elsif (li[:Service_Type__c] == "EOR" or li[:Service_Type__c] == "CSM")
          project.ownerID = users.find{|u| u.username == "tom.kolich@gooddata.com"}.ID
          project["programID"] = "542128040019fa3458191adec117b86c"
        end

        project["groupID"] = "50f73e62002b7f7a9d0196eba05bf1b1"
        notification_to = {
            :to => 'aaron.myhre@gooddata.com',
            :cc => ['emily.rugaber@gooddata.com','sumeet.howe@gooddata.com',"jiri.stovicek@gooddata.com","tom.kolich@gooddata.com"]
        }
      end

      project["companyID"] =  company.ID
      project["categoryID"] = "50f5a7ee000d0278de51cc3a4d803e62"

      project["scheduleID"] = "50f558520003e0c8c8d1290e0d051571"
      project["milestonePathID"] = "50f5e5be001a53c6b9027b25d7b00854"
      project["ownerPrivileges"] = "APT"

      project["URL"] = "https://na6.salesforce.com/#{li[:Id]}" if li[:Id] != nil
      project[CGI.escape("DE:Salesforce ID")] = li[:Opportunity][:Id]

      #li[:Product][:Name] == 'PS-INVESTMENT'
      # Requested by M.H od 9.9.2014
      if (Float(li[:Approved_Investment_Hours__c]) == Float(li[:Total_Service_Hours__c]))
        project[CGI.escape("DE:Project Type")] = "Investment"
        project[CGI.escape("DE:Budget Hours")] =  0
      elsif (Float(li[:TotalPrice]) > 0)
        project[CGI.escape("DE:Project Type")] = "Implementation"
        budget_hours = Float(li[:Service_Hours_per_Period__c]) *  Float(li[:Number_of_Periods__c])
        project[CGI.escape("DE:Budget Hours")] =  budget_hours
      elsif (li[:Product][:Name] == 'GD-ENT-EOR' or li[:Product][:Name] == 'EOR-CST')
        project[CGI.escape("DE:Project Type")] = "Customer Success"
        budget_hours = Float(li[:Service_Hours_per_Period__c]) *  Float(li[:Number_of_Periods__c])
        project[CGI.escape("DE:Budget Hours")] =  budget_hours
      end

      project[CGI.escape("DE:Hours per Period")] = li[:Service_Hours_per_Period__c]
      project[CGI.escape("DE:Number of Periods")] = li[:Number_of_Periods__c]
      project[CGI.escape("DE:Expiration Period")] = li[:Expiration_Period__c]
      project[CGI.escape("DE:Salesforce Type")] = li[:Opportunity][:Type]

      @log.info "Creating project #{project.name} with SFDC ID #{li[:Id]}"

      project = attask.project.add(project)[0]
      Pony.mail(:to => notification_to[:to],:cc => notification_to[:cc],:from => 'attask@gooddata.com', :subject => "New project with #{project.name} was create in attask.", :body => "Project link: https://gooddata.attask-ondemand.com/project/view?ID=#{project.ID}")
      @work_done = true
      count = count + 1
    end
  end
end


desc 'Spredsheet'
command :spredsheet do |c|



  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]

  c.desc 'Username to Google'
  c.flag [:gs_username]

  c.desc 'Password to Google'
  c.flag [:gs_password]

  c.desc 'Username to Google'
  c.flag [:sf_username]

  c.desc 'Password to Google'
  c.flag [:sf_password]



  c.action do |global_options,options,args|
    at_username = options[:at_username]
    at_password = options[:at_password]
    gs_username = options[:gs_username]
    gs_password = options[:gs_password]
    sf_username = options[:sf_username]
    sf_password = options[:sf_password]

    attask = Attask.client("gooddata",at_username,at_password)

    fields = ["Customer","Project","Directory name","Status","Type","Uses FTP?","Uses ES?","Contract Ends","Sync Start","Sync End","Project pid","Running on","Infrastructure","Data Validation?","Validation user access","Referential integrity?","QAHO?","File existence check?","Archiver","CS Person","MS Person","Customer Name","Customer Phone","Customer Email","SF Downloader version","NOTE","Working Hours","TZ","Opp ID","Restart","Confluence","Automatic validation","Tier","Tech. user","CRON","Duration"]

    google = Synchronizer::GoogleDownloader.new(gs_username,gs_password,"0ApZR1O4QVzThdElSRHpITnpGRGZ4ckFJR2ZhUm9YeVE",0,fields)

    users = attask.user.search()

    salesforce = Synchronizer::SalesForce.new( sf_username,sf_password)
    salesforce.query("SELECT Name,Amount, Id, Type,x1st_year_services_total__c,ps_hours__c, Services_Type__c, Services_Type_Subcategory__c, Practice_Group__c,AccountId FROM Opportunity",{:values => [:Id,:Amount,:x1st_year_services_total__c,:ps_hours__c,:Services_Type__c,:Services_Type_Subcategory__c,:Practice_Group__c,:Type,:AccountId,:Name],:as_hash => true})

    account = Synchronizer::SalesForce.new(sf_username,sf_password)
    account.query("SELECT Id, Name FROM Account",{:values => [:Id,:Name],:as_hash => true})

    companies = attask.company.search(({:fields => "ID,name"}))

    #pp account.output

    google.output.each do |row|
        if (row["Opp ID"] != "" && row["Status"] != "Suspended" ) then

        sfdc_object = salesforce.getValueByField(:Id,row["Opp ID"]).first
        accountName = account.output.find{|a| a[:Id].first == sfdc_object[:AccountId]}[:Name]


        company = companies.find{|c| c.name.casecmp(accountName) == 0 ? true : false}
        if (company == nil) then
          company = Attask::Company.new
          company["name"] = accountName
          puts "Creating company #{company["name"]}"

          company = attask.company.add(company).first
          companies = attask.company.search(({:fields => "ID,name"}))
        end


        project = Attask::Project.new()
        project.name =  "#{row["Customer"]} - #{row["Project"]}"

        user = nil
        if (row["MS Person"] != nil)
          user = users.find{|u| u.emailAddr == row["MS Person"]}
        end

        project.ownerID = user.ID if user != nil
        project["companyID"] =  company.ID
        project["categoryID"] = "512c89ec000b3685ee0581379a85f28f"
        project["groupID"] = "511df3ee000a3646cf87f7f192fde769"
        project["scheduleID"] = "50f558520003e0c8c8d1290e0d051571"

        project[CGI.escape("DE:Project Type")] = "Maintenance"

        project[CGI.escape("DE:Salesforce ID")] = sfdc_object[:Id].first
        project["status"] = "MNT"

        project["condition"] = "ON"
        project["conditionType"] = "MN"

        project[CGI.escape("DE:Practice Group")] = "Europe"
        project[CGI.escape("DE:Operational Status")] = row["Status"]
        project[CGI.escape("DE:Project PID")] = row["Project pid"]
        project[CGI.escape("DE:Confluence")] = row["Confluence"]
        project[CGI.escape("DE:Solution Architect")] = row["CS Person"]
        project[CGI.escape("DE:Solution Engineer")] = row["MS Person"]
        project[CGI.escape("DE:Automatic validation")] = row["Automatic validation"]
        project[CGI.escape("DE:CRON")]=row["CRON"]
        project[CGI.escape("DE:Average Duration")] = row["Duration"]
        project[CGI.escape("DE:Tier")] = row["Tier"]
        project[CGI.escape("DE:Working Hours")] = row["Working Hours"]
        project[CGI.escape("DE:Time Zone")] = row["TZ"]
        project[CGI.escape("DE:Restart")] = row["Restart"]
        project[CGI.escape("DE:Tech. user")] = row["Tech. user"]

        if (row["Uses FTP?"] == "No" || row["Uses FTP?"] == "") then
          project[CGI.escape("DE:Uses FTP")] = "No"
        else
          project[CGI.escape("DE:Uses FTP")] = "Yes"
        end

        project[CGI.escape("DE:File ex. check")] = row["File existence check?"]
        project[CGI.escape("DE:Archiver")] = row["Archiver"]
        project[CGI.escape("DE:SF Downloader Version")] = row["SF Downloader version"]
        project[CGI.escape("DE:Infrastructure")] = row["Infrastructure"]


        case
          when row["Infrastructure"] == "run,es gen" then project[CGI.escape("DE:Infrastructure")] = "run_es_gen"
          when row["Infrastructure"] == "CloudConnect" || row["Infrastructure"] == "cc" then project[CGI.escape("DE:Infrastructure")] = "CloudConnect"
          when row["Infrastructure"] == "run" then project[CGI.escape("DE:Infrastructure")] = "run"
          when row["Infrastructure"] == "infra" || row["Infrastructure"] == "Infra" then project[CGI.escape("DE:Infrastructure")] = "infra"
        end

        project[CGI.escape("DE:Running on")] = row["Running on"]
        project[CGI.escape("DE:Directory name")] = row["Directory name"]


        attask.project.add(project)
        @work_done = true
        end
    end


    #pp google.output

    #attask = Attask.client("gooddata",at_username,at_password)

    #project = Attask::Project.new()
    #project.ID =  "511cacee0002e569b972734795337efc"
    #attask.project.exec_function(project,"calculateFinance")


  end
end



desc 'Import jira'
command :jira do |c|
#  c.desc 'Execute only for one entity.'
#  c.default_value false
#  c.flag [:o, :only]

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|

    at_username = options[:at_username]
    at_password = options[:at_password]

    attask = Attask.client("gooddata",at_username,at_password)

    projects = attask.project.search({:fields => "name,DE:Legacy ID",:customFields => ""})

    arr_of_arrs = FasterCSV.read("/home/adrian.toman/import/projects.csv",{:headers=>true})

    count = 0


    projects = projects.find_all{|p| p["DE:Legacy ID"] != nil}

    arr_of_arrs.each do |row|

      value = projects.find {|p| p["DE:Legacy ID"].strip.casecmp(row["Key"].strip) == 0}


      pp row if value == nil
      #puts "nasel" if value != nil
      #puts "nenasel" if value == nil


      end

    end

end


desc 'Check and fix billable hours'
command :billable_check do |c|

  c.desc 'Username to SF account'
  c.flag [:sf_username]

  c.desc 'Password + token to SF account'
  c.flag [:sf_password]

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|
    sf_username = options[:sf_username]
    sf_password = options[:sf_password]
    at_username = options[:at_username]
    at_password = options[:at_password]

    attask = Attask.client("gooddata",at_username,at_password)


    @user = {
        "West" => "gautam.kher@gooddata.com",
        "Partner" => "gautam.kher@gooddata.com",
        "East" => "matt.maudlin@gooddata.com",
        "Europe" => "martin.hapl@gooddata.com"
    }


    projects = attask.project.search({:fields => "ID,name,DE:Salesforce ID",:customFields => ""})
    users = attask.user.search()
    companies = attask.company.search(({:fields => "ID,name"}))

    salesforce = Synchronizer::SalesForce.new(sf_username,sf_password)
    salesforce.query("SELECT Amount, Id, Type,x1st_year_services_total__c,ps_hours__c, Services_Type__c, Services_Type_Subcategory__c, Practice_Group__c,StageName, Name,AccountId FROM Opportunity",{:values => [:Id,:Amount,:x1st_year_services_total__c,:ps_hours__c,:Services_Type__c,:Services_Type_Subcategory__c,:Practice_Group__c,:Type,:StageName,:Name,:AccountId],:as_hash => true})


    account = Synchronizer::SalesForce.new(sf_username,sf_password)
    account.query("SELECT Id, Name FROM Account",{:values => [:Id,:Name],:as_hash => true})

    projects = projects.find_all{|p| p["DE:Salesforce ID"] != "N/A" and p["DE:Salesforce ID"] != nil }

    # This section will create warn messages, when there is incorectly set opportunity in SFDC
    salesforce.filter("6 - CLOSED WON")
    salesforce.notAlreadyCreated(projects)

    salesforce.output.each do |s|

      project = Attask::Project.new()
      project.name =  s[:Name].match(/^[^->]*/)[0].strip
      project.status = "IDA"


      accountName = account.output.find{|a| a[:Id].first == s[:AccountId]}[:Name]

      company = companies.find{|c| c.name.casecmp(accountName) == 0 ? true : false}
      if (company == nil) then
        company = Attask::Company.new
        company["name"] = accountName
        @log.info "Creating company #{company["name"]}"
        company = attask.company.add(company).first
      end

      user = nil
      if (s[:Practice_Group__c] != nil)
        email = @user[s[:Practice_Group__c]]
        user = users.find{|u| u.emailAddr == email}
      end

      project.ownerID = user.ID if user != nil
      project["companyID"] =  company.ID
      project["categoryID"] = "50f5a7ee000d0278de51cc3a4d803e62"
      project["groupID"] = "50f49e85000893b820341d23978dd05b"
      project["scheduleID"] = "50f558520003e0c8c8d1290e0d051571"
      project["milestonePathID"] = "50f5e5be001a53c6b9027b25d7b00854"
      project["ownerPrivileges"] = "APT"
      project["URL"] = "https://na6.salesforce.com/#{s[:Id].first}" if s[:Id].first != nil

      #project["templateID"] = # ?

      project[CGI.escape("DE:Salesforce ID")] = s[:Id].first
      project[CGI.escape("DE:Project Type")] = s[:Type]

      @log.info "Creating project #{project.name} with SFDC ID #{s[:Id].first}"

      attask.project.add(project)
      @work_done = true
    end





  end
end



desc 'Add new projects to SF'
command :update_ps_hours do |c|

  c.desc 'Username to SF account'
  c.flag [:sf_username]

  c.desc 'Password + token to SF account'
  c.flag [:sf_password]

  c.desc 'Username to Attask'

  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|
    sf_username = options[:sf_username]
    sf_password = options[:sf_password]
    at_username = options[:at_username]
    at_password = options[:at_password]

    attask = Attask.client("gooddata",at_username,at_password)
    #attask = Attask.client("gooddata",at_username,at_password,{:sandbox => true})

    projects = attask.project.search({:fields => "ID,name,categoryID",:customFields => "DE:Total Service Hours,DE:Budget Hours"})


    #hours = []
    #csv = CSV.open("/home/adrian.toman/import/hours.csv",'r', :headers => true)

    #csv.each do |row|
    #  temp = [row[0].split(",")[0],row[0].split(",")[1],row[0].split(",")[2]]
    #  hours << temp
    #end

    #FasterCSV.foreach("/home/adrian.toman/import/hours2.csv", :quote_char => '"',:col_sep =>',', :headers => true) do |row|
    #  pp row

    #  hours << row if row !=nil
    #end

    projects.each do |project|
      if (project["categoryID"] == "50f5a7ee000d0278de51cc3a4d803e62") then
         if project["DE:Budget Hours"] != nil
            value_hours = Float(project["DE:Budget Hours"])
         else
            value_hours = 0
         end

         if (!project["DE:Total Service Hours"].nil?)
           budget_hours = Float(project["DE:Total Service Hours"])
         else
           budget_hours = 0
         end

         project[CGI.escape("DE:Legacy Budget Hours")] =  budget_hours - value_hours
         project.delete("DE:Total Service Hours")
         project.delete("DE:Budget Hours")
         puts "Project ID - #{project.ID} I have found hours and I am setting #{budget_hours - value_hours}"
         attask.project.update(project)
      end

    end

  end
end

desc 'Add new projects to SF'
command :move do |c|

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|

    at_username = options[:at_username]
    at_password = options[:at_password]

    attask = Attask.client("gooddata",at_username,at_password)

    projects = attask.project.search({:fields => "ID,name,DE:Project Type,DE:CRON,DE:Project PID,DE:Project Type,DE:Running on",:customFields => ""})

    pp projects.count

    projects = projects.find_all{|p| p["DE:Project Type"] == "Maintenance"}
    #projects = projects.find_all{|p| p["DE:Project PID"] == "n9fpmc1p4v1pjsd5p1jeb0j31cs767yg"}

    projects.each do |p|
      puts "Name: #{p.name} PID: #{p["DE:Project PID"]}} CRON:#{p["DE:CRON"]}"

      task = Attask::Task.new()
      task["categoryID"]= "5167fbd8000b3cd1c2d8f2e670c29f4a"
      task["groupID"] = "511df3ee000a3646cf87f7f192fde769"
      task["projectID"] = p["ID"]
      task["DE:Server"] = p["DE:Running on"]


      #pp p["DE:Running on"]


      attask.task.add(task)

      #pp task


    end

    #pp tasks
    #tasks = tasks.find_all {|t| t["categoryID"] == "5167fbd8000b3cd1c2d8f2e670c29f4a"}
    #pp tasks






  end
end



desc 'Add new projects to SF'
command :pagerduty do |c|

  c.desc 'Username to Attask'
  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]

  c.desc 'S3 access key'
  c.flag [:s3_access]

  s.desc 'S3 secret key'
  c.flag [:s3_secret]



  c.action do |global_options,options,args|

    at_username = options[:at_username]
    at_password = options[:at_password]
    s3_access = options[:s3_access]
    s3_secret = options[:s3_secret]

    #attask = Attask.client("gooddata",at_username,at_password,{:sandbox => true})
    attask = Attask.client("gooddata",at_username,at_password)
    begin
      s3 = Synchronizer::S3.new(s3_access,s3_secret,"gooddata_com_attask",@log)

      s3.download_file("pd_timesheet.csv")
      s3.delete_file("pd_timesheet.csv")

      pd_timesheets = FasterCSV.read("data/pd_timesheet.csv",{:headers=>true})

      pd_timesheets.each do |row|
            hour = Attask::Hour.new()
            hour["entryDate"] = row["entrydate"]
            hour["hours"] = row["duration"]
            hour["hourTypeID"] = row["hourtypeid"]
            hour["taskID"] = row["taskid"]
            hour["timesheetID"] = row["timesheetid"]
            hour["ownerID"] = row["ownerid"]
            hour["roleID"] = row["roleid"]
            attask.hour.add(hour)
            @log.info "Created entry(Date: #{row["entrydate"]}, Hours: #{row["duration"]} Timesheet: #{hour["timesheetID"]})"
      end
      File.delete("data/pd_timesheet.csv")
    rescue
      @log.error "There was error in executing PD Migration: #{$!}"
      Pony.mail(:to => "adrian.toman@gooddata.com",:cc => "miloslav.zientek@gooddata.com",:from => 'attask@gooddata.com', :subject => "Attask Pagerduty - looks like that file was not exported on S3 ", :body => "Please check PD synchronization log", :attachments => {"pagerduty.log" => File.read("log/migration_pagerduty.log")} )
    end


  end
end






desc 'Add new projects to SF'
command :update_planed_date do |c|
  c.desc 'Username to Attask'

  c.flag [:at_username]

  c.desc 'Password to Attask'
  c.flag [:at_password]


  c.action do |global_options,options,args|

    at_username = options[:at_username]
    at_password = options[:at_password]

    #attask = Attask.client("gooddata",at_username,at_password,{:sandbox => true})
    attask = Attask.client("gooddata",at_username,at_password)

    projects = attask.project.search({:fields => "ID,name,ownerID",:customFields => ""})
    projects.each do |project|
        pp project.ownerID
        pp project.ID
         if (project.ownerID.nil?)
           puts "Updatuju #{project.ID}"
           project["ownerID"] = "50e6f9f4001bcc70028ae8a52ae94033"
           attask.project.update(project)
         end
    end
  end
end




desc 'Attask to SF synchronization'

command :attask_to_salesforce do |c|
  c.desc 'Username to SF account'
  c.flag [:sf_config_file]
  c.desc 'Username to Attask'

  c.action do |global_options,options,args|
    require "databasedotcom"

    sf_config_file = options[:sf_config_file]

    yaml = YAML.load_file(sf_config_file)

    at_username = options["attask_login"]
    at_password = options["attask_password"]
    sf_username = yaml["username"]
    sf_password = yaml["password"] + yaml["token"]

    #attask = Attask.client("gooddata",at_username,at_password,{:sandbox => true})
    attask = Attask.client("gooddata",at_username,at_password)
    projects = attask.project.search({:fields => "ID,group:name,owner:name,name,status,percentComplete",:customFields => "DE:Salesforce ID,DE:Status Update Overview,DE:Action Plan,DE:External Org Dependencies,DE:Condition Indicator,DE:Budget Hours"})


    salesforce = Synchronizer::SalesForce.new(sf_username,sf_password)
    salesforce.query("SELECT Id,Project_Owner__c,Project_Group__c,Project_Stage__c,Status_Update__c,Services_Complete__c,Implementation_Status__c,Action_Plan__c,External_Org_Dependencies__c,AccountId,Name FROM Opportunity",{:values => [:Id,:Project_Owner__c,:Project_Group__c,:Project_Stage__c,:Status_Update__c,:Services_Complete__c,:Implementation_Status__c,:Action_Plan__c,:External_Org_Dependencies__c,:AccountId,:Name],:as_hash => true})
    opportunities = salesforce.output

    account = Synchronizer::SalesForce.new(sf_username,sf_password)
    account.query("SELECT Id, Name, OwnerId FROM Account",{:values => [:Id,:Name,:OwnerId],:as_hash => true})
    accounts = account.output

    user = Synchronizer::SalesForce.new(sf_username,sf_password)
    user.query("SELECT Id, Email,Name FROM User",{:values => [:Id,:Email,:Name],:as_hash => true})
    users = user.output

    client = Databasedotcom::Client.new(sf_config_file)
    client.authenticate :username => sf_username, :password => sf_password
    client.materialize("Opportunity")

    status_values = {}
    attask.project.metadata["data"]["fields"]["status"]["possibleValues"].each do |s|
      status_values[s["value"]] = s["label"]
    end

    opportunities.each do |op_value|
      projects_with_given_opportunity = projects.find_all{|p| p["DE:Salesforce ID"] == op_value[:Id]}
      project = nil
      #There can be multiple projects with given opportunity. If there are more then one we will take the open one and with biggest bugget
      if (projects_with_given_opportunity.count == 1)
        project = projects_with_given_opportunity.first
      elsif (projects_with_given_opportunity.count > 1)
        project = nil
        projects_with_given_opportunity = projects_with_given_opportunity.find_all{|p| p.status != "CPL" and p.status != "DED"}
        budget_hours = 0
        projects_with_given_opportunity.each do |p|
          if !p["DE:Budget Hours"].nil? and budget_hours < p["DE:Budget Hours"]
            budget_hours = p["DE:Budget Hours"]
            project = p
          end
        end
      end

      now = Date.today

      if (!project.nil?)
        helper = Synchronizer::Helper.new(op_value[:Id],op_value[:Name],"Opportunity")

        # if ((op_value[:Project_Stage__c] == "New" or op_value[:Project_Stage__c].nil?) and (project.status == "PLN" or project.status == "CUR" ))
        #   # Per https://confluence.intgdc.com/pages/viewpage.action?pageId=145326495 we need to send email to Account Owner
        #   value = accounts.find{|a| a[:Id] == op_value[:AccountId]}
        #   user = users.find{|u| u[:Id] == value[:OwnerId]}
        #   if (!user.nil?)
        #     text = "Dear #{user[:Name]},\n\nServices completed staffing of project #{project["name"]} (https://attask-ondemand.com/project/view?ID=#{project.ID}) related to opportunity #{op_value[:Name]} (https://na6.salesforce.com/#{op_value[:Id]}).\n\nThe owner is: #{project.owner.name}\n\nPlease contact the owner directly for kickoff planning.\n\nBest regards,\nServices Staffing Team"
        #     #Pony.mail(:to => user[:Email],:from => 'attask@gooddata.com', :subject => "Attask => Salesforce Synchronization", :body => text)
        #     Pony.mail(:to => user[:Email],:from => 'attask@gooddata.com', :subject => "Attask => Salesforce Synchronization", :body => text)
        #     fail "kokos"
        #   end
        # end



        values = {}
        values["Project_Owner__c"] = project.owner.name unless helper.comparerString(op_value[:Project_Owner__c],project.owner.name,"Owner")
        values["Project_Group__c"] = project.group.name unless helper.comparerString(op_value[:Project_Group__c],project.group.name,"Group")
        values["Project_Stage__c"] = status_values[project.status] unless helper.comparerString(op_value[:Project_Stage__c],status_values[project.status],"Status")

        sf_status_update = op_value[:Status_Update__c].nil? ? "" : op_value[:Status_Update__c].gsub(/[^[:print:]]/,"")
        at_status_update = project["DE:Status Update Overview"].nil? ? "" : project["DE:Status Update Overview"].gsub(/[^[:print:]]/,"")
        values["Status_Update__c"] = project["DE:Status Update Overview"].nil? ? "" : project["DE:Status Update Overview"] unless helper.comparerString(sf_status_update,at_status_update,"Status Update")

        if (now.wday == 1)
          values["Services_Complete__c"] = project["percentComplete"] unless helper.comparerString(op_value[:Services_Complete__c],project["percentComplete"],"Services Complete")
        end
        values["Implementation_Status__c"] = project["DE:Condition Indicator"] unless helper.comparerString(op_value[:Implementation_Status__c],project["DE:Condition Indicator"],"Implementation Status")
        values["Action_Plan__c"] = project["DE:Action Plan"] unless helper.comparerString(op_value[:Action_Plan__c],project["DE:Action Plan"],"Action Plan")
        values["External_Org_Dependencies__c"] = project["DE:External Org Dependencies"] unless helper.comparerString(op_value[:External_Org_Dependencies__c],project["DE:External Org Dependencies"],"Action Plan")
        begin
          client.update("Opportunity",op_value[:Id],values) if helper.changed
          helper.printLog(@log) if helper.changed
          @work_done = true if helper.changed
        rescue => e
          @log.error "There was error when updating opportunity #{op_value[:Id]}. Message: #{e.message}"
        end
      end
    end
  end
end







pre do |global,command,options,args|
  next true if command.nil?

  if (ENV["USERNAME"] != "adrian.toman")
    @log = Logger.new("log/migration_#{command.name}.log",'daily')
  else
    @log = Logger.new(STDOUT,'daily')
  end
  @work_done = false


  # Pre logic here
  # Return true to proceed; false t/root/RubymineProjects/Synchronizero abourt and not call the
  # chosen command
  # Use skips_pre before a command to skip this block
  # on that command only
  true
end

post do |global,command,options,args|
  #@log.close
  Pony.mail(:to => "martin.hapl@gooddata.com",:cc => "adrian.toman@gooddata.com,jiri.stovicek@gooddata.com",:from => 'attask@gooddata.com', :subject => "Attask Synchronization - Some work was done in #{command.name}", :body => "File in attachements", :attachments => {"migration_#{command.name}.log" => File.read("log/migration_#{command.name}.log")}) if (@work_done)
  # Post logic here
  # Use skips_post before a command to skip this       id
  # block on that command only
end

on_error do |exception|
  @log.error exception
  @log.error exception.backtrace
  #pp exception
  #pp exception.backtrace
  #@log.close
  #Pony.mail(:to => "clover@gooddata.pagerduty.com",:cc => "adrian.toman@gooddata.com", :from => 'adrian.toman@gooddata.com', :subject => "Error in SF => Attask synchronization", :body => exception.to_s) if ENV["USERNAME"] != "adrian.toman"

  #pp exception.backtrace
  #if exception.is_a?(SystemExit) && exception.status == 0
  #  false
  #else
  #  pp exception.inspect
  #
  #  false
  #end
end


def createHash(collection)
  temp = Hash.new
  collection["fields"].each_pair do |key,value|
    if (key != "password" and key != "auditUserIDs" and key != "auditNote") then
      fail "Unknown field fieldType" if value["fieldType"] == nil

      temp[key] = {"name" => key,"type" => value["fieldType"]}
    else
      puts key
    end
  end
  if collection["custom"] != nil then
    collection["custom"].each_pair do |key,value|
      fail "Unknown field type" if value["type"] == nil
      temp["DE:"+ key] = {"name" => "DE:" + key,"type" => value["type"]}
    end
  end
  temp
end


def createEmail(name)
  return "" if name == nil
  temp = name.downcase.split(" ");
  return "#{temp[0]}.#{temp[1]}@gooddata.com"
end

def escape(str)
  ActiveSupport::Multibyte::Chars.new(str).normalize(:d).split(//u).reject { |e| e.length > 1 }.join
end


exit GLI.run(ARGV)
