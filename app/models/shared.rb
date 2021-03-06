require 'visit'
require 'image_dataset'
require 'net/sftp'

class Shared  < ActionController::Base
  extend SharedHelper
  def self.adrc_sftp_username; adrc_sftp_user end
  def self.adrc_sftp_host_address; adrc_sftp_host end
  def self.adrc_sftp_password; adrc_sftp_pwd end
  
  def test_return( p_var)
    return "AAAAAAAAAAAAA"+p_var
  end
  
  def apply_cg_edits(p_tn)
    connection = ActiveRecord::Base.connection();
    if !p_tn.include?('cg_')  
        v_tn = "cg_"+p_tn.gsub(/\./,'_')  # made for the fs aseg, lh.aparc.arae, rh.aprac.area
     else
       v_tn = p_tn
    end
    @cg_tns = CgTn.where(" tn = '"+v_tn+"'")
    @cg_tn = nil
    @cg_tns.each do |tns|
      if !tns.id.blank?
         @cg_tn = CgTn.find(tns.id)
      end
    end

    @cns = []
    @key_cns = []
    @v_key = []
    @cns_type_dict ={}
    @cns_common_name_dict = {}
    @cg_data_dict = {}
    @cg_edit_data_dict = {}

    @cg_tn_cns =CgTnCn.where("cg_tn_id in (?)",@cg_tn.id)
    @cg_tn_cns.each do |cg_tn_cn|
        @cns.push(cg_tn_cn.cn)
        @cns_common_name_dict[cg_tn_cn.cn] = cg_tn_cn.common_name
        if cg_tn_cn.key_column_flag == "Y"
          @key_cns.push(cg_tn_cn.cn)
        end 
        if !cg_tn_cn.data_type.blank?
          @cns_type_dict[cg_tn_cn.cn] = cg_tn_cn.data_type
        end
    end
    # apply cg_edit to cg_data and refresh cg_edit , same as above, but no key array
    sql = "SELECT "+@cns.join(',') +",delete_key_flag FROM "+@cg_tn.tn+"_edit" 
    @edit_results = connection.execute(sql)         
    @edit_results.each do |r|
        v_key_array = []
        v_cnt  = 0
        v_key =""
        v_delete_data_row="N"
        r.each do |rc| # make and save cn-value| key
          if @key_cns.include?(@cns[v_cnt]) # key column
            v_key = v_key+@cns[v_cnt] +"^"+rc.to_s+"|"
            v_key_array.push( @cns[v_cnt] +"='"+rc.to_s+"'")
          end
          v_cnt = v_cnt + 1
        end  
        if !v_key.blank? and !@v_key.include?(v_key) 
            @v_key.push(v_key)
        end
        # update cg_data
        v_cnt = 0
        v_col_value_array = []
        r.each do |rc|
          if !@key_cns.include?(@cns[v_cnt])
            # might need to int, to date, etc from datatype
            if @cns[v_cnt].blank?
             # v_col_value_array.push(" delete_key_flag ='"+rc.to_s+"' ")
               if rc.to_s == "Y"
                v_delete_data_row="Y"
              end
            else
                if rc.to_s != "|"
                    v_col_value_array.push(@cns[v_cnt]+"='"+rc.to_s.gsub(/'/, "''")+"' ")
                end
            end
          end               
          v_cnt = v_cnt + 1
        end
        if v_delete_data_row=="N"
            if v_col_value_array.size > 0
              sql = "update "+@cg_tn.tn+" set "+v_col_value_array.join(',')+" where "+v_key_array.join(" and ")
               @results = connection.execute(sql)
             end
        else
            sql = "delete from "+@cg_tn.tn+" where "+v_key_array.join(" and ")
             @results = connection.execute(sql)
        end        
    end
    
    
  end
  
  def compare_file_header(p_standard_header,p_file_header)
    v_comment =""
    v_flag = "Y"
    if p_standard_header.gsub(/	/,"").gsub(/\n/,"") !=  p_file_header.gsub(/	/,"").gsub(/\n/,"")
      v_comment = "ERROR!!! file header  not match expected header \n"+p_standard_header+"\n"+p_file_header 
      v_flag = "N"              
    else
      v_comment =" header matches expected."
    end
    return v_flag, v_comment
  end
  
  def get_sp_id_from_subjectid_v(p_subjectid_v)
    v_subjectid_chop = p_subjectid_v.gsub(/_v/,"").delete("0-9")
    v_visit_number = 1
    if p_subjectid_v.include?('_v2')
          v_visit_number = 2
    elsif p_subjectid_v.include?('_v3')
          v_visit_number = 3
    elsif p_subjectid_v.include?('_v4')
          v_visit_number = 4
    elsif p_subjectid_v.include?('_v5')
          v_visit_number = 5
    end
    if v_visit_number > 1
      scan_procedures = ScanProcedure.where("subjectid_base ='"+v_subjectid_chop+"' and codename like '%visit"+v_visit_number.to_s+"'")
    else
      scan_procedures = ScanProcedure.where("subjectid_base ='"+v_subjectid_chop+"' and ( codename like '%visit"+v_visit_number.to_s+"' or codename not like '%visit%' )")
    end
    v_cnt = 0
    scan_procedures.each do |sp|
       v_cnt = v_cnt +1
    end
    if v_cnt > 1
      puts "MULTIPLE SP "+p_subjectid_v
    end
    
    scan_procedures.each do |sp|
      # puts sp.codename+"= codename"
      return sp.id
    end
    
    return nil
  end
  
 def move_present_to_old_new_to_present(p_tn, p_colum_list,p_conditions,p_comment)
   v_comment = p_comment
   connection = ActiveRecord::Base.connection();
   # check move cg_ to cg_old
    sql = "select count(*) from "+p_tn+"_old"
    results_old = connection.execute(sql)
    
    sql = "select count(*) from "+p_tn
    results = connection.execute(sql)
    v_old_cnt = results_old.first.to_s.to_i
    v_present_cnt = results.first.to_s.to_i
    v_old_minus_present =v_old_cnt-v_present_cnt
    v_present_minus_old = v_present_cnt-v_old_cnt
    if ( v_old_minus_present <= 0 or ( v_old_cnt > 0 and  (v_present_minus_old/v_old_cnt)>0.7     ) )
      sql =  "truncate table "+p_tn+"_old"
      results = connection.execute(sql)
      sql = "insert into "+p_tn+"_old select * from "+p_tn
      results = connection.execute(sql)
    else
      v_comment = "ERROR!!! The "+p_tn+"_old table has 30% more rows than the present "+p_tn+" \n Not truncating "+p_tn+"_old "+v_comment 
    end
    #  truncate cg_ and insert cg_new
    sql =  "truncate table "+p_tn+""
    results = connection.execute(sql)
    
    sql = "insert into "+p_tn+"("+p_colum_list+")
    select distinct "+p_colum_list+" from "+p_tn+"_new 
                                   where "+p_conditions
    results = connection.execute(sql)
   
   return v_comment
  end 
  

  def run_sftp
      v_username = Shared.adrc_sftp_username # get from shared helper
      v_passwrd = Shared.adrc_sftp_password   # get from shared helperwhich is not on github
      v_ip = Shared.adrc_sftp_host_address # get from shared helper
      v_source ="/Users/panda_admin/upload_adrc/test_upload.txt"
      v_target ="/coho2/home/wisconsin/test_upload.txt"
      Net::SFTP.start(v_ip, v_username, :password => v_passwrd) do |sftp|
           sftp.upload!(v_source, "test_upload.txt")
      end

      
      # need to run from scooby as panda_admin-- adrc expects the ip address
    
  end
  
  
  def run_adrc_upload  
     
    visit = Visit.find(3)  #  need to get base path without visit
    v_base_path = visit.get_base_path()
     @schedule = Schedule.where("name in ('adrc_upload')").first
      @schedulerun = Schedulerun.new
      @schedulerun.schedule_id = @schedule.id
      @schedulerun.comment ="starting adrc_upload"
      @schedulerun.save
      @schedulerun.start_time = @schedulerun.created_at
      @schedulerun.save
      v_comment = ""
      v_comment_warning =""
    connection = ActiveRecord::Base.connection();
    sql = "truncate table cg_adrc_upload_new"       
    results = connection.execute(sql)
    sql = "insert into cg_adrc_upload_new(subjectid,sent_flag,status_flag, enrollment_id, scan_procedure_id,status_comment,dir_list) select subjectid,sent_flag,status_flag, enrollment_id, scan_procedure_id,status_comment,dir_list from cg_adrc_upload "
    results = connection.execute(sql)
    # recruit new adrc scans ---   change 
    v_weeks_back = "2"
    sql = "select distinct enrollments.enumber from enrollments,enrollment_vgroup_memberships, vgroups  where enrollments.enumber like 'adrc%' 
              and vgroups.id = enrollment_vgroup_memberships.vgroup_id 
              and enrollment_vgroup_memberships.enrollment_id = enrollments.id
              and vgroups.vgroup_date < DATE_SUB(curdate(), INTERVAL "+v_weeks_back+" WEEK)             
              and enrollments.enumber NOT IN ( select subjectid from cg_adrc_upload_new)
              and vgroups.transfer_mri ='yes'"
    results = connection.execute(sql)
    results.each do |r|
          enrollment = Enrollment.where("enumber in (?)",r[0])
          sql2 = "insert into cg_adrc_upload_new (subjectid,sent_flag,status_flag, enrollment_id, scan_procedure_id) values('"+r[0]+"','N','Y', "+enrollment[0].id.to_s+",22)"
          results2 = connection.execute(sql2)
    end
    v_comment = self.move_present_to_old_new_to_present("cg_adrc_upload",
    "subjectid, general_comment, sent_flag, sent_comment, status_flag, status_comment, dir_list,enrollment_id, scan_procedure_id",
                   "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


    # apply edits  -- made into a function  in shared model
    self.apply_cg_edits('cg_adrc_upload')
    
    
    # get adrc subjectid to upload
    sql = "select distinct subjectid from cg_adrc_upload where sent_flag ='N' and status_flag in ('Y','R') "
    results = connection.execute(sql)
    # change series_description_map table
    v_folder_array = Array.new
    v_scan_desc_type_array = Array.new
    # check for dir in /tmp
    v_target_dir ="/tmp/adrc_upload"
    v_target_dir ="/Volumes/Macintosh_HD2/adrc_upload"
    if !File.directory?(v_target_dir)
      v_call = "mkdir "+v_target_dir
      stdin, stdout, stderr = Open3.popen3(v_call)
      while !stdout.eof?
        puts stdout.read 1024    
       end
      stdin.close
      stdout.close
      stderr.close
    end
    v_comment = " :list of subjectid "+v_comment
    results.each do |r|
      v_comment = r[0]+","+v_comment
    end
    @schedulerun.comment =v_comment[0..1990]
    @schedulerun.save
    results.each do |r|
      v_comment = "strt "+r[0]+","+v_comment
      @schedulerun.comment =v_comment[0..1990]
      @schedulerun.save
      # update schedulerun comment - prepend 
      sql_vgroup = "select DATE_FORMAT(max(v.vgroup_date),'%Y%m%d' ) from vgroups v where v.id in (select evm.vgroup_id from enrollment_vgroup_memberships evm, enrollments e where evm.enrollment_id = e.id and e.enumber ='"+r[0]+"')"
      results_vgroup = connection.execute(sql_vgroup)
      # mkdir /tmp/adrc_upload/[subjectid]_YYYYMMDD_wisc
      v_subject_dir = r[0]+"_"+(results_vgroup.first)[0].to_s+"_wisc"
      v_parent_dir_target =v_target_dir+"/"+v_subject_dir
      v_call = "mkdir "+v_parent_dir_target
      stdin, stdout, stderr = Open3.popen3(v_call)
      while !stdout.eof?
        puts stdout.read 1024    
       end
      stdin.close
      stdout.close
      stderr.close
      sql_dataset = "select distinct appointments.appointment_date, visits.id visit_id, image_datasets.id image_dataset_id, image_datasets.series_description, image_datasets.path, series_description_map.series_description_type 
                  from vgroups , appointments, visits, image_datasets, series_description_map 
                  where vgroups.transfer_mri = 'yes' and vgroups.id = appointments.vgroup_id 
                  and appointments.id = visits.appointment_id and visits.id = image_datasets.visit_id
                  and image_datasets.series_description =   series_description_map.series_description
                  and series_description_map.series_description_type in ('T1','T2','T2 Flair','DTI') 
                  and vgroups.id in (select evm.vgroup_id from enrollment_vgroup_memberships evm, enrollments e where evm.enrollment_id = e.id and e.enumber ='"+r[0]+"')
                   order by appointments.appointment_date "
      results_dataset = connection.execute(sql_dataset)
      v_folder_array = [] # how to empty
      v_scan_desc_type_array = []
      v_cnt = 1
      results_dataset.each do |r_dataset|
            v_series_description_type = r_dataset[5].gsub(" ","_")
            if !v_scan_desc_type_array.include?(v_series_description_type)
                 v_scan_desc_type_array.push(v_series_description_type)
            end
            v_path = r_dataset[4]
            v_dir_array = v_path.split("/")
            v_dir = v_dir_array[(v_dir_array.size - 1)]
            v_dir_target = v_dir+"_"+v_series_description_type
            v_path = v_base_path+"/"+v_path.gsub("/Volumes/team/","").gsub("/Volumes/team-1/","").gsub("/Data/vtrak1/","")
            if v_folder_array.include?(v_dir_target)
              v_dir_target = v_dir_target+"_"+v_cnt.to_s
              v_cnt = v_cnt +1
              # might get weird if multiple types have dups - only expect T1/Bravo
            end
            v_folder_array.push(v_dir_target)

             # v_call = "/usr/bin/bunzip2 "+v_parent_dir_target+"/"+v_dir_target+"/*.bz2"
              v_call = "mise "+v_path+" "+v_parent_dir_target+"/"+v_dir_target   # works where bunzip2 cmd after rsync not work
puts "AAAAAA "+v_call
             stdin, stdout, stderr = Open3.popen3(v_call)
              stderr.each {|line|
                  puts line
                }
                while !stdout.eof?
                  puts stdout.read 1024    
                 end
             stdin.close
             stdout.close
             stderr.close
             # temp - replace /Volumes/team/ and /Data/vtrak1/ with /Volumes/team-1 in dev
            # split on / --- get the last dir
            # make new dir name dir_series_description_type 
            # check if in v_folder_array , if in v_folder_array , dir_series_description_type => dir_series_description_type_2
            # add  dir, dir_series_description_type to v_folder_array
            # cp path ==> /tmp/adrc_upload/[subjectid]_yyymmdd_wisc/dir_series_description_type(_2)
      end

      sql_status = "select status_flag from cg_adrc_upload where subjectid ='"+r[0]+"'"
      results_status = connection.execute(sql_status)
      if v_scan_desc_type_array.size < 4   and (results_status.first)[0] != "R"
        sql_dirlist = "update cg_adrc_upload set general_comment =' NOT ALL SCAN TYPES!!!! "+v_folder_array.join(", ")+"' where subjectid ='"+r[0]+"' "
        results_dirlist = connection.execute(sql_dirlist)
         v_comment_warning = v_comment_warning+"  "+v_scan_desc_type_array.size.to_s+" scan type "+r[0]
      v_call = "rm -rf "+v_parent_dir_target
# puts "BBBBBBBB "+v_call
      stdin, stdout, stderr = Open3.popen3(v_call)
      stderr.each {|line|
           puts line
      }
      while !stdout.eof?
        puts stdout.read 1024    
       end   
      stdin.close
      stdout.close
      stderr.close
      else
      
        sql_dirlist = "update cg_adrc_upload set dir_list ='"+v_folder_array.join(", ")+"' where subjectid ='"+r[0]+"' "
        results_dirlist = connection.execute(sql_dirlist)
# TURN INTO A LOOP
        v_dicom_field_array =['0010,0030','0010,0010','0008,0050','0008,1030','0010,0020','0040,0254','0008,0080','0008,1010','0009,1002','0009,1030','0018,1000',
                        '0025,101A','0040,0242','0040,0243']
        v_dicom_field_value_hash ={'0010,0030'=>'DOB','0010,0010'=>'Name','0008,0050'=>'Accession Number',
                           '0008,1030'=>'Study Description', '0010,0020'=>'Patient ID','0040,0254'=>'Performed Proc Step Desc',
                            '0008,0080'=>'Institution Name','0008,1010'=>'Station Name','0009,1002'=>'Private',
                            '0009,1030'=>'Private','0018,1000'=>'Device Serial Number','0025,101A'=>'Private',
                            '0040,0242'=>'Performed Station Name','0040,0243'=>'Performed Location'}
     ####  v_dicom_field_array.each do |dicom_key|
               Dir.glob(v_parent_dir_target+'/*/*/*.dcm').each {|dcm| puts d = DICOM::DObject.new(dcm); 
                                                                                     v_dicom_field_array.each do |dicom_key|
                                                                                           if !d[dicom_key].nil? 
                                                                                                 d[dicom_key].value = v_dicom_field_value_hash[dicom_key]; d.write(dcm) 
                                                                                            end 
                                                                                      end }
              Dir.glob(v_parent_dir_target+'/*/*/*.0*').each {|dcm| puts d = DICOM::DObject.new(dcm); 
                                                                                        v_dicom_field_array.each do |dicom_key|
                                                                                            if !d[dicom_key].nil? 
                                                                                              d[dicom_key].value = v_dicom_field_value_hash[dicom_key]; d.write(dcm) 
                                                                                           end 
                                                                                        end }
                                                                                                
       ####  end                            
                                    
#                             
# # #puts "bbbbb dicom clean "+v_parent_dir_target+"/*/"
# Dir.glob(v_parent_dir_target+'/*/*/*.dcm').each {|dcm| puts d = DICOM::DObject.new(dcm); if !d["0010,0030"].nil? 
#                                                                                           d["0010,0030"].value = "DOB"; d.write(dcm) 
#                                                                                               end } 
        v_call = "rsync -av "+v_parent_dir_target+" panda_admin@scooby.dom.wisc.edu:/home/panda_admin/upload_adrc/"
        stdin, stdout, stderr = Open3.popen3(v_call)
        while !stdout.eof?
          puts stdout.read 1024    
         end
        stdin.close
        stdout.close
        stderr.close
                                                                           
        #v_call = "zip -r "+v_target_dir+"/"+v_subject_dir+".zip  "+v_parent_dir_target
        #v_call = "cd "+v_target_dir+"; zip -r "+v_subject_dir+"  "+v_subject_dir   #  ???????    PROBLEM HERE????
        v_call = "cd "+v_target_dir+";  /bin/tar -zcf "+v_subject_dir+".tar.gz "+v_subject_dir+"/"
        v_call =  'ssh panda_admin@scooby.dom.wisc.edu "  tar  -C /home/panda_admin/upload_adrc  -zcf /home/panda_admin/upload_adrc/'+v_subject_dir+'.tar.gz '+v_subject_dir+'/ "  '
        stdin, stdout, stderr = Open3.popen3(v_call)
        while !stdout.eof?
          puts stdout.read 1024    
         end
        stdin.close
        stdout.close
        stderr.close
        puts "bbbbbbb "+v_call

        v_call = ' rm -rf '+v_target_dir+'/'+v_subject_dir
           stdin, stdout, stderr = Open3.popen3(v_call)
           while !stdout.eof?
             puts stdout.read 1024    
            end
           stdin.close
           stdout.close
           stderr.close
        # 
        v_call = 'ssh panda_admin@scooby.dom.wisc.edu " rm -rf /home/panda_admin/upload_adrc/'+v_subject_dir+' "'
        stdin, stdout, stderr = Open3.popen3(v_call)
        while !stdout.eof?
          puts stdout.read 1024    
         end
        stdin.close
        stdout.close
        stderr.close
       
        
         # did the tar.gz on scooby to avoid mac acl PaxHeader extra directories
         v_call = "rsync -av panda_admin@scooby.dom.wisc.edu:/home/panda_admin/upload_adrc/"+v_subject_dir+".tar.gz "+v_target_dir+'/'+v_subject_dir+".tar.gz"
         stdin, stdout, stderr = Open3.popen3(v_call)
         while !stdout.eof?
           puts stdout.read 1024    
          end
         stdin.close
         stdout.close
         stderr.close

        # sftp -- shared helper hasthe username /password and address
        v_username = Shared.adrc_sftp_username # get from shared helper
        v_passwrd = Shared.adrc_sftp_password   # get from shared helperwhich is not on github
        v_ip = Shared.adrc_sftp_host_address # get from shared helper
        v_source = v_target_dir+'/'+v_subject_dir+".tar.gz"
        v_target = v_subject_dir+".tar.gz"
        Net::SFTP.start(v_ip, v_username, :password => v_passwrd) do |sftp|
            sftp.upload!(v_source, v_target)
        end

        v_call = " rm -rf "+v_target_dir+'/'+v_subject_dir+".tar.gz"
        stdin, stdout, stderr = Open3.popen3(v_call)
        while !stdout.eof?
          puts stdout.read 1024    
         end
        stdin.close
        stdout.close
        stderr.close        
        
        sql_sent = "update cg_adrc_upload set sent_flag ='Y' where subjectid ='"+r[0]+"' "
        results_sent = connection.execute(sql_sent)
      end
      v_comment = "end "+r[0]+","+v_comment
      @schedulerun.comment =v_comment[0..1990]
      @schedulerun.save 
    end
              
    @schedulerun.comment =("successful finish adrc_upload "+v_comment_warning+" "+v_comment[0..1990])
    if !v_comment.include?("ERROR")
       @schedulerun.status_flag ="Y"
     end
     @schedulerun.save
     @schedulerun.end_time = @schedulerun.updated_at      
     @schedulerun.save          
      
    
  end
  
  def run_asl_status
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
         @schedule = Schedule.where("name in ('asl_status')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting asl_status"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
    ####    begin   # catch all exception and put error in comment    
            sql = "truncate table cg_asl_status_new"
            connection = ActiveRecord::Base.connection();        
            results = connection.execute(sql)

            sql_base = "insert into cg_asl_status_new(asl_subjectid, asl_general_comment,asl_registered_to_fs_flag,asl_smoothed_and_warped_flag,asl_fmap_flag,asl_fmap_single,
            asl_bkup_registered_to_fs_flag,asl_bkup_smoothed_and_warped_flag,asl_bkup_fmap_flag,asl_bkup_fmap_single,asl_2013_0_fmap_flag,asl_2013_0_fmap_single,
            asl_2013_1525_fmap_flag,asl_2013_1525_fmap_single,asl_2013_2025_fmap_flag,asl_2013_2025_fmap_single,
            asl_2013_0_registered_to_fs_flag,asl_2013_0_smoothed_and_warped_flag,asl_2013_1525_registered_to_fs_flag,asl_2013_1525_smoothed_and_warped_flag,
            asl_2013_2025_registered_to_fs_flag,asl_2013_2025_smoothed_and_warped_flag,
            enrollment_id, scan_procedure_id)values("  
            v_raw_path = v_base_path+"/raw"
            v_mri = "/mri"
            no_mri_path_sp_list =['asthana.adrc-clinical-core.visit1',
            'bendlin.mets.visit1','bendlin.tami.visit1','bendlin.wmad.visit1','carlson.sharp.visit1','carlson.sharp.visit2',
            'carlson.sharp.visit3','carlson.sharp.visit4','dempsey.plaque.visit1','dempsey.plaque.visit2','gleason.falls.visit1',
            'johnson.merit220.visit1','johnson.merit220.visit2','johnson.tbi.aware.visit3','johnson.tbi-va.visit1','ries.aware.visit1','wrap140']

            v_preprocessed_path = v_base_path+"/preprocessed/visits/"
            # get list of scan_procedure codename -- exclude 4, 10, 15, 19, 32, 
                # ??? johnson.pc vs johnsonpc4000.visit1 vs pc_4000
                # ??? johnson.tbi10000 vs johnson.tbiaware vs tbi_1000
                # ??? johnson.wrap140.visit1 vs wrap140.visit1 vs wrap140
                # NOT exists /Volumes/team-1/raw/carlson.esprit/mri
                # NOT exists /Volumes/team-1/raw/johnson.wrap140.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbiaware.visit3/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit2/mri
                # NOT exists /Volumes/team-1/raw/johnnson.alz.repsup.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.pc4000.visit1/mri
            v_exclude_sp =[4,10,15,19,32]
            @scan_procedures = ScanProcedure.where("id not in (?)",v_exclude_sp)
            @scan_procedures. each do |sp|
              v_visit_number =""
              if sp.codename.include?("visit2")
                v_visit_number ="_v2"
              elsif sp.codename.include?("visit3")
                v_visit_number ="_v3"
              elsif sp.codename.include?("visit4")
                v_visit_number ="_v4"
              elsif sp.codename.include?("visit5")
                v_visit_number ="_v5"
              end
               if no_mri_path_sp_list.include?(sp.codename)
                 v_mri = ""
                else
                  v_mri = "/mri"
                end
                v_raw_full_path = v_raw_path+"/"+sp.codename+v_mri
                v_preprocessed_full_path = v_preprocessed_path+sp.codename
                if File.directory?(v_raw_full_path)
                    if !File.directory?(v_preprocessed_full_path)
                        puts "preprocessed path NOT exists "+v_preprocessed_full_path
                     end
                    Dir.entries(v_raw_full_path).select { |file| File.directory? File.join(v_raw_full_path, file)}.each do |dir|
                      dir_name_array = dir.split('_')
                      if dir_name_array.size == 3
                         enrollment = Enrollment.where("enumber in (?)",dir_name_array[0])
                         if !enrollment.blank?
                             v_asl_registered_to_fs_flag ="N"
                             v_asl_smoothed_and_warped_flag = "N"
                             v_asl_fmap_flag = "N"
                             v_asl_fmap_single ="N"                                
                             v_asl_bkup_registered_to_fs_flag ="N"
                             v_asl_bkup_smoothed_and_warped_flag = "N"
                             v_asl_bkup_fmap_flag = "N"
                             v_asl_bkup_fmap_single ="N"
                             v_asl_2013_0_fmap_flag = "N"
                             v_asl_2013_0_fmap_single ="N"   
                             v_asl_2013_0_registered_to_fs_flag ="N"
                             v_asl_2013_0_smoothed_and_warped_flag = "N"                          
                             v_asl_2013_1525_fmap_flag = "N"
                             v_asl_2013_1525_fmap_single ="N"  
                             v_asl_2013_1525_registered_to_fs_flag ="N"
                             v_asl_2013_1525_smoothed_and_warped_flag = "N"                           
                             v_asl_2013_2025_fmap_flag = "N"
                             v_asl_2013_2025_fmap_single ="N"
                             v_asl_2013_2025_registered_to_fs_flag ="N"
                             v_asl_2013_2025_smoothed_and_warped_flag = "N"
                             
                             v_subjectid_asl_bkup = v_preprocessed_full_path+"/"+dir_name_array[0]+"/asl_bkup"
                             if File.directory?(v_subjectid_asl_bkup)
                                  v_dir_array = Dir.entries(v_subjectid_asl_bkup)   # need to get date for specific files
                                  # evalute for asl_registered_to_fs_flag = rFS_ASL_[subjectid]_fmap.nii ,
                                  # asl_smoothed_and_warped_flag = swrFS_ASL_[subjectid]_fmap.nii,
                                  # asl_fmap_flag = [ASL_[subjectid]_[sdir]_fmap.nii or ASL_[subjectid]_fmap.nii],
                                  # asl_fmap_single = ASL_[subjectid]_fmap.nii
                             
                                v_dir_array.each do |f|
                                  if f == "swrFS_ASL_"+dir_name_array[0]+"_fmap.nii"
                                    v_asl_bkup_smoothed_and_warped_flag = "Y"
                                  elsif  f == "rFS_ASL_"+dir_name_array[0]+"_fmap.nii"
                                    v_asl_bkup_registered_to_fs_flag ="Y"
                                  elsif  f == "ASL_"+dir_name_array[0]+"_fmap.nii"
                                    v_asl_bkup_fmap_flag = "Y"
                                    v_asl_bkup_fmap_single ="Y"
                                  elsif  f.start_with?("ASL_"+dir_name_array[0]) and f.end_with?("_fmap.nii")
                                    v_asl_bkup_fmap_flag = "Y"
                                  end
                                end
                             end
                             
                             v_subjectid_asl = v_preprocessed_full_path+"/"+dir_name_array[0]+"/asl"
                             if File.directory?(v_subjectid_asl)
                                  v_dir_array = Dir.entries(v_subjectid_asl)   # need to get date for specific files
                                  # evalute for asl_registered_to_fs_flag = rFS_ASL_[subjectid]_fmap.nii ,
                                  # asl_smoothed_and_warped_flag = swrFS_ASL_[subjectid]_fmap.nii,
                                  # asl_fmap_flag = [ASL_[subjectid]_[sdir]_fmap.nii or ASL_[subjectid]_fmap.nii],
                                  # asl_fmap_single = ASL_[subjectid]_fmap.nii
                                  # dir_name_array[0] is just subjectid
                             
                                v_dir_array.each do |f|
                                  if f == "swrFS_ASL_"+dir_name_array[0]+"_fmap.nii"
                                    v_asl_smoothed_and_warped_flag = "Y"
                                  elsif  f == "rFS_ASL_"+dir_name_array[0]+"_fmap.nii"
                                    v_asl_registered_to_fs_flag ="Y"
                                  elsif  f.start_with?("ASL_fmap_"+dir_name_array[0]+"_0_") and f.end_with?(".nii")
                                    v_asl_2013_0_fmap_flag = "Y"
                                    v_asl_2013_0_fmap_single ="Y"
                                   # v_asl_2013_1525_fmap_flag = "Y"
                                    # v_asl_2013_1525_fmap_single ="Y" 
                                  elsif f.start_with?("swrFS_ASL_fmap_"+dir_name_array[0]+"_0_") and f.end_with?(".nii") 
                                      v_asl_2013_0_smoothed_and_warped_flag = "Y"
                                  elsif  f.start_with?("rFS_ASL_fmap_"+dir_name_array[0]+"_0_") and f.end_with?(".nii")
                                      v_asl_2013_0_registered_to_fs_flag ="Y"                                                                         
                                  elsif   f.start_with?("ASL_fmap_"+dir_name_array[0]+"_1525_") and f.end_with?(".nii")
                                      v_asl_2013_1525_fmap_flag = "Y"
                                      v_asl_2013_1525_fmap_single ="Y"
                                  elsif f.start_with?("swrFS_ASL_fmap_"+dir_name_array[0]+"_1525_") and f.end_with?(".nii") 
                                      v_asl_2013_1525_smoothed_and_warped_flag = "Y"
                                  elsif  f.start_with?("rFS_ASL_fmap_"+dir_name_array[0]+"_1525_") and f.end_with?(".nii")
                                      v_asl_2013_1525_registered_to_fs_flag ="Y"                                                                       
                                  elsif   f.start_with?("ASL_fmap_"+dir_name_array[0]+"_2025_") and f.end_with?(".nii")
                                      v_asl_2013_2025_fmap_flag = "Y"
                                      v_asl_2013_2025_fmap_single ="Y"  
                                  elsif f.start_with?("swrFS_ASL_fmap_"+dir_name_array[0]+"_2025_") and f.end_with?(".nii") 
                                      v_asl_2013_2025_smoothed_and_warped_flag = "Y"
                                  elsif  f.start_with?("rFS_ASL_fmap_"+dir_name_array[0]+"_2025_") and f.end_with?(".nii")
                                      v_asl_2013_2025_registered_to_fs_flag ="Y"                                    
                                  elsif  f == "ASL_"+dir_name_array[0]+"_fmap.nii"
                                    v_asl_fmap_flag = "Y"
                                    v_asl_fmap_single ="Y"
                                  elsif  f.start_with?("ASL_"+dir_name_array[0]) and f.end_with?("_fmap.nii")
                                    v_asl_fmap_flag = "Y"
                                  end
                                end
                             end
                             if File.directory?(v_subjectid_asl) or  File.directory?(v_subjectid_asl_bkup)
                                sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','','"+v_asl_registered_to_fs_flag+"','"+v_asl_smoothed_and_warped_flag+"','"+v_asl_fmap_flag+"',
                                                           '"+v_asl_fmap_single+"','"+v_asl_bkup_registered_to_fs_flag+"','"+v_asl_bkup_smoothed_and_warped_flag+"','"+v_asl_bkup_fmap_flag+"',
                                                           '"+v_asl_bkup_fmap_single+"','"+v_asl_2013_0_fmap_flag+"', '"+v_asl_2013_0_fmap_single+"','"+v_asl_2013_1525_fmap_flag+"', '"+v_asl_2013_1525_fmap_single+"',
                                                          '"+v_asl_2013_2025_fmap_flag+"', '"+v_asl_2013_2025_fmap_single+"','"+v_asl_2013_0_registered_to_fs_flag+"','"+v_asl_2013_0_smoothed_and_warped_flag+"'
                                                          ,'"+v_asl_2013_1525_registered_to_fs_flag+"','"+v_asl_2013_1525_smoothed_and_warped_flag+"','"+v_asl_2013_2025_registered_to_fs_flag+"',
                                                          '"+v_asl_2013_2025_smoothed_and_warped_flag+"',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             else
                                 sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','no ASL or ASL_bkup dir','N','N','N','N','N','N','N','N','N','N','N','N','N','N','N','N','N','N','N','N',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             end # check for subjectid asl dir
                         else
                           #puts "no enrollment "+dir_name_array[0]
                         end # check for enrollment
                      end # check that dir name is in expected format [subjectid]_exam#_MMDDYY - just test size of array
                    end # loop thru the subjectids
                 else
                        #puts "               # NOT exists "+v_raw_full_path
                 end # check if raw dir exisits
            end            
            # check move cg_ to cg_old
            # v_shared = Shared.new 
             # move from new to present table -- made into a function  in shared model
             v_comment = self.move_present_to_old_new_to_present("cg_asl_status",
             "asl_subjectid, asl_general_comment,asl_registered_to_fs_flag, asl_registered_to_fs_comment, asl_registered_to_fs_global_quality, asl_smoothed_and_warped_flag, asl_smoothed_and_warped_comment, asl_smoothed_and_warped_global_quality, asl_fmap_flag, asl_fmap_single, asl_fmap_comment, asl_fmap_global_quality,
             asl_bkup_registered_to_fs_flag, asl_bkup_registered_to_fs_comment, asl_bkup_registered_to_fs_global_quality, asl_bkup_smoothed_and_warped_flag, asl_bkup_smoothed_and_warped_comment, asl_bkup_smoothed_and_warped_global_quality, asl_bkup_fmap_flag, asl_bkup_fmap_single, asl_bkup_fmap_comment, asl_bkup_fmap_global_quality, 
             asl_2013_0_fmap_flag, asl_2013_0_fmap_single, asl_2013_0_fmap_comment, asl_2013_0_fmap_global_quality,
             asl_2013_1525_fmap_flag, asl_2013_1525_fmap_single, asl_2013_1525_fmap_comment, asl_2013_1525_fmap_global_quality,
            asl_2013_2025_fmap_flag, asl_2013_2025_fmap_single, asl_2013_2025_fmap_comment, asl_2013_2025_fmap_global_quality,
            asl_2013_0_registered_to_fs_flag,asl_2013_0_smoothed_and_warped_flag,asl_2013_1525_registered_to_fs_flag,asl_2013_1525_smoothed_and_warped_flag,
            asl_2013_2025_registered_to_fs_flag,asl_2013_2025_smoothed_and_warped_flag,
              enrollment_id,scan_procedure_id",
                            "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


             # apply edits  -- made into a function  in shared model
             self.apply_cg_edits('cg_asl_status')

             puts "successful finish asl_status "+v_comment[0..459]
              @schedulerun.comment =("successful finish asl_status "+v_comment[0..459])
              if !v_comment.include?("ERROR")
                 @schedulerun.status_flag ="Y"
               end
               @schedulerun.save
               @schedulerun.end_time = @schedulerun.updated_at      
               @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
    
    
  end
  

  def run_dir_size
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
        connection = ActiveRecord::Base.connection(); 
         @schedule = Schedule.where("name in ('dir_size')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting dir_size"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
          v_date = Date.today.strftime("%Y-%m-%d")
          v_dir_array =['data2','data4','data6','SysAdmin','data1','data3','data5','data7','analyses','preprocessed','soar_data','raw'] 
          # v_dir_array =['data3']    
          # linux likes "du -ch --max-depth=2 ."
          # mac like "du -ch -d 2 ."
          v_cnt = 1
          v_dir_array.each do |dir|  
            v_depth = "1"
            if dir == "preprocessed"
               v_depth = "2"
            end
            v_dir_base =   v_base_path+"/"+dir      
            v_sql = "delete from dir_size where run_date ='"+v_date+"' and dir_base ='"+v_dir_base+"' "
              results = connection.execute(v_sql)                      
            v_call = "cd "+v_dir_base+"; du -ch -d "+v_depth+" ."
            puts v_call
            stdin, stdout, stderr = Open3.popen3(v_call)
            while !stdout.eof?
              v_val = 1
              # just waiting
            end
            while v_line = stdout.gets 
           # (stdout.read).each do |v_line|    
              # convert eveything to G
              v_cols = v_line.split()
              # gsub and to_float, divide
              v_dir_size = v_cols[0]
              v_dir_size_float =0
              if v_dir_size.include?"G"
                 v_dir_size.gsub("G","")
                 v_dir_size_float = v_dir_size.to_f
              elsif v_dir_size.include?"T"
                v_dir_size.gsub("T","")
                v_dir_size_float =  (v_dir_size.to_f)*1024
              elsif v_dir_size.include?"M"
                v_dir_size.gsub("M","")
                v_dir_size_float =  (v_dir_size.to_f)/(1024)
              elsif v_dir_size.include?"K"
                v_dir_size.gsub("K","")
                v_dir_size_float =  (v_dir_size.to_f)/(1024*1024)
              end
              
              # split, replace leading ./ with v_dir_base
              if v_cols[1][0..0] == "."
                 v_dir_path = v_dir_base+ (v_cols[1])[1..-1]  # need to trim leading "."
              else
                if v_cols[1] == "total"
                  v_dir_path = v_dir_base+"/="+ (v_cols[1])
                else
                    v_dir_path = v_dir_base+"/"+ (v_cols[1])
                 end
              end
               v_sql = "insert into dir_size(dir_base,dir_path, run_date,dir_size)Values('"+v_dir_base+"','"+v_dir_path+"','"+v_date+"','"+v_dir_size_float.to_s+"')"
               results = connection.execute(v_sql)
               v_cnt = v_cnt + 1
             end
             # how to try/catch errors
             
            stdin.close
            stdout.close
            stderr.close
          end

           puts "successful finish dir_size "+v_comment[0..459]
           @schedulerun.comment =("successful finish dir_size "+v_cnt.to_s+" rows inserted "+ v_comment[0..459])
           if !v_comment.include?("ERROR")
              @schedulerun.status_flag ="Y"
           end
           @schedulerun.save
           @schedulerun.end_time = @schedulerun.updated_at      
           @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
  end  
  

  def run_dti_status
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
         @schedule = Schedule.where("name in ('dti_status')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting dti_status"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
    ####    begin   # catch all exception and put error in comment    
            sql = "truncate table cg_dti_status_new"
            connection = ActiveRecord::Base.connection();        
            results = connection.execute(sql)

            sql_base = "insert into cg_dti_status_new(dti_subjectid,dti_fa_file_name, dti_general_comment,dti_fa_flag,dti_md_file_name,dti_md_flag,enrollment_id, scan_procedure_id)values("  
# just looking in preprocessed for list - but could add the listing from raw later to drive processing 

            v_preprocessed_path = v_base_path+"/preprocessed/modalities/dti/adluru_pipeline/"
            v_preprocessed_full_path = v_preprocessed_path   #+sp.codename
            if File.directory?( v_preprocessed_full_path) # v_raw_full_path)
              if !File.directory?(v_preprocessed_full_path)
                  puts "preprocessed path NOT exists "+v_preprocessed_full_path
              end
              # FA
              # ls *_combined_fa.nii*
              # split off subjected - assume all visit1
              v_cnt = 0
              Dir.glob(v_preprocessed_path+"/FA/*_combined_fa.nii*").each do |f|
                  v_file_name = f.gsub(v_preprocessed_path+"/FA/","")
                  file_name_array = v_file_name.split('_')
                  if file_name_array.size == 3
                      enrollment = Enrollment.where("enumber in (?)",file_name_array[0])
                      if !enrollment.blank?
                        v_dti_fa_flag = "Y"
                        # get v_sp based on subjectid - replace all numbers? look up in scan_procedure -- visit1 
                        v_subjectid_trim = file_name_array[0].gsub(/[0-9]/,"")
                        sql = "select id from scan_procedures where subjectid_base ='"+v_subjectid_trim+"' and codename like '%visit1'"
                        results = connection.execute(sql)
                        v_sp = 0;
                        results.each do |r|
                              v_sp = r[0]
                        end
                        sql = sql_base+"'"+file_name_array[0]+"','"+v_file_name+"','','"+v_dti_fa_flag+"',NULL,'Y',"+enrollment[0].id.to_s+","+v_sp.to_s+")"
                        results = connection.execute(sql)
                        v_cnt = v_cnt + 1
                      end
                  else
                        #puts "               # NOT exists "+v_raw_full_path
                  end # check if raw dir exisits
              end
              Dir.glob(v_preprocessed_path+"/MD/*_combined_md.nii*").each do |f|
                  v_file_name = f.gsub(v_preprocessed_path+"/MD/","")
                  file_name_array = v_file_name.split('_')
                  if file_name_array.size == 3
                      enrollment = Enrollment.where("enumber in (?)",file_name_array[0])
                      if !enrollment.blank?
                        v_dti_md_flag = "Y"
                        # get v_sp based on subjectid - replace all numbers? look up in scan_procedure -- visit1 
                        v_subjectid_trim = file_name_array[0].gsub(/[0-9]/,"")
                        sql = "select id from scan_procedures where subjectid_base ='"+v_subjectid_trim+"' and codename like '%visit1'"
                        results = connection.execute(sql)
                        v_sp = 0;
                        results.each do |r|
                              v_sp = r[0]
                        end
                        # check if file_name_array[0] == dti_subjectid
                        sql = "select * from cg_dti_status_new where dti_subjectid ='"+file_name_array[0]+"'"
                        results = connection.execute(sql)
                        if results.size > 0
                           sql = "update cg_dti_status_new set dti_md_flag ='"+v_dti_md_flag+"', dti_md_file_name='"+v_file_name+"'"
                           results = connection.execute(sql)
                        else 
                           sql = sql_base+"'"+file_name_array[0]+"',NULL,'','N','"+v_file_name+"','"+v_dti_md_flag+"',"+enrollment[0].id.to_s+","+v_sp.to_s+")"
                           results = connection.execute(sql)
                        end
                        v_cnt = v_cnt + 1
                      end
                  else
                        #puts "               # NOT exists "+v_raw_full_path
                  end # check if raw dir exisits
              end
              
              
           end           
           # check move cg_ to cg_old
           # v_shared = Shared.new 
           # move from new to present table -- made into a function  in shared model
           v_comment = self.move_present_to_old_new_to_present("cg_dti_status",
             "dti_subjectid,dti_fa_file_name, dti_general_comment,dti_fa_flag, dti_fa_comment, dti_fa_global_quality,dti_md_file_name,dti_md_flag, dti_md_comment, dti_md_global_quality, enrollment_id,scan_procedure_id",
                            "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


           # apply edits  -- made into a function  in shared model
           self.apply_cg_edits('cg_dti_status')

           puts "successful finish dti_status "+v_comment[0..459]
           @schedulerun.comment =("successful finish dti_status "+v_cnt.to_s+" records loaded "+v_comment[0..459])
           if !v_comment.include?("ERROR")
              @schedulerun.status_flag ="Y"
           end
           @schedulerun.save
           @schedulerun.end_time = @schedulerun.updated_at      
           @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
  end  
  
  def run_epi_rest_status
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
         @schedule = Schedule.where("name in ('epi_rest_status')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting epi_rest_status"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
    ####    begin   # catch all exception and put error in comment    
            sql = "truncate table cg_epi_rest_status_new"
            connection = ActiveRecord::Base.connection();        
            results = connection.execute(sql)

            sql_base = "insert into cg_epi_rest_status_new(epi_rest_subjectid, epi_rest_general_comment,w_filter_errts_norm_ra_flag,filter_errts_norm_ra_flag,enrollment_id, scan_procedure_id)values("  
            v_raw_path = v_base_path+"/raw"
            v_mri = "/mri"
            no_mri_path_sp_list =['asthana.adrc-clinical-core.visit1',
            'bendlin.mets.visit1','bendlin.tami.visit1','bendlin.wmad.visit1','carlson.sharp.visit1','carlson.sharp.visit2',
            'carlson.sharp.visit3','carlson.sharp.visit4','dempsey.plaque.visit1','dempsey.plaque.visit2','gleason.falls.visit1',
            'johnson.merit220.visit1','johnson.merit220.visit2','johnson.tbi.aware.visit3','johnson.tbi-va.visit1','ries.aware.visit1','wrap140']

            v_preprocessed_path = v_base_path+"/preprocessed/visits/"
            # get list of scan_procedure codename -- exclude 4, 10, 15, 19, 32, 
                # ??? johnson.pc vs johnsonpc4000.visit1 vs pc_4000
                # ??? johnson.tbi10000 vs johnson.tbiaware vs tbi_1000
                # ??? johnson.wrap140.visit1 vs wrap140.visit1 vs wrap140
                # NOT exists /Volumes/team-1/raw/carlson.esprit/mri
                # NOT exists /Volumes/team-1/raw/johnson.wrap140.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbiaware.visit3/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit2/mri
                # NOT exists /Volumes/team-1/raw/johnnson.alz.repsup.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.pc4000.visit1/mri
            v_exclude_sp =[4,10,15,19,32]
            @scan_procedures = ScanProcedure.where("id not in (?)",v_exclude_sp)
            @scan_procedures. each do |sp|
              v_visit_number =""
              if sp.codename.include?("visit2")
                v_visit_number ="_v2"
              elsif sp.codename.include?("visit3")
                v_visit_number ="_v3"
              elsif sp.codename.include?("visit4")
                v_visit_number ="_v4"
              elsif sp.codename.include?("visit5")
                v_visit_number ="_v5"
              end
               if no_mri_path_sp_list.include?(sp.codename)
                 v_mri = ""
                else
                  v_mri = "/mri"
                end
                v_raw_full_path = v_raw_path+"/"+sp.codename+v_mri
                v_preprocessed_full_path = v_preprocessed_path+sp.codename
                if File.directory?(v_raw_full_path)
                    if !File.directory?(v_preprocessed_full_path)
                        puts "preprocessed path NOT exists "+v_preprocessed_full_path
                     end
                    Dir.entries(v_raw_full_path).select { |file| File.directory? File.join(v_raw_full_path, file)}.each do |dir|
                      dir_name_array = dir.split('_')
                      if dir_name_array.size == 3
                         enrollment = Enrollment.where("enumber in (?)",dir_name_array[0])
                         if !enrollment.blank?
                             v_subjectid_epi_rest = v_preprocessed_full_path+"/"+dir_name_array[0]+"/epi_rest/proc"
                             if File.directory?(v_subjectid_epi_rest)
                                  v_dir_array = Dir.entries(v_subjectid_epi_rest)   # need to get date for specific files
                                v_w_filter_errts_norm_ra_flag ="N"
                                v_filter_errts_norm_ra_flag = "N"
                                v_dir_array.each do |f|
                                  if f.start_with?("filter_errts_norm_ra"+dir_name_array[0]) and f.end_with?(".nii")
                                    v_filter_errts_norm_ra_flag = "Y"
                                  elsif f.start_with?("w_filter_errts_norm_ra"+dir_name_array[0]) and f.end_with?(".nii")
                                        v_w_filter_errts_norm_ra_flag ="Y"
                                  end
                                end
                                
                                sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','','"+v_w_filter_errts_norm_ra_flag+"','"+v_filter_errts_norm_ra_flag+"',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             else
                                 sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','no epi_rest dir','N','N',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             end # check for subjectid asl dir
                         else
                           #puts "no enrollment "+dir_name_array[0]
                         end # check for enrollment
                      end # check that dir name is in expected format [subjectid]_exam#_MMDDYY - just test size of array
                    end # loop thru the subjectids
                 else
                        #puts "               # NOT exists "+v_raw_full_path
                 end # check if raw dir exisits
            end            
            # check move cg_ to cg_old
            # v_shared = Shared.new 
             # move from new to present table -- made into a function  in shared model
             v_comment = self.move_present_to_old_new_to_present("cg_epi_rest_status",
             "epi_rest_subjectid, epi_rest_general_comment,w_filter_errts_norm_ra_flag, w_filter_errts_norm_ra_comment, w_filter_errts_norm_ra_global_quality, filter_errts_norm_ra_flag, filter_errts_norm_ra_comment, filter_errts_norm_ra_global_quality, enrollment_id,scan_procedure_id",
                            "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


             # apply edits  -- made into a function  in shared model
             self.apply_cg_edits('cg_epi_rest_status')

             puts "successful finish epi_rest_status "+v_comment[0..459]
              @schedulerun.comment =("successful finish epi_rest_status "+v_comment[0..459])
              if !v_comment.include?("ERROR")
                 @schedulerun.status_flag ="Y"
               end
               @schedulerun.save
               @schedulerun.end_time = @schedulerun.updated_at      
               @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
    
    
  end

  def run_fdg_status
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
         @schedule = Schedule.where("name in ('fdg_status')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting fdg_status"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
    ####    begin   # catch all exception and put error in comment    
            sql = "truncate table cg_fdg_status_new"
            connection = ActiveRecord::Base.connection();        
            results = connection.execute(sql)

            sql_base = "insert into cg_fdg_status_new(fdg_subjectid, fdg_general_comment,fdg_registered_to_fs_flag,fdg_scaled_registered_to_fs_flag,fdg_smoothed_and_warped_flag,fdg_scaled_smoothed_and_warped_flag,enrollment_id, scan_procedure_id)values("  


            v_preprocessed_path = v_base_path+"/preprocessed/visits/"
            # get list of scan_procedure codename -- exclude 4, 10, 15, 19, 32, 
                # ??? johnson.pc vs johnsonpc4000.visit1 vs pc_4000
                # ??? johnson.tbi10000 vs johnson.tbiaware vs tbi_1000
                # ??? johnson.wrap140.visit1 vs wrap140.visit1 vs wrap140
                # NOT exists /Volumes/team-1/raw/carlson.esprit/mri
                # NOT exists /Volumes/team-1/raw/johnson.wrap140.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbiaware.visit3/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit2/mri
                # NOT exists /Volumes/team-1/raw/johnnson.alz.repsup.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.pc4000.visit1/mri
            v_exclude_sp =[4,10,15,19,32]
            @scan_procedures = ScanProcedure.where("petscan_flag='Y' and id not in (?)",v_exclude_sp)  # NEED ONLY sp with fdg, but filter later
            @scan_procedures. each do |sp|
               v_visit_number =""
               if sp.codename.include?("visit2")
                  v_visit_number ="_v2"
               elsif sp.codename.include?("visit3")
                  v_visit_number ="_v3"
               elsif sp.codename.include?("visit4")
                  v_visit_number ="_v4"
               elsif sp.codename.include?("visit5")
                  v_visit_number ="_v5"
               end

                v_preprocessed_full_path = v_preprocessed_path+sp.codename
                sql_enum = "select distinct enrollments.enumber from enrollments, scan_procedures_vgroups, vgroups, appointments, petscans, enrollment_vgroup_memberships
                                    where scan_procedures_vgroups.scan_procedure_id = "+sp.id.to_s+" and  vgroups.transfer_pet = 'yes'  
                                    and appointments.vgroup_id = vgroups.id and appointments.appointment_type = 'pet_scan'
                                    and appointments.id = petscans.appointment_id and petscans.lookup_pettracer_id = 2
                                    and enrollment_vgroup_memberships.vgroup_id = vgroups.id and enrollment_vgroup_memberships.enrollment_id = enrollments.id
                                    and enrollments.enumber like '"+sp.subjectid_base+"%' order by enrollments.enumber"
                 @results = connection.execute(sql_enum)
                                    
                 @results.each do |r|
                     enrollment = Enrollment.where("enumber='"+r[0]+"'")
                     if !enrollment.blank?
                        v_subjectid_fdg = v_preprocessed_full_path+"/"+enrollment[0].enumber+"/pet/fdg"
                        if File.directory?(v_subjectid_fdg)
                            v_dir_array = Dir.entries(v_subjectid_fdg)   # need to get date for specific files
                            v_fdg_registered_to_fs_flag ="N"
                            v_fdg_scaled_registered_to_fs_flag ="N"
                            v_fdg_smoothed_and_warped_flag = "N"
                            v_fdg_scaled_smoothed_and_warped_flag = "N"
                            v_dir_array.each do |f|
                               if f.start_with?("swr") and f.end_with?("summed.nii")
                                  v_fdg_smoothed_and_warped_flag = "Y"
                               elsif f.start_with?("swr") and f.end_with?("scaled.nii")
                                  v_fdg_scaled_smoothed_and_warped_flag = "Y"
                               elsif f.start_with?("rFS") and f.end_with?("summed.nii")
                                  v_fdg_registered_to_fs_flag ="Y"
                               elsif f.start_with?("rFS") and f.end_with?("scaled.nii")
                                  v_fdg_scaled_registered_to_fs_flag ="Y"
                                end
                              end
                                
                             sql = sql_base+"'"+enrollment[0].enumber+v_visit_number+"','','"+v_fdg_registered_to_fs_flag+"','"+v_fdg_scaled_registered_to_fs_flag+"','"+v_fdg_smoothed_and_warped_flag+"','"+v_fdg_scaled_smoothed_and_warped_flag+"',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             else
                                 sql = sql_base+"'"+enrollment[0].enumber+v_visit_number+"','no fdg dir','N','N','N','N',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             end # check for subjectid asl dir
                      else
                           #puts "no enrollment "+dir_name_array[0]
                      end # check for enrollment
                 end # loop thru the subjectids
            end            
            # check move cg_ to cg_old
            # v_shared = Shared.new 
             # move from new to present table -- made into a function  in shared model
             v_comment = self.move_present_to_old_new_to_present("cg_fdg_status",
             "fdg_subjectid, fdg_general_comment,fdg_registered_to_fs_flag, fdg_registered_to_fs_comment, fdg_registered_to_fs_global_quality,fdg_scaled_registered_to_fs_flag, fdg_scaled_registered_to_fs_comment, fdg_scaled_registered_to_fs_global_quality,fdg_smoothed_and_warped_flag, fdg_smoothed_and_warped_comment, fdg_smoothed_and_warped_global_quality,fdg_scaled_smoothed_and_warped_flag, fdg_scaled_smoothed_and_warped_comment, fdg_scaled_smoothed_and_warped_global_quality,enrollment_id,scan_procedure_id",
                            "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


             # apply edits  -- made into a function  in shared model
             self.apply_cg_edits('cg_fdg_status')

             puts "successful finish fdg_status "+v_comment[0..459]
              @schedulerun.comment =("successful finish fdg_status "+v_comment[0..459])
              if !v_comment.include?("ERROR")
                 @schedulerun.status_flag ="Y"
               end
               @schedulerun.save
               @schedulerun.end_time = @schedulerun.updated_at      
               @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
    
    
  end
  
  
  def run_lst_116_status   # also lst_122 in same column
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
         @schedule = Schedule.where("name in ('lst_116_status')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting lst_116_status"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
    ####    begin   # catch all exception and put error in comment    
            sql = "truncate table cg_lst_116_status_new"
            connection = ActiveRecord::Base.connection();        
            results = connection.execute(sql)

            sql_base = "insert into cg_lst_116_status_new(lst_116_subjectid, lst_116_general_comment,wlesion_030_flag,enrollment_id, scan_procedure_id)values("  
            v_raw_path = v_base_path+"/raw"
            v_mri = "/mri"
            no_mri_path_sp_list =['asthana.adrc-clinical-core.visit1',
            'bendlin.mets.visit1','bendlin.tami.visit1','bendlin.wmad.visit1','carlson.sharp.visit1','carlson.sharp.visit2',
            'carlson.sharp.visit3','carlson.sharp.visit4','dempsey.plaque.visit1','dempsey.plaque.visit2','gleason.falls.visit1',
            'johnson.merit220.visit1','johnson.merit220.visit2','johnson.tbi.aware.visit3','johnson.tbi-va.visit1','ries.aware.visit1','wrap140']

            v_preprocessed_path = v_base_path+"/preprocessed/visits/"
            # get list of scan_procedure codename -- exclude 4, 10, 15, 19, 32, 
                # ??? johnson.pc vs johnsonpc4000.visit1 vs pc_4000
                # ??? johnson.tbi10000 vs johnson.tbiaware vs tbi_1000
                # ??? johnson.wrap140.visit1 vs wrap140.visit1 vs wrap140
                # NOT exists /Volumes/team-1/raw/carlson.esprit/mri
                # NOT exists /Volumes/team-1/raw/johnson.wrap140.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbiaware.visit3/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit2/mri
                # NOT exists /Volumes/team-1/raw/johnnson.alz.repsup.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.pc4000.visit1/mri
            v_exclude_sp =[4,10,15,19,32]
            @scan_procedures = ScanProcedure.where("id not in (?)",v_exclude_sp)
            @scan_procedures. each do |sp|
              v_visit_number =""
              if sp.codename.include?("visit2")
                v_visit_number ="_v2"
              elsif sp.codename.include?("visit3")
                v_visit_number ="_v3"
              elsif sp.codename.include?("visit4")
                v_visit_number ="_v4"
              elsif sp.codename.include?("visit5")
                v_visit_number ="_v5"
              end
               if no_mri_path_sp_list.include?(sp.codename)
                 v_mri = ""
                else
                  v_mri = "/mri"
                end
                v_raw_full_path = v_raw_path+"/"+sp.codename+v_mri
                v_preprocessed_full_path = v_preprocessed_path+sp.codename
                if File.directory?(v_raw_full_path)
                    if !File.directory?(v_preprocessed_full_path)
                        puts "preprocessed path NOT exists "+v_preprocessed_full_path
                     end
                    Dir.entries(v_raw_full_path).select { |file| File.directory? File.join(v_raw_full_path, file)}.each do |dir|
                      dir_name_array = dir.split('_')
                      if dir_name_array.size == 3
                         enrollment = Enrollment.where("enumber in (?)",dir_name_array[0])
                         if !enrollment.blank?
                             v_subjectid_lst_116 = v_preprocessed_full_path+"/"+dir_name_array[0]+"/LST_116"
                             v_subjectid_lst_122 = v_preprocessed_full_path+"/"+dir_name_array[0]+"/LST_122"
                             if File.directory?(v_subjectid_lst_116)
                                  v_dir_array = Dir.entries(v_subjectid_lst_116)   # need to get date for specific files
                                v_wlesion_030_flag ="N"
                                v_dir_array.each do |f|
                                  if f.start_with?("wlesion_030_m"+dir_name_array[0]+"_Sag-CUBE-FLAIR_") and f.end_with?("_cubet2flair.nii")
                                    v_wlesion_030_flag = "Y"
                                   end
                                end
                                sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','LST 116 dir','"+v_wlesion_030_flag+"',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             else
                                 if File.directory?(v_subjectid_lst_122)
                                       v_dir_array = Dir.entries(v_subjectid_lst_122)   # need to get date for specific files
                                     v_wlesion_030_flag ="N"
                                     v_dir_array.each do |f|
                                       if f.start_with?("wlesion_lbm0_030_rm"+dir_name_array[0]+"_Sag-CUBE-FLAIR_") and f.end_with?("_cubet2flair.nii")
                                         v_wlesion_030_flag = "Y"
                                        end
                                     end
                                     sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','LST 122 dir','"+v_wlesion_030_flag+"',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                      results = connection.execute(sql)
                               
                                 else
                                   sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','no LST_116 dir or LST_122 dir','N',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                   results = connection.execute(sql)
                                 end
                             end # check for subjectid asl dir
                         else
                           #puts "no enrollment "+dir_name_array[0]
                         end # check for enrollment
                      end # check that dir name is in expected format [subjectid]_exam#_MMDDYY - just test size of array
                    end # loop thru the subjectids
                 else
                        #puts "               # NOT exists "+v_raw_full_path
                 end # check if raw dir exisits
            end            
            # check move cg_ to cg_old
            # v_shared = Shared.new 
             # move from new to present table -- made into a function  in shared model
             v_comment = self.move_present_to_old_new_to_present("cg_lst_116_status",
             "lst_116_subjectid, lst_116_general_comment,wlesion_030_flag, wlesion_030_comment, wlesion_030_global_quality, enrollment_id,scan_procedure_id",
                            "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


             # apply edits  -- made into a function  in shared model
             self.apply_cg_edits('cg_lst_116_status')

             puts "successful finish lst_116_status "+v_comment[0..459]
              @schedulerun.comment =("successful finish lst_116_status "+v_comment[0..459])
              if !v_comment.include?("ERROR")
                 @schedulerun.status_flag ="Y"
               end
               @schedulerun.save
               @schedulerun.end_time = @schedulerun.updated_at      
               @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
    
    
  end
  
  def run_pib_status
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
         @schedule = Schedule.where("name in ('pib_status')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting pib_status"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
    ####    begin   # catch all exception and put error in comment    
            sql = "truncate table cg_pib_status_new"
            connection = ActiveRecord::Base.connection();        
            results = connection.execute(sql)

            sql_base = "insert into cg_pib_status_new(pib_subjectid, pib_general_comment,pib_registered_to_fs_flag,pib_smoothed_and_warped_flag,enrollment_id, scan_procedure_id)values("  


            v_preprocessed_path = v_base_path+"/preprocessed/visits/"
            # get list of scan_procedure codename -- exclude 4, 10, 15, 19, 32, 
                # ??? johnson.pc vs johnsonpc4000.visit1 vs pc_4000
                # ??? johnson.tbi10000 vs johnson.tbiaware vs tbi_1000
                # ??? johnson.wrap140.visit1 vs wrap140.visit1 vs wrap140
                # NOT exists /Volumes/team-1/raw/carlson.esprit/mri
                # NOT exists /Volumes/team-1/raw/johnson.wrap140.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbiaware.visit3/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit2/mri
                # NOT exists /Volumes/team-1/raw/johnnson.alz.repsup.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.pc4000.visit1/mri
            v_exclude_sp =[4,10,15,19,32]
            @scan_procedures = ScanProcedure.where("petscan_flag='Y' and id not in (?)",v_exclude_sp)  # NEED ONLY sp with pib, but filter later
            @scan_procedures. each do |sp|
               v_visit_number =""
               if sp.codename.include?("visit2")
                  v_visit_number ="_v2"
               elsif sp.codename.include?("visit3")
                  v_visit_number ="_v3"
               elsif sp.codename.include?("visit4")
                  v_visit_number ="_v4"
               elsif sp.codename.include?("visit5")
                  v_visit_number ="_v5"
               end

                v_preprocessed_full_path = v_preprocessed_path+sp.codename
                sql_enum = "select distinct enrollments.enumber from enrollments, scan_procedures_vgroups, vgroups, appointments, petscans, enrollment_vgroup_memberships
                                    where scan_procedures_vgroups.scan_procedure_id = "+sp.id.to_s+" and  vgroups.transfer_pet = 'yes'  
                                    and appointments.vgroup_id = vgroups.id and appointments.appointment_type = 'pet_scan'
                                    and appointments.id = petscans.appointment_id and petscans.lookup_pettracer_id = 1
                                    and enrollment_vgroup_memberships.vgroup_id = vgroups.id and enrollment_vgroup_memberships.enrollment_id = enrollments.id
                                    and enrollments.enumber like '"+sp.subjectid_base+"%' order by enrollments.enumber"
                 @results = connection.execute(sql_enum)
                                    
                 @results.each do |r|
                     enrollment = Enrollment.where("enumber='"+r[0]+"'")
                     if !enrollment.blank?
                        v_subjectid_pib = v_preprocessed_full_path+"/"+enrollment[0].enumber+"/pet/pib"
                        if File.directory?(v_subjectid_pib)
                            v_dir_array = Dir.entries(v_subjectid_pib)   # need to get date for specific files
                            v_pib_registered_to_fs_flag ="N"
                            v_pib_smoothed_and_warped_flag = "N"
                            v_dir_array.each do |f|
                               if f.start_with?("swr") and f.end_with?(".nii")
                                  v_pib_smoothed_and_warped_flag = "Y"
                               elsif f.start_with?("rFS") and f.end_with?(".nii")
                                  v_pib_registered_to_fs_flag ="Y"
                                end
                              end
                                
                             sql = sql_base+"'"+enrollment[0].enumber+v_visit_number+"','','"+v_pib_registered_to_fs_flag+"','"+v_pib_smoothed_and_warped_flag+"',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             else
                                 sql = sql_base+"'"+enrollment[0].enumber+v_visit_number+"','no pib dir','N','N',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             end # check for subjectid asl dir
                      else
                           #puts "no enrollment "+dir_name_array[0]
                      end # check for enrollment
                 end # loop thru the subjectids
            end            
            # check move cg_ to cg_old
            # v_shared = Shared.new 
             # move from new to present table -- made into a function  in shared model
             v_comment = self.move_present_to_old_new_to_present("cg_pib_status",
             "pib_subjectid, pib_general_comment,pib_registered_to_fs_flag, pib_registered_to_fs_comment, pib_registered_to_fs_global_quality, pib_smoothed_and_warped_flag, pib_smoothed_and_warped_comment, pib_smoothed_and_warped_global_quality, enrollment_id,scan_procedure_id",
                            "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


             # apply edits  -- made into a function  in shared model
             self.apply_cg_edits('cg_pib_status')

             puts "successful finish pib_status "+v_comment[0..459]
              @schedulerun.comment =("successful finish pib_status "+v_comment[0..459])
              if !v_comment.include?("ERROR")
                 @schedulerun.status_flag ="Y"
               end
               @schedulerun.save
               @schedulerun.end_time = @schedulerun.updated_at      
               @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
    
    
  end
    
  def run_t1seg_status
        visit = Visit.find(3)  #  need to get base path without visit
        v_base_path = visit.get_base_path()
         @schedule = Schedule.where("name in ('t1seg_status')").first
          @schedulerun = Schedulerun.new
          @schedulerun.schedule_id = @schedule.id
          @schedulerun.comment ="starting t1seg_status"
          @schedulerun.save
          @schedulerun.start_time = @schedulerun.created_at
          @schedulerun.save
          v_comment = ""
    ####    begin   # catch all exception and put error in comment    
            sql = "truncate table cg_t1seg_status_new"
            connection = ActiveRecord::Base.connection();        
            results = connection.execute(sql)

            sql_base = "insert into cg_t1seg_status_new(t1seg_subjectid, t1seg_general_comment,t1seg_ac_pc_flag,t1seg_smoothed_and_warped_flag,enrollment_id, scan_procedure_id)values("  
            v_raw_path = v_base_path+"/raw"
            v_mri = "/mri"
            no_mri_path_sp_list =['asthana.adrc-clinical-core.visit1',
            'bendlin.mets.visit1','bendlin.tami.visit1','bendlin.wmad.visit1','carlson.sharp.visit1','carlson.sharp.visit2',
            'carlson.sharp.visit3','carlson.sharp.visit4','dempsey.plaque.visit1','dempsey.plaque.visit2','gleason.falls.visit1',
            'johnson.merit220.visit1','johnson.merit220.visit2','johnson.tbi.aware.visit3','johnson.tbi-va.visit1','ries.aware.visit1','wrap140']

            v_preprocessed_path = v_base_path+"/preprocessed/visits/"
            # get list of scan_procedure codename -- exclude 4, 10, 15, 19, 32, 
                # ??? johnson.pc vs johnsonpc4000.visit1 vs pc_4000
                # ??? johnson.tbi10000 vs johnson.tbiaware vs tbi_1000
                # ??? johnson.wrap140.visit1 vs wrap140.visit1 vs wrap140
                # NOT exists /Volumes/team-1/raw/carlson.esprit/mri
                # NOT exists /Volumes/team-1/raw/johnson.wrap140.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbiaware.visit3/mri
                # NOT exists /Volumes/team-1/raw/johnson.tbi1000.visit2/mri
                # NOT exists /Volumes/team-1/raw/johnnson.alz.repsup.visit1/mri
                # NOT exists /Volumes/team-1/raw/johnson.pc4000.visit1/mri
            v_exclude_sp =[4,10,15,19,32]
            @scan_procedures = ScanProcedure.where("id not in (?)",v_exclude_sp)
            @scan_procedures. each do |sp|
              v_visit_number =""
              if sp.codename.include?("visit2")
                v_visit_number ="_v2"
              elsif sp.codename.include?("visit3")
                v_visit_number ="_v3"
              elsif sp.codename.include?("visit4")
                v_visit_number ="_v4"
              elsif sp.codename.include?("visit5")
                v_visit_number ="_v5"
              end
               if no_mri_path_sp_list.include?(sp.codename)
                 v_mri = ""
                else
                  v_mri = "/mri"
                end
                v_raw_full_path = v_raw_path+"/"+sp.codename+v_mri
                v_preprocessed_full_path = v_preprocessed_path+sp.codename
                if File.directory?(v_raw_full_path)
                    if !File.directory?(v_preprocessed_full_path)
                        puts "preprocessed path NOT exists "+v_preprocessed_full_path
                     end
                    Dir.entries(v_raw_full_path).select { |file| File.directory? File.join(v_raw_full_path, file)}.each do |dir|
                      dir_name_array = dir.split('_')
                      if dir_name_array.size == 3
                         enrollment = Enrollment.where("enumber in (?)",dir_name_array[0])
                         if !enrollment.blank?
                             v_subjectid_t1seg = v_preprocessed_full_path+"/"+dir_name_array[0]+"/t1_aligned_newseg"
                             v_subjectid_unknown = v_preprocessed_full_path+"/"+dir_name_array[0]+"/unknown"
                             if File.directory?(v_subjectid_t1seg)
                                  v_dir_array = Dir.entries(v_subjectid_t1seg)   # need to get date for specific files
                                  # evalute for t1seg_ac_pc_flag = rFS_t1seg_[subjectid]_fmap.nii ,
                                  # t1seg_smoothed_and_warped_flag = swrFS_t1seg_[subjectid]_fmap.nii,
                                  # t1seg_fmap_flag = [t1seg_[subjectid]_[sdir]_fmap.nii or t1seg_[subjectid]_fmap.nii],
                                  # t1seg_fmap_single = t1seg_[subjectid]_fmap.nii
                                v_t1seg_ac_pc_flag ="N"
                                v_t1seg_smoothed_and_warped_flag = "N"
                                v_dir_array.each do |f|
                                  if f.start_with?("smwc1o"+dir_name_array[0]+"_Ax-FSPGR-BRAVO_") and f.end_with?(".nii")
                                    v_t1seg_smoothed_and_warped_flag = "Y"
                                  end
                                end
                                if File.directory?(v_subjectid_unknown)
                                  v_dir_array = Dir.entries(v_subjectid_unknown)
                                  v_dir_array.each do |f|
                                     if f.start_with?("o"+dir_name_array[0]+"_Ax-FSPGR-BRAVO_") and f.end_with?(".nii")
                                        v_t1seg_ac_pc_flag ="Y"
                                      end
                                  end
                                end
                                
                                sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','','"+v_t1seg_ac_pc_flag+"','"+v_t1seg_smoothed_and_warped_flag+"',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             else
                                 sql = sql_base+"'"+dir_name_array[0]+v_visit_number+"','no t1_aligned_newseg dir','N','N',"+enrollment[0].id.to_s+","+sp.id.to_s+")"
                                 results = connection.execute(sql)
                             end # check for subjectid asl dir
                         else
                           #puts "no enrollment "+dir_name_array[0]
                         end # check for enrollment
                      end # check that dir name is in expected format [subjectid]_exam#_MMDDYY - just test size of array
                    end # loop thru the subjectids
                 else
                        #puts "               # NOT exists "+v_raw_full_path
                 end # check if raw dir exisits
            end            
            # check move cg_ to cg_old
            # v_shared = Shared.new 
             # move from new to present table -- made into a function  in shared model
             v_comment = self.move_present_to_old_new_to_present("cg_t1seg_status",
             "t1seg_subjectid, t1seg_general_comment,t1seg_ac_pc_flag, t1seg_ac_pc_comment, t1seg_ac_pc_global_quality, t1seg_smoothed_and_warped_flag, t1seg_smoothed_and_warped_comment, t1seg_smoothed_and_warped_global_quality, enrollment_id,scan_procedure_id",
                            "scan_procedure_id is not null  and enrollment_id is not null ",v_comment)


             # apply edits  -- made into a function  in shared model
             self.apply_cg_edits('cg_t1seg_status')

             puts "successful finish t1seg_status "+v_comment[0..459]
              @schedulerun.comment =("successful finish t1seg_status "+v_comment[0..459])
              if !v_comment.include?("ERROR")
                 @schedulerun.status_flag ="Y"
               end
               @schedulerun.save
               @schedulerun.end_time = @schedulerun.updated_at      
               @schedulerun.save
    ####    rescue Exception => msg
    ####         v_error = msg.to_s
    ####         puts "ERROR !!!!!!!"
    ####         puts v_error
    ####         v_error = v_error+"\n"+v_comment
    ####          @schedulerun.comment =v_error[0..499]
    ####          @schedulerun.status_flag="E"
    ####    end
    
    
  end
  
  
  def run_fs_Y_N
    visit = Visit.find(3)  #  need to get base path without visit
    v_base_path = visit.get_base_path()
     @schedule = Schedule.where("name in ('fs_Y_N')").first
      @schedulerun = Schedulerun.new
      @schedulerun.schedule_id = @schedule.id
      @schedulerun.comment ="starting fs_Y_N"
      @schedulerun.save
      @schedulerun.start_time = @schedulerun.created_at
      @schedulerun.save
    begin   # catch all exception and put error in comment
       v_fs_path = v_base_path+"/preprocessed/modalities/freesurfer/orig_recon/"
      # ls the dirs and links
      v_dir_skip =  ['QA', 'fsaverage', 'fsaverage_bkup20121114', '.', '..', 'lh.EC_average','rh.EC_average','qdec','surfer.log']
      # 'tmp*'  --- just keep dir cleaner
      # ??? 'pdt00020.long.pdt00020_base',      'pdt00020_base',       'pdt00020_v2.long.pdt00020_base', plq20018.R, plq20024.R
      # _v2, _v3, _v4 --> visit2,3,4
      connection = ActiveRecord::Base.connection();
      v_sp_visit1_array = []
      v_sp_visit2_array = []
      v_sp_visit3_array = []
      v_sp_visit4_array = []
      sql = "select id from scan_procedures where codename like '%visit2'"        
      results = connection.execute(sql)
      results.each do |r|
        v_sp_visit2_array.push(r[0])
      end      
      
      sql = "select id from scan_procedures where codename like '%visit3'"        
      results = connection.execute(sql)
      results.each do |r|
        v_sp_visit3_array.push(r[0])
      end
      
      sql = "select id from scan_procedures where codename like '%visit4'"        
      results = connection.execute(sql)
      results.each do |r|
        v_sp_visit4_array.push(r[0])
      end
      
      sql = "select id from scan_procedures where codename not like '%visit2' and  codename  not like '%visit3' and  codename  not like '%visit4'"        
      results = connection.execute(sql)
      results.each do |r|
        v_sp_visit1_array.push(r[0])
      end      
      
      
      
      # check for enumber in enrollment, link to enrollment_vgroup_memberships, appointments, visits
      # limit by _v2, _v3, _v4 in sp via scan_procedures_vgroups , scan_procedures like 'visit2, visit3, visit4
      dir_list = Dir.entries(v_fs_path).select { |file| File.directory? File.join(v_fs_path, file)}
      link_list = Dir.entries(v_fs_path).select { |file| File.symlink? File.join(v_fs_path, file)}
      dir_list.concat(link_list)
      v_cnt = 0
      dir_list.each do |dirname|
        if !v_dir_skip.include?(dirname) and !dirname.start_with?('tmp')
          if dirname.include?('_v2')
            dirname = dirname.gsub(/_v2/,'')
            v_dirname_chop = dirname.gsub(/[0123456789]/,'')
            vgroups = Vgroup.where("vgroups.id in (select enrollment_vgroup_memberships.vgroup_id from enrollments, enrollment_vgroup_memberships 
                                                                     where enrollments.id = enrollment_vgroup_memberships.enrollment_id and enumber in (?))
                                                            and vgroups.id in (select appointments.vgroup_id from appointments where appointment_type = 'mri' )
                                                            and vgroups.id in ( select scan_procedures_vgroups.vgroup_id from scan_procedures_vgroups,scan_procedures
                                                                                             where scan_procedures_vgroups.scan_procedure_id in (?)
                                                                                              and scan_procedures.id = scan_procedures_vgroups.scan_procedure_id 
                                                                                              and scan_procedures.subjectid_base in (?))", dirname,v_sp_visit2_array,v_dirname_chop)                                                                               
            vgroups.each do |v|
              if v.fs_flag != "Y"
                 v.fs_flag ="Y"
                 v.save
                 v_cnt = v_cnt + 1
              end
            end
          elsif dirname.include?('_v3')
            dirname = dirname.gsub(/_v3/,'')
            v_dirname_chop = dirname.gsub(/[0123456789]/,'')
            vgroups = Vgroup.where("vgroups.id in (select enrollment_vgroup_memberships.vgroup_id from enrollments, enrollment_vgroup_memberships 
                                                                     where enrollments.id = enrollment_vgroup_memberships.enrollment_id and enumber in (?))
                                                             and vgroups.id in (select appointments.vgroup_id from appointments where appointment_type = 'mri' )
                                                            and vgroups.id in ( select scan_procedures_vgroups.vgroup_id from scan_procedures_vgroups,scan_procedures
                                                                                             where scan_procedures_vgroups.scan_procedure_id in (?)
                                                                                              and scan_procedures.id = scan_procedures_vgroups.scan_procedure_id 
                                                                                              and scan_procedures.subjectid_base in (?))", dirname,v_sp_visit3_array,v_dirname_chop)
            vgroups.each do |v|
              if v.fs_flag != "Y"
                 v.fs_flag ="Y"
                 v.save
                  v_cnt = v_cnt + 1
              end
            end
          elsif dirname.include?('_v4')
            dirname = dirname.gsub(/_v4/,'')
            v_dirname_chop = dirname.gsub(/[0123456789]/,'')
            vgroups = Vgroup.where("vgroups.id in (select enrollment_vgroup_memberships.vgroup_id from enrollments, enrollment_vgroup_memberships 
                                                                     where enrollments.id = enrollment_vgroup_memberships.enrollment_id and enumber in (?))
                                                             and vgroups.id in (select appointments.vgroup_id from appointments where appointment_type = 'mri' )
                                                            and vgroups.id in ( select scan_procedures_vgroups.vgroup_id from scan_procedures_vgroups,scan_procedures
                                                                                             where scan_procedures_vgroups.scan_procedure_id in (?)
                                                                                              and scan_procedures.id = scan_procedures_vgroups.scan_procedure_id 
                                                                                              and scan_procedures.subjectid_base in (?))", dirname,v_sp_visit4_array,v_dirname_chop)
            vgroups.each do |v|
              if v.fs_flag != "Y"
                 v.fs_flag ="Y"
                 v.save
                  v_cnt = v_cnt + 1
              end
            end
          else
            v_dirname_chop = dirname.gsub(/[0123456789]/,'')
            vgroups = Vgroup.where("vgroups.id in (select enrollment_vgroup_memberships.vgroup_id from enrollments, enrollment_vgroup_memberships 
                                                                     where enrollments.id = enrollment_vgroup_memberships.enrollment_id and enumber in (?))
                                                             and vgroups.id in (select appointments.vgroup_id from appointments where appointment_type = 'mri' )
                                                            and vgroups.id in ( select scan_procedures_vgroups.vgroup_id from scan_procedures_vgroups,scan_procedures
                                                                                             where scan_procedures_vgroups.scan_procedure_id in (?)
                                                                                             and scan_procedures.id = scan_procedures_vgroups.scan_procedure_id 
                                                                                             and scan_procedures.subjectid_base in (?))", dirname,v_sp_visit1_array,v_dirname_chop)
            vgroups.each do |v|
              if v.fs_flag != "Y"
                 v.fs_flag ="Y"
                 v.save
                  v_cnt = v_cnt + 1
              end
            end
          end
        end
      end
 
        @schedulerun.comment ="successful finish fs_Y_N ===set = Y "+v_cnt.to_s
        @schedulerun.status_flag ="Y"
        @schedulerun.save
        @schedulerun.end_time = @schedulerun.updated_at      
        @schedulerun.save
      puts " fs_flag set = Y "+v_cnt.to_s
      rescue Exception => msg
         v_error = msg.to_s
         puts "ERROR !!!!!!!"
         puts v_error
          @schedulerun.comment =v_error[0..499]
          @schedulerun.status_flag="E"
          @schedulerun.save
      end
    
    
  end
  
end