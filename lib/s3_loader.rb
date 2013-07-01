require 'aws/s3'

module Synchronizer

  class S3


    def initialize(access_key, secret_key, bucket,logger)
      @access_key = access_key
      @secrect_key = secret_key
      @bucket = bucket
      @logger = logger
    end


   def store_to_s3(directory)
     AWS::S3::Base.establish_connection!(
         :access_key_id     => @access_key,
         :secret_access_key => @secrect_key
     )
     bucket = AWS::S3::Bucket.find(@bucket)
     begin
      Dir.new(directory).each do |f|
         if (f != ".." and f!=".") then
           file_path = directory + f
           AWS::S3::S3Object.store(f, open(file_path), bucket.name)
         end
       end
     rescue Exception => e
       @logger.warn(e)
       @logger.warn("Backup to S3 failed")
     end

   end


    def download_file(name)
      AWS::S3::Base.establish_connection!(
          :access_key_id     => @access_key,
          :secret_access_key => @secrect_key
      )

      AttaskBucket = Bucket.find("gooddata_com_attask")

      file = AttaskBucket.find(name)
      File.open("data/pd_timesheet.csv", "w") do |f|
        f.write(file.value)
      end
    end

    def delete_file(name)
      AWS::S3::Base.establish_connection!(
          :access_key_id     => @access_key,
          :secret_access_key => @secrect_key
      )
      file = AttaskBucket.find(name)
      file.delete
    end




  end

  #class AttaskBucket < AWS::S3::S3Object
  #  set_current_bucket_to 'gooddata_com_attask'
  #end


end