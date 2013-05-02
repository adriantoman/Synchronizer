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
require "lib/synchronizer.rb"
require "lib/helper.rb"
require "lib/google_downloader.rb"
require "lib/s3_loader.rb"
require 'cgi'
require 'active_support/all'
require 'logger'
require "pony"
require "csv"
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


  c.action do |global_options,options,args|
    at_username = options[:at_username]
    at_password = options[:at_password]



    attask = Attask.client("gooddata",at_username,at_password)

    projects = attask.project.search({:fields=>"ID",:customFields =>"DE:Salesforce ID"})

    projects = projects.find_all{|p| p["DE:Salesforce ID"] != "N/A" and p["DE:Salesforce ID"] != nil}

    projects.each do |p|
      p["URL"] = "https://na6.salesforce.com/#{p["DE:Salesforce ID"]}"
      p.delete("DE:Salesforce ID")
      attask.project.update(p)
   end




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
        "Contractor" => "50f02f810002afbea77b8672f462c330"
    }

    attask = Attask.client("gooddata",at_username,at_password)

    #users = attask.user.search({:fields => "ID,name",:customFields => ""})
    projects = attask.project.search({:fields => "ID,companyID,groupID,status,condition,conditionType,budget,categoryID",:customFields => "DE:Salesforce ID,DE:Project Type,DE:Salesforce Type,DE:Practice Group,DE:Services Type,DE:Service Type Subcategory,DE:Salesforce Name"})

    puts "Attask loaded"


    salesforce = Synchronizer::SalesForce.new( sf_username,sf_password)

    salesforce.query("SELECT Amount, Id, Name, Type,x1st_year_services_total__c,ps_hours__c, Services_Type__c, Services_Type_Subcategory__c, Practice_Group__c FROM Opportunity",{:values => [:Id,:Amount,:Name,:x1st_year_services_total__c,:ps_hours__c,:Services_Type__c,:Services_Type_Subcategory__c,:Practice_Group__c,:Type],:as_hash => true})


    puts "SF loaded"

    count = 0

    projects = projects.find_all{|p| p["DE:Salesforce ID"] != "N/A" and p["DE:Salesforce ID"] != nil}

    projects.each do |project|

    helper = Synchronizer::Helper.new(project["ID"],project["name"],"project")
    sfdc_object = salesforce.getValueByField(:Id,project["DE:Salesforce ID"])

      if sfdc_object.first != nil then

        sfdc_object  = sfdc_object.first

        if (project["DE:Salesforce ID"].casecmp("0068000000gubcKAAQ") == 0) then
          if (project["DE:Project Type"] != "Maintenance" and project["DE:Project Type"] != "Migration" and project["DE:Project Type"] != "Customer Success" ) then
            project[CGI.escape("DE:Project Type")] = "Internal" unless helper.comparerString(project["DE:Project Type"],"Internal","Project Type")
            project[CGI.escape("DE:Practice Group")] = "Europe" unless helper.comparerString(project["DE:Practice Group"],"Europe","Practice Group")
          end

          project["companyID"] =  "50e6fa86001bd48395eb3772aaafe2c9" unless helper.comparerString(project["companyID"],"50e6fa86001bd48395eb3772aaafe2c9","companyID")
          #project["groupID"] = "50f731ae002a695ba0f5eb3fe47f34ff" unless helper.comparerString(project["groupID"],"50f731ae002a695ba0f5eb3fe47f34ff","groupID")

        else
          # UPDATE CONDITIONS -> Every time

          project[CGI.escape("DE:Salesforce Type")] = sfdc_object[:Type] unless helper.comparerString(project["DE:Salesforce Type"],sfdc_object[:Type],"Salesforce Type")
          project[CGI.escape("DE:Salesforce Name")] = sfdc_object[:Name] unless helper.comparerString(project["DE:Salesforce Name"],sfdc_object[:Name],"Salesforce Name")


          #project[CGI.escape("DE:Salesforce Name")] = sfdc_object[:Name] unless helper.comparerString(project["DE:Salesforce Name"],sfdc_object[:Name],"Salesforce Name") unless sfdc_object[:Name].include? "Redfin"

          if (project["DE:Project Type"] != "Maintenance" and project["DE:Project Type"] != "Migration" and project["DE:Project Type"] != "Customer Success" ) then
            project[CGI.escape("DE:Practice Group")] = sfdc_object[:Practice_Group__c] unless helper.comparerString(project["DE:Practice Group"],sfdc_object[:Practice_Group__c],"Practice Group")
          end

          if (project["categoryID"] == "50f5a7ee000d0278de51cc3a4d803e62") then
            project[CGI.escape("DE:Services Type")] = sfdc_object[:Services_Type__c] unless helper.comparerString(project["DE:Services Type"],sfdc_object[:Services_Type__c],"Services Type")
            project[CGI.escape("DE:Service Type Subcategory")] = sfdc_object[:Services_Type_Subcategory__c] unless helper.comparerString(project["DE:Service Type Subcategory"],sfdc_object[:Services_Type_Subcategory__c],"Service Type Subcategory")
          end

          # STATUS == Awaiting Sign-off then Condition Type = Manual and Status = On Target
          if (project["status"] == "ASO") then
            project["condition"] = "ON" unless helper.comparerString(project["condition"],"ON","condition") # On-Target
            project["conditionType"] = "MN" unless helper.comparerString(project["conditionType"],"MN","conditionType") # Manual
          end
        end


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
        project.delete("DE:Services Type")
        project.delete("DE:Practice Group")
        project.delete("DE:Service Type Subcategory")


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

    attask.project.exportToCsv({:filename => "project.csv",:filepath => export})
    attask.assigment.exportToCsv({:filename => "assigment.csv",:filepath => export})
    attask.baseline.exportToCsv({:filename => "baseline.csv",:filepath => export})
    attask.baselinetask.exportToCsv({:filename => "baselinetask.csv",:filepath => export})
    attask.category.exportToCsv({:filename => "category.csv",:filepath => export})
    attask.company.exportToCsv({:filename => "company.csv",:filepath => export})
    attask.expense.exportToCsv({:filename => "expense.csv",:filepath => export})
    attask.expensetype.exportToCsv({:filename => "expensetype.csv",:filepath => export})
    attask.group.exportToCsv({:filename => "group.csv",:filepath => export})
    attask.hour.exportToCsv({:filename => "hour.csv",:filepath => export})
    attask.hourtype.exportToCsv({:filename => "hourtype.csv",:filepath => export})
    attask.issue.exportToCsv({:filename => "issue.csv",:filepath => export})
    ###attask.rate.exportToCsv({:filename => "rate.csv",:filepath => "/home/adrian.toman/export/"})
    attask.resourcepool.exportToCsv({:filename => "resourcepool.csv",:filepath => export})
    attask.risk.exportToCsv({:filename => "risk.csv",:filepath => export})
    attask.risktype.exportToCsv({:filename => "risktype.csv",:filepath => export})
    attask.role.exportToCsv({:filename => "role.csv",:filepath => export})
    attask.schedule.exportToCsv({:filename => "schedule.csv",:filepath => export})
    attask.task.exportToCsv({:filename => "task.csv",:filepath => export})
    attask.team.exportToCsv({:filename => "team.csv",:filepath => export})
    attask.timesheet.exportToCsv({:filename => "timesheet.csv",:filepath => export})
    attask.user.exportToCsv({:filename => "user.csv",:filepath => export})
    attask.milestone.exportToCsv({:filename => "milestone.csv",:filepath => export})


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

    attask = Attask.client("gooddata",at_username,at_password)


    @user = {
        "West" => "gautam.kher@gooddata.com",
        "Partner" => "romeo.leon@gooddata.com",
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
    incorectly_filled = salesforce.filter_out_without_control("6 - CLOSED WON")
    incorectly_filled = salesforce.notAlreadyCreated_out(incorectly_filled,projects)

    @log.info "There are some oportunities with services but without PS hours" if incorectly_filled.count > 0
    incorectly_filled.each do |i|
      @log.info "--------------------------------"
      @log.info "SFDC name:#{i[:Name]} SFDC id:#{i[:Id].first}"
      @log.info "--------------------------------"
    end
    @work_done = true  if incorectly_filled.count > 0

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
      project[CGI.escape("DE:Budget Hours")] =  s[:PS_Hours__c]

      #project["templateID"] = # ?

      project[CGI.escape("DE:Salesforce ID")] = s[:Id].first
      project[CGI.escape("DE:Project Type")] = "Implementation"
      project[CGI.escape("DE:Salesforce Type")] = s[:Type]

      @log.info "Creating project #{project.name} with SFDC ID #{s[:Id].first}"

      attask.project.add(project)
      @work_done = true
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
        "Partner" => "romeo.leon@gooddata.com",
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

    projects = attask.project.search({:fields => "ID,name,DE:Salesforce ID,DE:Project Type",:customFields => ""})
    users = attask.user.search()
    companies = attask.company.search(({:fields => "ID,name"}))

    salesforce = Synchronizer::SalesForce.new(sf_username,sf_password)
    salesforce.query("SELECT Id,ps_hours__c FROM Opportunity",{:values => [:Id,:ps_hours__c],:as_hash => true})

    projects = projects.find_all{|p| p["DE:Salesforce ID"] != "N/A" and p["DE:Salesforce ID"] != nil }
    projects = projects.find_all{|p|  p["DE:Project Type"] == "Implementation" }

    hours = []


    csv = CSV.open("/home/adrian.toman/import/hours.csv",'r', :headers => true)

    csv.each do |row|
      temp = [row[0].split(",")[0],row[0].split(",")[1],row[0].split(",")[2]]
      hours << temp
    end

    #FasterCSV.foreach("/home/adrian.toman/import/hours2.csv", :quote_char => '"',:col_sep =>',', :headers => true) do |row|
    #  pp row

    #  hours << row if row !=nil
    #end

    projects.each do |project|
      element = hours.find{|value| value[0] == project["ID"]}


      sf_element = salesforce.output.find{|s| s[:Id].first == project["DE:Salesforce ID"]}
      if (!sf_element.nil? && !sf_element.empty?)

         if element != nil
            value_hours = Float(element[2])
         else
            value_hours = 0
         end
         value_ps_hours = Float(sf_element[:PS_Hours__c])

         project[CGI.escape("DE:Budget Hours")] =  value_ps_hours - value_hours
         project.delete("DE:Salesforce ID")
         project.delete("DE:Project Type")
         puts "I have found hours: #{value_hours} and in SFDC (#{sf_element[:Id].first}) is #{value_ps_hours} and I am setting #{value_ps_hours - value_hours}"
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

      case (p["DE:Running on"])
        when "clover-prod2":
          task["DE:Graph"]= "app"
          task["name"] = "Main graph"
        when "clover-prod3":
          task["DE:Graph"]= "app"
          task["name"] = "Main graph"
        when "clover-test2":
          task["DE:Graph"]= "app"
          task["name"] = "Main graph"
        when "clover-dev2":
          task["DE:Graph"]= "app"
          task["name"] = "Main graph"
        else
          task["DE:Graph"]= "CHANGE"
          task["name"] = "CHANGE"
      end
      task["DE:CRON"] = p["DE:CRON"]

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


    projects = attask.project.search({:fields => "ID,name,DE:Salesforce ID,DE:Project Type,DE:Legacy ID,DE:Legacy,status",:customFields => ""})

    salesforce = Synchronizer::SalesForce.new(sf_username,sf_password)
    salesforce.query("SELECT Id,Services_Kick_Off_Date__c,Services_Completion_Date__c FROM Opportunity",{:values => [:Id,:Services_Kick_Off_Date__c,:Services_Completion_Date__c],:as_hash => true})

    projects = projects.find_all{|p| p["DE:Salesforce ID"] != "N/A" and p["DE:Salesforce ID"] != nil }
    projects = projects.find_all{|p|  p["DE:Legacy"] == "Yes" and p["DE:Project Type"] == "Implementation"}

    projects.each do |project|

      sf_element = salesforce.output.find{|s| s[:Id].first == project["DE:Salesforce ID"]}
      if (!sf_element.nil? && !sf_element.empty?)

          if (sf_element[:Services_Kick_Off_Date__c] != nil) or (sf_element[:Services_Completion_Date__c] != nil) then
            project["plannedStartDate"] = sf_element[:Services_Kick_Off_Date__c]
            project["actualStartDate"] = sf_element[:Services_Kick_Off_Date__c]

            project.delete("DE:Salesforce ID")
            project.delete("DE:Project Type")
            project.delete("DE:Legacy ID")
            project.delete("DE:Legacy")
            attask.project.update(project)
            puts "The project #{sf_element[:Id].first} has been updated (Start Date) #{sf_element[:Services_Kick_Off_Date__c]}"

          else
            puts "The project #{sf_element[:Id].first} has not Services_Kick_Off_Date__c in SF"
          end

          if (project.status == "CPL") then
            if (sf_element[:Services_Completion_Date__c] != nil) then

              project["status"] = "CUR"
              attask.project.update(project)

              puts "The project set to Current #{project["ID"]}"

              task = Attask::Task.new()
              #task["categoryID"]= "5167fbd8000b3cd1c2d8f2e670c29f4a"
              #task["groupID"] = "511df3ee000a3646cf87f7f192fde769"
              task["projectID"] = project["ID"]
              task["name"] = "Completition of Legacy project"
              task["description"] = "Added to edit completition date in attask"
              #task["plannedStartDate"] = sf_element[:Services_Completion_Date__c]
              #task["plannedCompletionDate"] = sf_element[:Services_Completion_Date__c]
              task["actualStartDate"] = sf_element[:Services_Kick_Off_Date__c]
              task["actualCompletionDate"] = sf_element[:Services_Completion_Date__c]
              task["status"] = "CPL"
              puts "The project completition date is #{sf_element[:Services_Completion_Date__c]}"

              attask.task.add(task)

              project["status"] = "CPL"
              attask.project.update(project)

              puts "The project set to Completed #{project["ID"]}"

              #puts "The project #{sf_element[:Id].first} has been updated (Completion date) #{sf_element[:Services_Completion_Date__c]}"
              #project["projectedCompletionDate"] = sf_element[:Services_Completion_Date__c]
              #project["actualCompletionDate"] = sf_element[:Services_Completion_Date__c]
              #puts "The project #{sf_element[:Id].first} has been updated (Completion date) #{sf_element[:Services_Completion_Date__c]}"
              #attask.project.update(project)
            else
              puts "The project #{sf_element[:Id].first} has not Services_Completion_Date__c in SF"
            end
          end




      end
    end

  end
end




pre do |global,command,options,args|
  next true if command.nil?
  @log = Logger.new("log/migration_#{command.name}.log",'daily')
  @work_done = false


  # Pre logic here
  # Return true to proceed; false to abourt and not call the
  # chosen command
  # Use skips_pre before a command to skip this block
  # on that command only
  true
end

post do |global,command,options,args|
  #@log.close
  Pony.mail(:to => "martin.hapl@gooddata.com",:cc => "adrian.toman@gooddata.com",:from => 'attask@gooddata.com', :subject => "Attask Synchronization - Some work was done in #{command.name}", :body => "File in attachements", :attachments => {"migration_#{command.name}.log" => File.read("log/migration_#{command.name}.log")}) if (@work_done)
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
