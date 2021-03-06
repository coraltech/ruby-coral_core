
home = File.dirname(__FILE__)

$:.unshift(home) unless
  $:.include?(home) || $:.include?(File.expand_path(home))
  
#-------------------------------------------------------------------------------
  
require 'rubygems'

#---

# Include core
[ :interface, :core ].each do |name| 
  require File.join('coral_core', name.to_s + ".rb") 
end

# Include utilities
[ :git, :data, :disk, :shell ].each do |name| 
  require File.join('coral_core', 'util', name.to_s + ".rb") 
end

# Include Git overrides
Dir.glob(File.join(home, 'coral_core', 'util', 'git', '*.rb')).each do |file|
  require file
end

# Include data model
[ :event, :command, :repository, :memory ].each do |name| 
  require File.join('coral_core', name.to_s + ".rb") 
end

# Include specialized events
Dir.glob(File.join(home, 'coral_core', 'event', '*.rb')).each do |file|
  require file
end

#*******************************************************************************
# Coral Core Library
#
# This provides core data elements and utilities used in the Coral gems.
#
# Author::    Adrian Webb (mailto:adrian.webb@coraltech.net)
# License::   GPLv3
module Coral
  
  VERSION = File.read(File.join(File.dirname(__FILE__), '..', 'VERSION'))
 
end