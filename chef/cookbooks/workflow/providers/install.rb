# =================================================================
# Copyright 2018 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =================================================================

#
# Cookbook Name:: workflow 
# Provider:: workflow_install
#

include IM::Helper
include WF::Helper
use_inline_resources

#Create Action preare
action :prepare do
  # Download and extract binaries
  #case node['platform_family']
    #when 'debian'
      #apt_update 'update' do
        # action :update
    #end
  #end
  #package 'unzip'

  workflow_expand_area = node['ibm']['expand_area']
  #unpack_complete_file_name = workflow_expand_area + '/unpack_complete.txt'

  # TODO: need solve the issue - unpack_complete.txt is created always.

  #if ::File.exist?(unpack_complete_file_name)
  #  Chef::Log.info("#{unpack_complete_file_name} exists. Unpack will not be done.")
  #else
    #converge_by("prepare #{@new_resource}") do

      #Chef::Log.info("#{unpack_complete_file_name} doesn't exist. Unpack now...")
      repo_paths = new_resource.sw_repo 

      user = define_user
      group = define_group
      im_folder_permission = define_im_folder_permission

      im_archive_names = node['workflow']['archive_names']
      im_archive_names.each_pair do |p, v|

        filename = v['filename']
        #md5 = v['md5']
        Chef::Log.info("Unpacking #{filename}...")

        ibm_cloud_utils_unpack "unpack-#{filename}" do
          source "#{repo_paths}/#{filename}"
          target_dir workflow_expand_area
          mode im_folder_permission
          #checksum md5 
          owner user
          group group
          remove_local true
          secure_repo new_resource.secure_repo
          vault_name node['workflow']['vault']['name']
          vault_item node['workflow']['vault']['encrypted_id']
          repo_self_signed_cert new_resource.repo_nonsecureMode
        end
      end

      #unpack_complete = open(unpack_complete_file_name, 'w')
      #FileUtils.chown user, group, unpack_complete_file_name
      #unpack_complete.write(SecureRandom.hex)
      #unpack_complete.close
    #end
  #end

  # Create the needed folders, 
  # if the dires are created with right permission and user/group, it's idempotency
  define_prepare_dirs
end

# Cleanup environment after Workflow installation
action :cleanup do
  tmp_dir = node['ibm']['temp_dir']
  # Cleanup expand area
  Chef::Log.info("Cleanup #{tmp_dir} \n")
  directory tmp_dir do
    recursive true
    action :delete
  end
end

#Create Action install_im
action :install_im do
  if @current_resource.im_installed
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  else
    converge_by("install_im #{@new_resource}") do

      im_install_dir = define_im_install_dir
      im_data_dir = define_im_data_dir
      im_shared_dir = define_im_shared_dir
      im_folder_permission = define_im_folder_permission

      user = define_user
      group = define_group

      # Install the 64bit directly for that only 64bit OS is supported by Workflow, if need, extract and allow install 32bit for 32bit OS.
      im_repo = node['ibm']['expand_area'] + '/IM64'

      ibm_log_dir = define_ibm_log_dir
      im_log_dir = ibm_log_dir + '/im'

      # evidence for im
      im_evidence_dir = ibm_log_dir + '/evidence'

      # Create the folders needed
      [im_log_dir, im_evidence_dir, "#{im_install_dir}/eclipse"].each do |dir|
        directory dir do
          recursive true
          action :create
          mode im_folder_permission
          owner user
          group group
        end
      end

      # Run the install - With im_shared_dir set (Above V1.8)
      execute "installim_#{new_resource.name}" do

        # Install the 64bit directly for that only 64bit OS is supported by Workflow, if need, extract and allow install 32bit for 32bit OS.
        cwd "#{im_repo}/tools"
        command %( ./imcl install com.ibm.cic.agent -repositories #{im_repo} -installationDirectory #{im_install_dir}/eclipse -accessRights #{new_resource.im_install_mode} -acceptLicense -dataLocation #{im_data_dir} -sharedResourcesDirectory #{im_shared_dir} -log #{im_log_dir}/IM.install.log)
        user user
        group group
        not_if { im_installed?(im_install_dir, new_resource.im_version, user) }

      end

      # By now, the im_repo_nonsecureMode will keep as 'false'
      if new_resource.im_repo_nonsecureMode == "true" && new_resource.im_install_mode == "group"
        import_self_signed_certificate
      end

      evidence_tar = "#{im_evidence_dir}/im-#{cookbook_name}-#{node['hostname']}-#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.tar"
      evidence_log = "#{cookbook_name}-#{node['hostname']}.log"
      # Run validation script
      execute 'Verify IM installation' do
        user user
        group group
        command "#{im_install_dir}/eclipse/tools/imcl version >> #{im_log_dir}/#{evidence_log}"
        only_if { Dir.glob("#{evidence_tar}").empty? }
      end

      # Tar logs
      ibm_cloud_utils_tar "Create_#{evidence_tar}" do
        source "#{im_log_dir}/#{evidence_log}"
        target_tar evidence_tar
        only_if { Dir.glob("#{evidence_tar}").empty? }
      end

      # clean up evidence log
      #["#{im_log_dir}/#{evidence_log}"].each do |dir|
      #  file dir do
      #    action :delete
      #  end
      #end
    end
  end
end

action :install do
  if @current_resource.installed
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  elsif @current_resource.im_installed
    converge_by("install #{@new_resource}") do

      im_install_dir = define_im_install_dir
      im_shared_dir = define_im_shared_dir
      ibm_log_dir = define_ibm_log_dir

      workflow_log_dir = ibm_log_dir + '/workflow'

      workflow_repo = node['ibm']['expand_area'] + '/repository/repos_64bit' 
      im_repo = node['ibm']['expand_area'] + '/IM64'

      user = define_user
      group = define_group

      if new_resource.im_repo_user.nil?
        Chef::Log.info "install: im_repo_user not provided. Please make sure your IM repo is not secured. If your IM repo is secured you must provide im_repo_user and configure your chef vault for password"
      else
        generate_storage_file
      end

      security_params = define_security_params

      # Re-encrypt the passwords using './imutilsc -s encryptString xxx', IM need encrypted passwords
      cmd_out = shell_out!("#{im_repo}/tools/imutilsc -s encryptString " + new_resource.db2_password)
      db2_password = cmd_out.stdout

      cmd_out = shell_out!("#{im_repo}/tools/imutilsc -s encryptString " + new_resource.db2_fenced_password)
      db2_fenced_password = cmd_out.stdout

      cmd_out = shell_out!("#{im_repo}/tools/imutilsc -s encryptString " + new_resource.db2_das_password)
      db2_das_password = cmd_out.stdout

      if !(new_resource.db2_response_file.nil? || new_resource.db2_response_file.empty?)
        db2_log_dir = ibm_log_dir + '/db2'
        db2_im_data_dir = '/var/ibm/InstallationManager_DB2'
        db2_install_dir = '/opt/IBM/DB2wWAS'
        db2_install_mode = 'admin'
        db2_install_user = 'root'
        db2_install_group = 'root'

        db2_silent_install_file="#{im_repo}/#{new_resource.db2_offering_id}_#{new_resource.db2_response_file}"

        template db2_silent_install_file do
          source 'responsefiles/' + new_resource.db2_response_file + '.erb'
          variables(
            :REPO_LOCATION => workflow_repo,
            :IM_REPO_LOCATION => im_repo,
            :INSTALL_LOCATION => db2_install_dir,
            :PROFILE_ID => new_resource.profile_id,
            :WAS_OFFERING_ID => new_resource.was_offering_id,
            :DB2_OFFERING_ID => new_resource.db2_offering_id,
            :DB2_PORT => new_resource.db2_port,
            :DB2INSTANCE_USERID => new_resource.db2_username,
            :ENCRYPTED_PWD => db2_password,
            :DB2_DAS_NEWUSER => new_resource.db2_das_newuser,
            :DB2_FENCED_NEWUSER => new_resource.db2_fenced_newuser,
            :DB2FENCED_USERID => new_resource.db2_fenced_username,
            :DB2FENCED_ENCRYPTED_PWD => db2_fenced_password,
            :DB2DAS_USERID => new_resource.db2_das_username,
            :DB2DAS_ENCRYPTED_PWD => db2_das_password
          )
        end

        # Use 'userinstc', 'installc' or 'groupinstc' seperately or specify different install mode
        install_command = "./imcl input #{db2_silent_install_file} #{security_params} -dataLocation #{db2_im_data_dir} -showProgress -accessRights #{db2_install_mode} -acceptLicense -log #{db2_log_dir}/#{new_resource.db2_offering_id}.install.log"

        execute "install #{new_resource.name}" do
          user db2_install_user
          group db2_install_group
          cwd im_repo + '/tools'
          command install_command
          not_if { ibm_installed_from_data?(im_repo + '/tools', db2_im_data_dir, new_resource.db2_offering_id, new_resource.db2_offering_version, db2_install_user) }
        end
      end

      silent_install_file="#{im_install_dir}/#{new_resource.offering_id}_#{new_resource.response_file}"

      template silent_install_file do
        source 'responsefiles/' + new_resource.response_file + '.erb'
        variables(
          :REPO_LOCATION => workflow_repo,
          :IM_REPO_LOCATION => im_repo,
          :INSTALL_LOCATION => new_resource.install_dir,
          :IM_INSTALL_LOCATION => im_install_dir,
          :WAS_OFFERING_ID => new_resource.was_offering_id,
          :DB2_OFFERING_ID => new_resource.db2_offering_id,
          :DB2_PORT => new_resource.db2_port,
          :DB2INSTANCE_USERID => new_resource.db2_username,
          :ENCRYPTED_PWD => db2_password,
          :DB2_DAS_NEWUSER => new_resource.db2_das_newuser,
          :DB2_FENCED_NEWUSER => new_resource.db2_fenced_newuser,
          :DB2FENCED_USERID => new_resource.db2_fenced_username,
          :DB2FENCED_ENCRYPTED_PWD => db2_fenced_password,
          :DB2DAS_USERID => new_resource.db2_das_username,
          :DB2DAS_ENCRYPTED_PWD => db2_das_password,
          :OFFERING_ID => new_resource.offering_id,
          :FEATURE_LIST => new_resource.feature_list,
          :PROFILE_ID => new_resource.profile_id,
          :IMSHARED => im_shared_dir
        )
      end

      # Use 'userinstc', 'installc' or 'groupinstc' seperately or specify different install mode
      install_command = "./imcl input #{silent_install_file} #{security_params} -showProgress -accessRights #{new_resource.im_install_mode} -acceptLicense -log #{workflow_log_dir}/#{new_resource.offering_id}.install.log"

      execute "install #{new_resource.name}" do
        user user
        group group
        cwd im_install_dir + '/eclipse/tools'
        command install_command

        # TODO: for admin mode, DB2 will be installed. 
        # Workflow installation success doesn't mean that DB2 installation success.
        not_if { ibm_installed?(im_install_dir, new_resource.offering_id, new_resource.offering_version, user) }
      end

      workflow_evidence_dir = ibm_log_dir + '/evidence'
      im_folder_permission = define_im_folder_permission
      [workflow_log_dir, workflow_evidence_dir].each do |dir|
        directory dir do
          recursive true
          action :create
          mode im_folder_permission
          owner user
          group group
        end
      end

      evidence_tar = "#{workflow_evidence_dir}/wf-#{cookbook_name}-#{node['hostname']}-#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.tar"
      evidence_log = "#{cookbook_name}-#{node['hostname']}.log"
      # Run validation script
      execute 'Verify Workflow installation' do
        user user
        group group
        command "#{new_resource.install_dir}/bin/versionInfo.sh -long >> #{workflow_log_dir}/#{evidence_log}"
        only_if { Dir.glob("#{evidence_tar}").empty? }
      end

      # Tar logs
      ibm_cloud_utils_tar "Create_#{evidence_tar}" do
        source "#{workflow_log_dir}/#{evidence_log}"
        target_tar evidence_tar
        only_if { Dir.glob("#{evidence_tar}").empty? }
      end

      # clean up evidence log
      #["#{workflow_log_dir}/#{evidence_log}"].each do |dir|
      #  file dir do
      #    action :delete
      #  end
      #end

      ["/tmp/master_password_file.txt", "/tmp/credential.store"].each do |dir|
        file dir do
          action :delete
        end
      end
    end
  else
    user = define_user
    Chef::Log.fatal "Installation manager is not installed for user #{user}. Please use :install_im action to install IM."
    raise "Installation manager is not installed for user #{user}. Please use :install_im action to install IM."
  end
end

#Create Action applyifix, need be executed after installation completed
action :applyifix do
  ifix_names = new_resource.ifix_names

  if ifix_names.nil? || ifix_names.empty? || ifix_names.lstrip.empty?
    Chef::Log.info "applyifix #{@new_resource} no ifixes need by installed - nothing to do."
  else
    converge_by("applyifix #{@new_resource}") do

      ifix_names = ifix_names.split(",")
      im_install_dir = define_im_install_dir
      im_folder_permission = define_im_folder_permission
      user = define_user
      group = define_group

      ifixes_expand_area = node['ibm']['expand_area'] + '/ifixes'
      # Manage base directory - Ifixes directory
      # TODO: investigate why the directory can't be created successfully here, but move it to define_prepare_dirs, the creation works.
      #subdirs = subdirs_to_create(ifixes_expand_area, user)
      #subdirs.each do |dir|
      #  directory dir do
      #    action :create
      #    recursive true
      #    owner user
      #    group group
      #  end
      #end

      # Write repository.config, will override if exists
      # TODO: no need to write new repository.config file if no ifixes need be installed.
      repository_config_filename = ifixes_expand_area  + "/repository.config"
      repository_config = open(repository_config_filename, 'w')
      need_install = false
      begin
        FileUtils.chown user, group, repository_config
        repository_config.puts("LayoutPolicy=Composite")
        repository_config.puts("LayoutPolicyVersion=0.0.0.1")
        

        repo_paths = new_resource.ifix_repo 
        ifix_names.each_with_index do |ifix_name, index|
          Chef::Log.info("Unpacking #{ifix_name}...")
          # ignore if the ifix_name is not valid
          next if ifix_name.nil? || ifix_name.lstrip.empty?

          # remove the blanks before and after the ifix name
          ifix_name = ifix_name.lstrip.rstrip
          ifix_zip_name = ifix_name + ".zip"
          # If the input ifix_name is with .zip, handle it
          if ifix_name =~ /\.zip$/
            ifix_zip_name = ifix_name
            ifix_name = ::File.basename(ifix_name, ".zip").to_s
          end

          unless ifix_installed?(im_install_dir, ifix_name, user)
            ibm_cloud_utils_unpack "unpack-#{ifix_name}" do
              source "#{repo_paths}/#{ifix_zip_name}"
              target_dir ifixes_expand_area + "/#{ifix_name}"
              mode im_folder_permission
              #checksum md5 
              owner user
              group group
              remove_local true
              secure_repo new_resource.secure_repo
              vault_name node['workflow']['vault']['name']
              vault_item node['workflow']['vault']['encrypted_id']
              repo_self_signed_cert new_resource.repo_nonsecureMode
            end

            need_install = true
            repository_config.puts("repository.url.#{index}=./#{ifix_name}")
          end
        end
      ensure
        # close file in finally block, always!
        repository_config.close
      end

      # set "-preferences offering.service.repositories.areUsed=false" to apply ifixes only
      cmd = "./imcl updateAll -preferences offering.service.repositories.areUsed=false -repositories #{ifixes_expand_area} -acceptLicense -installationDirectory #{new_resource.install_dir} -installFixes all"
      execute "applyifix_#{new_resource.name}" do

        # Install ifixes
        cwd "#{im_install_dir}/eclipse/tools"
        command cmd
        user user
        group group
        not_if { !need_install }
      end

      # TODO: evidence
    end
  end
end

#Override Load Current Resource
def load_current_resource
  Chef.event_handler do
    on :run_failed do
      HandlerSensitiveFiles::Helper.new.remove_sensitive_files_on_run_failure
    end
  end
  im_install_dir = define_im_install_dir
  im_repo = define_im_repo
  user = define_user

  # CHEF 12 @current_resource = Chef::Resource::WorkflowInstall.new(@new_resource.name)
  @current_resource = Chef::Resource.resource_for_node(:workflow_install, node).new(@new_resource.name)
  Chef::Log.info @current_resource

  #@current_resource = Chef::Resource::WorkflowInstall.new(@new_resource.name)
  #A common step is to load the current_resource instance variables with what is established in the new_resource.
  #What is passed into new_resouce via our recipes, is not automatically passed to our current_resource.
  @current_resource.user(user)
  @current_resource.im_version(@new_resource.im_version)
  @current_resource.im_install_dir(im_install_dir)
  @current_resource.offering_id(@new_resource.offering_id)
  @current_resource.offering_version(@new_resource.offering_version)

  #Get current state
  @current_resource.im_installed = im_installed?(im_install_dir, @new_resource.im_version, user)
  @current_resource.installed = ibm_installed?(im_install_dir, @new_resource.offering_id, @new_resource.offering_version, user)
  #@current_resource.fp_installed = im_fixpack_installed?(im_install_dir, im_repo, security_params, node['im']['fixpack_offering_id'] + '_' + @new_resource.im_version, user)

  Chef::Log.info @current_resource

  remove_storage_file
end

# Create necessary directory/folder recursively in advanced
# TODO: permission?
def define_prepare_dirs

  # Create the needed folders 
  user = define_user
  group = define_group

  ibm_log_dir = define_ibm_log_dir
  im_install_dir = define_im_install_dir
  im_data_dir = define_im_data_dir
  im_shared_dir = define_im_shared_dir

  # Manage base directory - ibm log directory
  subdirs = subdirs_to_create(ibm_log_dir, user)
  subdirs.each do |dir|
    directory dir do
      action :create
      recursive true
      owner user
      group group
    end
  end

  # Manage base directory - installation directory
  subdirs = subdirs_to_create(new_resource.install_dir, user)
  subdirs.each do |dir|
    directory dir do
      action :create
      recursive true
      owner user
      group group
    end
  end

  # Manage base directory - IM installation directory
  subdirs = subdirs_to_create(im_install_dir, user)
  subdirs.each do |dir|
    directory dir do
      action :create
      recursive true
      owner user
      group group
    end
  end

  # Manage base directory - IM data directory
  subdirs = subdirs_to_create(im_data_dir, user)
  subdirs.each do |dir|
    directory dir do
      action :create
      recursive true
      owner user
      group group
    end
  end

  # Manage base directory - IM shared directory
  subdirs = subdirs_to_create(im_shared_dir, user)
  subdirs.each do |dir|
    directory dir do
      action :create
      recursive true
      owner user
      group group
    end
  end


  ifixes_expand_area = node['ibm']['expand_area'] + '/ifixes'
  # Manage base directory - Ifixes directory
  subdirs = subdirs_to_create(ifixes_expand_area, user)
  subdirs.each do |dir|
    directory dir do
      action :create
      recursive true
      owner user
      group group
    end
  end
end

# define im installation directory
# if not specified, return default value based on im_install_mode 
def define_im_install_dir
  user = define_user
  case new_resource.im_install_mode
  when 'admin'
    im_install_dir = if new_resource.im_install_dir.nil?
                       '/opt/IBM/InstallationManager'
                     else
                       new_resource.im_install_dir
                     end
    im_install_dir
  when 'nonAdmin'
    im_install_dir = if new_resource.im_install_dir.nil?
                       '/home/' + user + '/IBM/InstallationManager'
                     else
                       new_resource.im_install_dir
                     end
    im_install_dir
  when 'group'
    im_install_dir = if new_resource.im_install_dir.nil?
                       '/home/' + user + '/IBM/InstallationManager_Group'
                     else
                       new_resource.im_install_dir
                     end
    im_install_dir
  end
end

# define im data directory
# if not specified, return default value based on im_install_mode 
def define_im_data_dir
  user = define_user
  case new_resource.im_install_mode
  when 'admin'
    im_data_dir = if new_resource.im_data_dir.nil?
                    '/var/ibm/InstallationManager'
                  else
                    new_resource.im_data_dir
                  end
    im_data_dir
  when 'nonAdmin'
    im_data_dir = if new_resource.im_data_dir.nil?
                    '/home/' + user + '/var/ibm/InstallationManager'
                  else
                    new_resource.im_data_dir
                  end
    im_data_dir
  when 'group'
    im_data_dir = if new_resource.im_data_dir.nil?
                    '/home/' + user + '/var/ibm/InstallationManager_Group'
                  else
                    new_resource.im_data_dir
                  end
    im_data_dir
  end
end

# define im shared directory
# if not specified, return default value based on im_install_mode 
def define_im_shared_dir
  user = define_user
  case new_resource.im_install_mode
  when 'admin'
    im_shared_dir = if new_resource.im_shared_dir.nil?
                      '/opt/IBM/IMShared'
                    else
                      new_resource.im_shared_dir
                    end
    im_shared_dir
  when 'nonAdmin', 'group'
    im_shared_dir = if new_resource.im_shared_dir.nil?
                      '/home/' + user + '/opt/IBM/IMShared'
                    else
                      new_resource.im_shared_dir
                    end
    im_shared_dir
  end
end

# define ibm log directory
# if not specified, return default value based on im_install_mode 
def define_ibm_log_dir
  user = define_user
  case new_resource.im_install_mode
  when 'admin'
    ibm_log_dir = if new_resource.ibm_log_dir.nil?
                      '/var/log/ibm_cloud'
                    else
                      new_resource.ibm_log_dir
                    end
    ibm_log_dir
  when 'nonAdmin', 'group'
    ibm_log_dir = if new_resource.ibm_log_dir.nil?
                      '/home/' + user + '/var/log/ibm_cloud'
                    else
                      new_resource.ibm_log_dir
                    end
    ibm_log_dir
  end
end

# define im folder permission 
def define_im_folder_permission
  case new_resource.im_install_mode
  when 'admin'
    im_folder_permission = '755'
    im_folder_permission
  when 'nonAdmin', 'group'
    im_folder_permission = '775'
    im_folder_permission
  end
end

# define workflow user
# if not specified, return default value based on im_install_mode 
# validate if specified user exists, meanwhile
def define_user
  case new_resource.im_install_mode
  when 'admin'
    user = if new_resource.user.nil?
             'root'
           else
             unless im_user_exists_unix?(new_resource.user)
               Chef::Log.fatal "User Name provided #{new_resource.user}, does not exist"
               raise "User Verification 1: User Name provided #{new_resource.user}, does not exist"
             end
             new_resource.user
           end
    user
  when 'nonAdmin', 'group'
    user = if new_resource.user.nil?
             Chef::Log.fatal "User Name not provided! Please provide the user that should be used to install your product"
             raise "User Name not provided! Please provide the user that should be used to install your product"
           else
             unless im_user_exists_unix?(new_resource.user)
               Chef::Log.fatal "User Name provided #{new_resource.user}, does not exist"
               raise "User Verification 1: User Name provided #{new_resource.user}, does not exist"
             end
             new_resource.user
           end
    user
  end
end

# define workflow group
# if not specified, return default value based on im_install_mode 
def define_group
  case new_resource.im_install_mode
  when 'admin'
    group = if new_resource.group.nil?
              'root'
            else
              new_resource.group
            end
    group
  when 'nonAdmin', 'group'
    group = if new_resource.group.nil?
              Chef::Log.fatal "Group not provided! Please provide the group that should be used to install your product"
              raise "Group not provided! Please provide the group that should be used to install your product"
            else
              new_resource.group
            end
    group
  end
end

# define im software repository
# download signed certificate for secure mode
def define_im_repo
  if new_resource.im_repo_nonsecureMode == "true" && new_resource.im_install_mode == "group"
    require 'net/http'
    uri = URI.parse(new_resource.sw_repo)
    download_self_signed_certificate
    new_host = self_signed_certificate_name
    im_repo = new_resource.sw_repo.gsub(uri.host, new_host.chomp)
  else
    im_repo = new_resource.sw_repo
  end
  im_repo
end

# define security parameters
# store credetials to master_password_file.txt
def define_security_params
  security_params = if new_resource.im_repo_user.nil?
                      ''
                    else
                      "-secureStorageFile /tmp/credential.store -masterPasswordFile /tmp/master_password_file.txt -preferences com.ibm.cic.common.core.preferences.ssl.nonsecureMode=#{new_resource.im_repo_nonsecureMode}"
                    end
  security_params
end

# define im repo password
def define_im_repo_password
  im_repo_password = ''
  encrypted_id = node['workflow']['vault']['encrypted_id']
  chef_vault = node['workflow']['vault']['name']
  unless chef_vault.empty?
    require 'chef-vault'
    im_repo_password = chef_vault_item(chef_vault, encrypted_id)['ibm']['im_repo_password']
    raise "No password found for IM repo user in chef vault \'#{chef_vault}\'" if im_repo_password.empty?
    Chef::Log.info "Found a password for IM repo user in chef vault \'#{chef_vault}\'"
  end
  im_repo_password
end

# generate storage file
def generate_storage_file
  im_repo = define_im_repo
  require 'securerandom'
  im_install_dir = define_im_install_dir
  user = define_user
  group = define_group
  im_repo_password = define_im_repo_password
  if ::File.exist?('/tmp/master_password_file.txt')
    Chef::Log.info("/tmp/master_password_file.txt exists. It will not be modified")
  else
    master_password_file = open('/tmp/master_password_file.txt', 'w')
    FileUtils.chown user, group, '/tmp/master_password_file.txt'
    master_password_file.write(SecureRandom.hex)
    master_password_file.close
  end
  if ::File.exist?('/tmp/credential.store')
    Chef::Log.info("/tmp/credential.store exists. It will not be modified")
  else
    cmd = "#{im_install_dir}/eclipse/tools/imutilsc saveCredential -url #{im_repo}/repository.xml -userName #{new_resource.im_repo_user} -userPassword \'#{im_repo_password}\' -secureStorageFile /tmp/credential.store -masterPasswordFile /tmp/master_password_file.txt -preferences com.ibm.cic.common.core.preferences.ssl.nonsecureMode=#{new_resource.im_repo_nonsecureMode} || true"
    cmd_out = run_shell_cmd(cmd, user)
    cmd_out.stderr.empty? && (cmd_out.stdout =~ /^Successfully saved the credential to the secure storage file./)
  end
end

# remove storage file
def remove_storage_file
  FileUtils.rm("/tmp/master_password_file.txt") if ::File.exist?('/tmp/master_password_file.txt')
  FileUtils.rm("/tmp/credential.store") if ::File.exist?('/tmp/credential.store')
end

# import self signed certificate
def import_self_signed_certificate
  Chef::Resource::RubyBlock.send(:include, IM::Helper)
  im_install_dir = define_im_install_dir
  user = define_user
  ruby_block "import_self_signed_certificate_#{new_resource}" do
    block do
      download_self_signed_certificate
      imutilsc = open(im_install_dir + '/eclipse/tools/imutilsc.ini', 'r')
      java_path = imutilsc.find { |line| line =~ /java/ }
      jre_bin_path = java_path.match("/java").pre_match
      shell_out!("cd #{jre_bin_path}; ./keytool -import -trustcacerts -keystore ../lib/security/cacerts -storepass changeit -noprompt -alias securerepo -file /tmp/secure-repo.pem || true")
    end
    only_if { im_installed?(im_install_dir, new_resource.im_version, user) }
  end
end

# download self signed certificate
def download_self_signed_certificate
  require 'net/http'
  require 'socket'
  require 'openssl'
  if ::File.exist?('/tmp/secure-repo.pem')
    Chef::Log.info("/tmp/secure-repo.pem exists. It will not be downloaded again")
  else
    uri = URI.parse(new_resource.sw_repo)
    tcp_client = TCPSocket.new(uri.host, uri.port)
    ssl_client = OpenSSL::SSL::SSLSocket.new(tcp_client)
    ssl_client.connect
    cert = OpenSSL::X509::Certificate.new(ssl_client.peer_cert)
    cert_file = open('/tmp/secure-repo.pem', 'w+')
    if cert_file.include? cert.to_pem
      Chef::Log.info "Self signed cert found in #{cert_file}"
    else
      cert_file.write(cert)
    end
    cert_file.close
  end
end

# return self signed certificate name
def self_signed_certificate_name
  require 'net/http'
  require 'socket'
  require 'openssl'
  uri = URI.parse(new_resource.sw_repo)
  tcp_client = TCPSocket.new(uri.host, uri.port)
  ssl_client = OpenSSL::SSL::SSLSocket.new(tcp_client)
  ssl_client.connect
  cert = OpenSSL::X509::Certificate.new(ssl_client.peer_cert)
  cert_name = cert.subject.to_a.find { |name, _, _| name == 'CN' }[1]
  etc_hosts = open('/etc/hosts', 'a+')
  if etc_hosts.include? "#{uri.host} #{cert_name}"
    Chef::Log.info "line #{uri.host} #{cert_name} found in /etc/hosts"
  else
    etc_hosts.write("#{uri.host} #{cert_name}")
  end
  etc_hosts.close
  cert_name
end

=begin
# TODO: extract following 2 methods to WorkflowHelper module
# create specified directories using specified user
def subdirs_to_create(dir, user)
  Chef::Log.info("Dir to create: #{dir}, user: #{user}")
  existing_subdirs = []
  remaining_subdirs = dir.split('/')
  remaining_subdirs.shift # get rid of '/'

  until remaining_subdirs.empty?
    Chef::Log.info("remaining_subdirs: #{remaining_subdirs.inspect}, existing_subdirs: #{existing_subdirs.inspect}")
    path = existing_subdirs.push('/' + remaining_subdirs.shift).join
    break unless ::File.exist?(path)
    raise "Path #{path} exists and is a file, expecting directory." unless ::File.directory?(path)
    # TODO: enable later
    #raise "Directory #{path} exists but is not traversable by #{user}." unless can_traverse?(user, path)
  end

  new_dirs = [existing_subdirs.join]
  new_dirs.push(new_dirs.last + '/' + remaining_subdirs.shift) until remaining_subdirs.empty?
  new_dirs
end
=end

# determine if can traverse or not?
#def can_traverse?(user, path)
#  return true if user == 'root'
#  byme = ::File.stat(path).uid == -> { ::Etc.getpwnam(user).uid } && ::File.stat(path).mode & 64 == 64 # owner has x
#  byus = ::File.stat(path).gid == -> { ::Etc.getpwnam(user).gid } && ::File.stat(path).mode & 8 == 8 # group has x
#  byall = ::File.stat(path).mode & 1 == 1 # other has x
#  byme || byus || byall
#end
