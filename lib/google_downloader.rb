

module Synchronizer


  class GoogleDownloader


    attr_accessor :session, :spredsheet, :worksheet,:output


    def initialize(login,password,spredsheet,worksheet,fields)
      @session = GoogleDrive.login(login, password)
      @output = Array.new

      download_spredsheet_by_id(spredsheet)
      set_worksheet(worksheet)
      load_projects(fields)
    end


    def download_spredsheet_by_id(id)
      @spredsheet = session.spreadsheet_by_key(id)
    end

    def set_worksheet(index)
        @worksheet = @spredsheet.worksheets[index]
    end


    def load_projects(columns)
      for row in 2..@worksheet.num_rows
        row_hash = Hash.new
        columns.each do |col|
          column_number = get_column_id(col)
          row_hash[col] = @worksheet[row,column_number]
        end
        @output.push(row_hash)
      end
    end

    def get_column_id(name)
      for col in 1..@worksheet.num_cols
          if (@worksheet[1,col] == name) then
            return col
          end
      end
    end


  end

end