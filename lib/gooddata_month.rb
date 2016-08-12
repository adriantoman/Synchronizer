module Synchronizer

  class GoodDataMonth

    attr_accessor :month,:year,:quarter

    MONTH_TO_QUARTER = {
        1 => 4,
        2 => 1,
        3 => 1,
        4 => 1,
        5 => 2,
        6 => 2,
        7 => 2,
        8 => 3,
        9 => 3,
        10 => 3,
        11 => 4,
        12 => 4
    }


    def initialize(date,grain)
      @month = date.month
      if (grain == 'Quarter' and @month == 1)
        @year = date.year - 1
      else
        @year = date.year
      end
      @quarter = MONTH_TO_QUARTER[date.month]
      @grain = grain
    end


    def numeric_key
      Integer(@year)*12 + Integer(@month)
    end

    def key
      case @grain
        when 'Year'
          @year.to_s
        when 'Month'
          "#{@year}-#{@month}"
        when 'Quarter'
          "#{@year}-#{@quarter}"
      end
    end

    def last_day_in_interval
      case @grain
        when 'Year'
          Time.parse("#{@year}-12-31")
        when 'Month'
          (Time.parse("#{@year}-#{@month}-01") + 1.month) - 1.day
        when 'Quarter'
          case @quarter
            when 1
              Time.parse("#{@year}-04-30")
            when 2
              Time.parse("#{@year}-07-31")
            when 3
              Time.parse("#{@year}-10-31")
            when 4
              Time.parse("#{@year+1}-01-31")
          end
      end
    end




  end
end
