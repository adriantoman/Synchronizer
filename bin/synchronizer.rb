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
require 'cgi'
require 'active_support/all'
require 'logger'
require "pony"
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

    pp attask.project.search





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
    projects = attask.project.search({:fields => "ID,name,companyID,groupID,status,condition,conditionType,budget",:customFields => "DE:Salesforce ID,DE:Project Type,DE:Practice Group,DE:Services Type,DE:Service Type Subcategory"})


    salesforce = Synchronizer::SalesForce.new( sf_username,sf_password)

    salesforce.query("SELECT Amount, Id, Type,x1st_year_services_total__c,ps_hours__c, Services_Type__c, Services_Type_Subcategory__c, Practice_Group__c FROM Opportunity",{:values => [:Id,:Amount,:x1st_year_services_total__c,:ps_hours__c,:Services_Type__c,:Services_Type_Subcategory__c,:Practice_Group__c,:Type],:as_hash => true})

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
          project["groupID"] = "50f731ae002a695ba0f5eb3fe47f34ff" unless helper.comparerString(project["groupID"],"50f731ae002a695ba0f5eb3fe47f34ff","groupID")

        else
          # UPDATE CONDITIONS -> Every time

          if (project["DE:Project Type"] != "Maintenance" and project["DE:Project Type"] != "Migration" and project["DE:Project Type"] != "Customer Success" ) then
            project[CGI.escape("DE:Project Type")] = sfdc_object[:Type] unless helper.comparerString(project["DE:Project Type"],sfdc_object[:Type],"Project Type")
            project[CGI.escape("DE:Practice Group")] = sfdc_object[:Practice_Group__c] unless helper.comparerString(project["DE:Practice Group"],sfdc_object[:Practice_Group__c],"Practice Group")
          end

          project[CGI.escape("DE:Services Type")] = sfdc_object[:Services_Type__c] unless helper.comparerString(project["DE:Services Type"],sfdc_object[:Services_Type__c],"Services Type")
          project[CGI.escape("DE:Service Type Subcategory")] = sfdc_object[:Services_Type_Subcategory__c] unless helper.comparerString(project["DE:Service Type Subcategory"],sfdc_object[:Services_Type_Subcategory__c],"Service Type Subcategory")

          # STATUS == Awaiting Sign-off then Condition Type = Manual and Status = On Target
          if (project["status"] == "ASO") then
            project["condition"] = "ON" unless helper.comparerString(project["condition"],"ON","condition") # On-Target
            project["conditionType"] = "MN" unless helper.comparerString(project["conditionType"],"MN","conditionType") # Manual
          end
        end

        # Update budget if there is only one project with specific SFDC_ID
        duplicated_sfdc = projects.find_all{|p| p["DE:Salesforce ID"] != nil and project["DE:Salesforce ID"] != nil and p["DE:Salesforce ID"].casecmp(project["DE:Salesforce ID"]) == 0 ? true : false}

        # To fix problem with escaping
        # All the values are present if needed, but with URL escaping
        project.delete("DE:Salesforce ID")
        project.delete("DE:Project Type")
        project.delete("DE:Services Type")
        project.delete("DE:Practice Group")
        project.delete("DE:Service Type Subcategory")

        if duplicated_sfdc.count == 1 and sfdc_object[:X1st_year_Services_Total__c] != nil then
          project.budget = sfdc_object[:X1st_year_Services_Total__c] unless helper.comparerFloat(project.budget,sfdc_object[:X1st_year_Services_Total__c],"budget")

        end

        attask.project.update(project) if helper.changed
        helper.printLog(@log) if helper.changed
        @work_done = true if helper.changed


        if (sfdc_object[:X1st_year_Services_Total__c] != nil and Float(sfdc_object[:X1st_year_Services_Total__c]) != 0 and sfdc_object[:PS_Hours__c] != nil and  Float(sfdc_object[:PS_Hours__c]) != 0) then
          budget = Float(sfdc_object[:X1st_year_Services_Total__c])
          hours = Float(sfdc_object[:PS_Hours__c])
          rateValue = budget / hours if hours > 0

          rates = attask.rate.search({},{:projectID => project.ID})

          @mapping.each_pair do |k,v|
            #Check if rate is in system
            recalculate = false


            rate = rates.find{|r| r.roleID == v}
            if (rate != nil)
              oldValue = Float(rate.rateValue)
              oldValue = oldValue.round(2)
              newValue =   Float(rateValue)
              newValue = newValue.round(2)
              if oldValue !=  newValue
                  rate.rateValue = newValue
                  @log.info "We are updating rate from #{oldValue} to #{newValue} (#{rate.roleID}) for project #{project["ID"]}"
                  attask.rate.update(rate)
                  recalculate = true
              end
            else
               rate = Attask::Rate.new()
               rate["projectID"] = project.ID
               rate["roleID"] = v
               rate["rateValue"] = rateValue.round(2)
               @log.info "We are adding rate #{rateValue.round(2)} (#{v}) for project #{project["ID"]}"
               attask.rate.add(rate)
            end
            attask.project.exec_function(project,"calculateFinance") if recalculate == true
            @work_done = true if recalculate == true

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


  c.action do |global_options,options,args|

    at_username = options[:at_username]
    at_password = options[:at_password]
    export = options[:export]

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
    ##attask.rate.exportToCsv({:filename => "rate.csv",:filepath => "/home/adrian.toman/export/"})
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

      #project["templateID"] = # ?

      project[CGI.escape("DE:Salesforce ID")] = s[:Id].first
      project[CGI.escape("DE:Project Type")] = s[:Type]

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
  @log.close
  Pony.mail(:to => "martin.hapl@gooddata.com",:cc => "adrian.toman@gooddata.com",:from => 'adrian.toman@gooddata.com', :subject => "Attask Synchronization - Some work was done in #{command.name}", :body => exception, :attachments => {"migration_#{command.name}.log" => File.read("log/migration_#{command.name}.log")}) if (@work_done)
  # Post logic here
  # Use skips_post before a command to skip this       id
  # block on that command only
end

on_error do |exception|
  @log.error exception
  @log.error exception.backtrace
  @log.close
  Pony.mail(:to => "clover@gooddata.pagerduty.com",:cc => "adrian.toman@gooddata.com", :from => 'adrian.toman@gooddata.com', :subject => "Error in SF => Attask synchronization", :body => exception.to_s)

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
      temp[key] = {"name" => key,"type" => value["type"]}
    else
      puts key
    end
  end
  if collection["custom"] != nil then
    collection["custom"].each_pair do |key,value|
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
