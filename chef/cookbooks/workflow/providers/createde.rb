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
# Provider:: workflow_createde
#

use_inline_resources

#Create Action prepare
action :prepare do
  if @current_resource.database_created
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  elsif new_resource.cluster_type = 'SingleCluster'
    converge_by("Prepare - createDatabase #{@new_resource}") do
      # TODO: no handling for case that only one or two of the databases are created.

      # create database - BPMDB/PDWDB/COMMONDB
      createdb_template = 'config/db2/createDatabase.sql.erb'
      if new_resource.product_type == 'AdvancedOnly'
        createdb_template = 'config/db2/createDatabase_AdvancedOnly.sql.erb'
      end
      Chef::Log.info("createdb_template: #{createdb_template}")

      # make sure db2 is started
      # TODO: seems db2 will be started always, if yes, remove this.
      execute "start_db2" do
        command "su - #{new_resource.db_alias_user} -c \"db2start\""
        ignore_failure true
      end

      silent_create_database_sql_abspath = "#{new_resource.install_dir}/bin/createDatabase.sql"
      Chef::Log.info("silent_create_database_sql_abspath: #{silent_create_database_sql_abspath}")

      template silent_create_database_sql_abspath do
        source createdb_template
        variables(
          :BPMDB_NAME => new_resource.db2_bpmdb_name,
          :PDWDB_NAME => new_resource.db2_pdwdb_name,
          :CMNDB_NAME => new_resource.db2_cmndb_name,
          :DB2_USER => new_resource.db2_schema
        )
      end

      # create database before creating environment
      execute "execute createDatabase" do
        command "su - #{new_resource.db_alias_user} -c \"db2 -tvf #{silent_create_database_sql_abspath}\""
        not_if { processdb_created? }
      end

      # Prepare for CPE if product type is not 'AdvancedOnly'
      if new_resource.product_type != 'AdvancedOnly'
        # generate createDatabase_ECM sql
        cpe_createdb_template = 'config/db2/createDatabase_ECM.sql.erb'
        cpe_silent_create_database_sql_abspath = "#{new_resource.install_dir}/bin/createDatabase_ECM.sql"
        Chef::Log.info("cpe_createdb_template: #{cpe_createdb_template}, cpe_silent_create_database_sql_abspath: #{cpe_silent_create_database_sql_abspath}")

        template cpe_silent_create_database_sql_abspath do
          source cpe_createdb_template
          variables(
            :DB2_DATA_DIR => new_resource.db2_data_dir,
            :CPEDB_NAME => new_resource.db2_cpedb_name,
            :DB2_USER => new_resource.db_alias_user
          )
        end

        # generate createTablespace_Advanced sql
        cpe_create_tablespace_template = 'config/db2/createTablespace_Advanced.sql.erb'
        cpe_silent_create_tablespace_sql_abspath = "#{new_resource.install_dir}/bin/createTablespace_Advanced.sql"
        Chef::Log.info("cpe_create_tablespace_template: #{cpe_create_tablespace_template}, cpe_silent_create_tablespace_sql_abspath: #{cpe_silent_create_tablespace_sql_abspath}")

        template cpe_silent_create_tablespace_sql_abspath do
          source cpe_create_tablespace_template
          variables(
            :DB2_DATA_DIR => new_resource.db2_data_dir,
            :CPEDB_NAME => new_resource.db2_cpedb_name,
            :DB2_USER => new_resource.db_alias_user
          )
        end

        # generate createDatabase_ECM sh
        cpedb_sh_template = 'config/db2/createDatabase_ECM.sh.erb'
        cpedb_silent_sh_abspath = "#{new_resource.install_dir}/bin/createDatabase_ECM.sh"
        Chef::Log.info("cpedb_sh_template: #{cpedb_sh_template}, cpedb_silent_sh_abspath: #{cpedb_silent_sh_abspath}")

        template cpedb_silent_sh_abspath do
          source cpedb_sh_template
          variables(
            :DB2_DATA_DIR => new_resource.db2_data_dir,
            :CPEDB_NAME => new_resource.db2_cpedb_name,
            :CREATE_DB_ECM_SQL => cpe_silent_create_database_sql_abspath,
            :CREATE_TSPACE_ECM_SQL => cpe_silent_create_tablespace_sql_abspath
          )
          mode '0755'
        end

        # create case DB folders & create CPE database/tablespace/schema
        execute "execute createCPEDB" do
          command "su - #{new_resource.db_alias_user} -c \"#{cpedb_silent_sh_abspath}\""
          not_if { cpedb_created? }
        end
      end

      # TODO: evidence
    end  
  else
    # TODO: the case that the db2 database is not in local environment
    # Theoretically, doing nothing, the DBA need create database manually before create DE.
  end
end

#Create Action create
action :create do
  if @current_resource.de_created
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  else
    converge_by("create #{@new_resource}") do
      install_dir = new_resource.install_dir

      silent_createde_propfile_abspath = "#{install_dir}/bin/#{new_resource.createde_property_file}"
      Chef::Log.info("create - silent_createde_propfile_abspath: #{silent_createde_propfile_abspath}")

      template silent_createde_propfile_abspath do
        source 'config/' + new_resource.createde_property_file + '.erb'
        variables(
          :DEADMIN_ALIAS_USER => new_resource.deadmin_alias_user,
          :DEADMIN_ALIAS_PWD => new_resource.deadmin_alias_password,
          :BPMDB_ALIAS_USER => new_resource.db_alias_user,
          :BPMDB_ALIAS_PWD => new_resource.db_alias_password,
          :CELLADMIN_ALIAS_USER => new_resource.celladmin_alias_user,
          :CELLADMIN_ALIAS_PWD => new_resource.celladmin_alias_password,
          :DMGR_HOST_NAME => new_resource.dmgr_hostname,
          :BAW_INSTALL_PATH => install_dir,
          :NODE_HOST_NAME => new_resource.node_hostname,
          :DB2_HOST_NAME => new_resource.db2_hostname,
          :DB2_PORT => new_resource.db2_port,
          :BAW_DB_SCHEMA => new_resource.db2_schema,
          :DB2_SHAREDDB_NAME => new_resource.db2_shareddb_name,
          :DB2_BPMDB_NAME => new_resource.db2_bpmdb_name,
          :DB2_PDWDB_NAME => new_resource.db2_pdwdb_name,
          :DB2_CPEDB_NAME => new_resource.db2_cpedb_name,
          :DB2_DATA_DIR => new_resource.db2_data_dir,
          :DB2_CELLONLY_NAME => new_resource.db2_cellonlydb_name,
          # PS only variables
          :PS_PURPOSE => new_resource.ps_environment_purpose,
          :PS_OFFLINE => new_resource.ps_offline,
          :PS_PC_TRANSPORT_PROTOCOL => new_resource.ps_pc_transport_protocol,
          :PS_PC_HOSTNAME => new_resource.ps_pc_hostname,
          :PS_PC_PORT => new_resource.ps_pc_port,
          :PS_PC_CONTEXTROOT_PREFIX => new_resource.ps_pc_contextroot_prefix,
          :PC_ALIAS_USER => new_resource.ps_pc_alias_user,
          :PC_ALIAS_PWD => new_resource.ps_pc_alias_password
        )
      end

      workflow_user = node['workflow']['runas_user']
      workflow_group = node['workflow']['runas_group']

      # Run config command to create topology
      cmd = "./BPMConfig.sh -create -de #{silent_createde_propfile_abspath}"
      # Chef 12+ problem with OS detection. Replacing C.UTF-8 with en_US"
      cmd = "export LANG=en_US; export LANGUAGE=en_US\:; export LC_ALL=en_US; ./BPMConfig.sh -create -de #{silent_createde_propfile_abspath}" if (node['platform_family'] == "debian")
      execute "create_de_#{new_resource.product_type}_#{new_resource.deployment_type}" do

        # Install the 64bit directly for that only 64bit OS is supported by Workflow, if need, extract and allow install 32bit for 32bit OS.
        cwd "#{install_dir}/bin"
        command cmd
        user workflow_user
        group workflow_group
        not_if { createde_success? }
      end

      # TODO: evidence
    end
  end
end

#Create Action start
# TODO: by now, support start after createde only. This can't be used to start DE after first-time
# If want to support, need find other flag to know if DE is started currently.
action :start do
  # TODO: for applying ifix, need restart DE. And this depends on that we change the determination if DE is started.
  if @current_resource.de_started
    Chef::Log.info "#{@new_resource} already exists - nothing to do."
  else
    converge_by("start #{@new_resource}") do

      silent_createde_propfile_abspath = "#{new_resource.install_dir}/bin/#{new_resource.createde_property_file}"
      Chef::Log.info("start - silent_createde_propfile_abspath: #{silent_createde_propfile_abspath}")

      workflow_user = node['workflow']['runas_user']
      workflow_group = node['workflow']['runas_group']

      # Run config command to start topology
      cmd = "./BPMConfig.sh -start #{silent_createde_propfile_abspath}"
      # Chef 12+ problem with OS detection. Replacing C.UTF-8 with en_US"
      cmd = "export LANG=en_US; export LANGUAGE=en_US\:; export LC_ALL=en_US; ./BPMConfig.sh -start #{silent_createde_propfile_abspath}" if (node['platform_family'] == "debian")
      # start DE
      execute "start_de_#{new_resource.product_type}_#{new_resource.deployment_type}" do

        # Install the 64bit directly for that only 64bit OS is supported by Workflow, if need, extract and allow install 32bit for 32bit OS.
        cwd "#{new_resource.install_dir}/bin"
        command cmd
        user workflow_user
        group workflow_group
        not_if { startde_success? }
      end

      # TODO: evidence
    end
  end
end

# If the database is created
def database_created?
  if new_resource.product_type == 'AdvancedOnly'
    processdb_created?
  else
    processdb_created? && cpedb_created?
  end
end

# If the process related database is created
def processdb_created?
  cmn_cmd_out = shell_out!("su - #{new_resource.db_alias_user} -c \"db2 list db directory | grep #{new_resource.db2_cmndb_name} || true\"")
  cmndb_created = cmn_cmd_out.stderr.empty? && (cmn_cmd_out.stdout =~ /#{new_resource.db2_cmndb_name}/)
  if new_resource.product_type == 'AdvancedOnly'
    cmndb_created
  else
    bpm_cmd_out = shell_out!("su - #{new_resource.db_alias_user} -c \"db2 list db directory | grep #{new_resource.db2_bpmdb_name} || true\"")
    bpmdb_created = bpm_cmd_out.stderr.empty? && (bpm_cmd_out.stdout =~ /#{new_resource.db2_bpmdb_name}/)
    pdw_cmd_out = shell_out!("su - #{new_resource.db_alias_user} -c \"db2 list db directory | grep #{new_resource.db2_pdwdb_name} || true\"")
    pdwdb_created = pdw_cmd_out.stderr.empty? && (pdw_cmd_out.stdout =~ /#{new_resource.db2_pdwdb_name}/)

    bpmdb_created && pdwdb_created && cmndb_created
  end    
end

# If the cpe related database is created
def cpedb_created?
    cpedb_cmd_out = shell_out!("su - #{new_resource.db_alias_user} -c \"db2 list db directory | grep #{new_resource.db2_cpedb_name} || true\"")
    cpedb_created = cpedb_cmd_out.stderr.empty? && (cpedb_cmd_out.stdout =~ /#{new_resource.db2_cpedb_name}/)

    cpedb_created
end

# If createde action is executed successfully
def createde_success?
  silent_createde_propfile_abspath = "#{new_resource.install_dir}/bin/#{new_resource.createde_property_file}"
  str_createde_suc = "The 'BPMConfig.sh -create -de #{silent_createde_propfile_abspath}' command completed successfully."
  createde_cmd_out = shell_out!("grep \"#{str_createde_suc}\" #{new_resource.install_dir}/logs/config -r || true")
  createde_cmd_out.stderr.empty? && (createde_cmd_out.stdout =~ /#{str_createde_suc}/)
end

# If startde action is executed successfully
def startde_success?
  silent_createde_propfile_abspath = "#{  new_resource.install_dir}/bin/#{new_resource.createde_property_file}"
  str_startde_suc = "The 'BPMConfig.sh -start #{silent_createde_propfile_abspath}' command completed successfully."
  startde_cmd_out = shell_out!("grep \"#{str_startde_suc}\" #{new_resource.install_dir}/logs/config -r || true")
  startde_cmd_out.stderr.empty? && (startde_cmd_out.stdout =~ /#{str_startde_suc}/)
end

#Override Load Current Resource
def load_current_resource
  Chef.event_handler do
    on :run_failed do
      HandlerSensitiveFiles::Helper.new.remove_sensitive_files_on_run_failure
    end
  end

  @current_resource = Chef::Resource.resource_for_node(:workflow_createde, node).new(@new_resource.name)
  #@current_resource = Chef::Resource::WorkflowInstall.new(@new_resource.name)

  # TODO: check if the databases are created locally for SingleCluster only.
  if new_resource.cluster_type = 'SingleCluster'
    @current_resource.database_created = database_created?
  end


  @current_resource.de_created = createde_success?
  @current_resource.de_started = startde_success?

=begin
  str_createde_suc = "The 'BPMConfig.sh -create -de #{silent_createde_propfile_abspath}' command completed successfully."
  createde_cmd_out = shell_out!("grep \"#{str_createde_suc}\" #{new_resource.install_dir}/logs/config -r || true")
  @current_resource.de_created = createde_cmd_out.stderr.empty? && (createde_cmd_out.stdout =~ /#{str_createde_suc}/)

  str_startde_suc = "The 'BPMConfig.sh -start #{silent_createde_propfile_abspath}' command completed successfully."
  startde_cmd_out = shell_out!("grep \"#{str_startde_suc}\" #{new_resource.install_dir}/logs/config -r || true")
  @current_resource.de_started = startde_cmd_out.stderr.empty? && (startde_cmd_out.stdout =~ /#{str_startde_suc}/)
=end

=begin
  im_install_dir = define_im_install_dir
  im_repo = define_im_repo
  user = define_user
  if new_resource.im_repo_user.nil?
    Chef::Log.info "im_repo_user not provided. Please make sure your IM repo is not secured.If your IM repo is secured you must provide im_repo_user and configure your chef vault for password"
  elsif im_installed?(im_install_dir, @new_resource.im_version, user)
    generate_storage_file
  end
  security_params = define_security_params

  @current_resource = Chef::Resource.resource_for_node(:workflow_install, node).new(@new_resource.name)
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
  #@current_resource.fp_installed = im_fixpack_installed?(im_install_dir, im_repo, security_params, node['im']['fixpack_offering_id'] + '_' + @new_resource.im_version, user)
  @current_resource.installed = ibm_installed?(im_install_dir, @new_resource.offering_id, @new_resource.offering_version, user)
  remove_storage_file
=end
end