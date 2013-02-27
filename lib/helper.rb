module Synchronizer

  class Helper


    attr_accessor :changed

    def initialize(id,name,entity)
      @changed = false
      @id = id
      @name = name
      @entity = entity
      @change_log = Hash.new
    end


    def comparerString(valueOne,valueTwo,log = nil)
      if ((valueOne.to_s.casecmp(valueTwo.to_s) != 0) and valueTwo != nil and valueTwo != "") then
        @changed = true
        @change_log[log] = "Key #{log} was changed from #{valueOne} to #{valueTwo}"
        false
      else
        true
      end
    end

    def comparerFloat(valueOne,valueTwo, log = nil)
      if Float(valueOne) != Float(valueTwo)
        @changed = true
        @change_log[log] = "Key #{log} was changed from #{valueOne} to #{valueTwo}"
        false
      else
        true
      end
    end


    def printLog(log)
      log.info "------------------------------------------"
      log.info "We have changed #{@entity} #{@name} (#{@id})"
      @change_log.each_value do |v|
        log.info v
      end
      log.info "------------------------------------------"
    end


  end


end