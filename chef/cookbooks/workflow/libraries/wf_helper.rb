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

# Cookbook Name:: workflow 
# Library:: im_helper
#
# <> library: Workflow helper
# <> Library Functions for the Workflow Cookbook

include Chef::Mixin::ShellOut

module WF
  # Helper module
  module Helper
    # get sub directories
    def subdirs_to_create(dir, user)
      Chef::Log.info("Dir to create: #{dir}, user: #{user}")
      existing_subdirs = []
      remaining_subdirs = dir.split('/')
      remaining_subdirs.shift # get rid of '/'

      until remaining_subdirs.empty?
        Chef::Log.info("remaining_subdirs: #{remaining_subdirs.inspect}, existing_subdirs: #{existing_subdirs.inspect}")
        path = existing_subdirs.push('/' + remaining_subdirs.shift).join
        break unless File.exist?(path)
        raise "Path #{path} exists and is a file, expecting directory." unless File.directory?(path)
        raise "Directory #{path} exists but is not traversable by #{user}." unless can_traverse?(user, path)
      end

      new_dirs = [existing_subdirs.join]
      new_dirs.push(new_dirs.last + '/' + remaining_subdirs.shift) until remaining_subdirs.empty?
      new_dirs
    end

    # determine if can traverse or not?
    def can_traverse?(user, path)
      return true if user == 'root'
      byme = File.stat(path).uid == -> { Etc.getpwnam(user).uid } && File.stat(path).mode & 64 == 64 # owner has x
      byus = File.stat(path).gid == -> { Etc.getpwnam(user).gid } && File.stat(path).mode & 8 == 8 # group has x
      byall = File.stat(path).mode & 1 == 1 # other has x
      byme || byus || byall
    end

  end
end