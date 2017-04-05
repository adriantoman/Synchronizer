require "date"


module Synchronizer

  class ExpirationHelper

    class << self

      EXPIRATION_TASK_NAME = 'Expiration task'
      EXPIRATION_USER = '572c4d4600100276cfa4395a88956f0f'

      def create_expiration_task(project_id,options = {})
        attask_client = options['attask']

        task = attask_client.task.search({:fields => "ID,name"},{:name => EXPIRATION_TASK_NAME,:projectID => project_id})

        if (task.empty?)
          task = Attask::Task.new()
          task['projectID'] = project_id
          task['name'] = EXPIRATION_TASK_NAME
          task['assignedToID'] = EXPIRATION_USER
          new_task = attask_client.task.add(task)
          return new_task.first.ID
        else
          return task.first.ID
        end
      end

      def expire_hours(number_of_hours,expiration_period,gm,options = {})
        attask_client = options['attask']
        project_id = options['project_id']
        task_id = options['task_id']
        billable_id = options['billable_id']
        date =  gm.last_day_in_interval

        hour = Attask::Hour.new()
        hour['ownerID'] = EXPIRATION_USER
        hour['hours'] = number_of_hours
        hour['entryDate'] = date.strftime('%Y-%m-%d')
        hour['taskID'] = task_id
        hour['hourTypeID'] = billable_id
        attask_client.hour.add(hour)
      end

      def generate_default_running_total(start_date,hours_per_period,number_of_periods,expiration_period)
        running_total = {}
        #{entry_date.year}-#{((entry_date.month)-1)/3 + 1}
        gooddata_months = (Date.parse(start_date.to_s)..Date.today).map {|d|  d.day == 1 ? GoodDataMonth.new(d,expiration_period) : nil }
        gooddata_months.compact!

        grouped_gooddata_months = gooddata_months.group_by{|gm| gm.key}

        index = 1
        grouped_gooddata_months.each do |key,hours|
          running_total[key] = index * hours_per_period
          index += 1
        end
        running_total
      end

      # This method will remove errors in date definition (I hope!)
      def round_start_date(input)
        date = Time.parse(input)
        if (date.day > 15 and date.month < 12)
          Time.parse("#{date.year}-#{date.month+1}-1")
        elsif (date.day > 15 and date.month == 12)
          Time.parse("#{date.year+1}-1-1")
        else
          Time.parse("#{date.year}-#{date.month}-1")
        end
      end




    end

  end
end