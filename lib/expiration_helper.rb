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

      def expire_hours(number_of_hours,expiration_period,group_key,options = {})
        attask_client = options['attask']
        project_id = options['project_id']
        task_id = options['task_id']
        billable_id = options['billable_id']
        date = last_bussines_date_in_interval(expiration_period,group_key)

        hour = Attask::Hour.new()
        hour['ownerID'] = EXPIRATION_USER
        hour['hours'] = number_of_hours
        hour['entryDate'] = date.strftime('%Y-%m-%d')
        hour['taskID'] = task_id
        hour['hourTypeID'] = billable_id
        attask_client.hour.add(hour)
      end

      def last_bussines_date_in_interval(period,key)
        case period
          when 'Year'
            Time.parse("#{key}-12-31")
          when 'Month'
            (Time.parse("#{key}-01") + 1.month) - 1.day
          when 'Quarter'
            year = key.split("-")[0]
            quarter = Integer(key.split("-")[1])
            (Time.parse("#{year}-#{(quarter - 1) * 3 + 1}-01")) + 3.month - 1.day
        end
      end


    end

  end
end