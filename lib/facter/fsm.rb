# Simple fsm module by James
# Copyright (C) 2012-2013+ James Shubin
# Written by James Shubin <james@shubin.ca>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'facter'

key = 'state'
regexp = /^[a-z]{1}[a-z0-9]{0,}$/

# find the module_vardir
dir = Facter.value('puppet_vardirtmp')		# nil if missing
if dir.nil?					# let puppet decide if present!
	dir = Facter.value('puppet_vardir')
	if dir.nil?
		var = nil
	else
		var = dir.gsub(/\/$/, '')+'/'+'tmp/'	# ensure trailing slash
	end
else
	var = dir.gsub(/\/$/, '')+'/'
end

if var.nil?
	# if we can't get a valid vardirtmp, then we can't collect...
	valid_dir = nil
else
	module_vardir = var+'fsm/'
	valid_dir = module_vardir.gsub(/\/$/, '')+'/'
	transition_dir = valid_dir+'transition/'
end

found = {}
chain = {}

if not(transition_dir.nil?) and File.directory?(transition_dir)
	# loop through each sub directory in the fsm::transition type
	Dir.glob(transition_dir+'*').each do |d|
		n = File.basename(d)	# should be the fsm::transition name
		if n.length > 0 and regexp.match(n)

			f = d.gsub(/\/$/, '')+'/state'	# full file path
			if File.exists?(f)
				# TODO: future versions should unpickle (but with yaml)
				v = File.open(f, 'r').read.strip	# read into str
				if v.length > 0 and regexp.match(v)
					found[n] = v
				end
			end

			f = d.gsub(/\/$/, '')+'/chain'	# full file path
			if File.exists?(f)
				chain[n] = []	# initialize empty array
				File.readlines(f).each do |l|
					l = l.strip	# clean off /n's
					# TODO: future versions should unpickle (but with yaml)
					if l.length > 0 and regexp.match(l)
						chain[n].push(l)
					end
				end
			end

		end
	end
end

found.keys.each do |x|
	Facter.add('fsm_transition_'+x) do
		#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
		setcode {
			found[x]
		}
	end

	if chain.key?(x)
		Facter.add('fsm_transition_chain_'+x) do
			#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
			setcode {
				chain[x].join(',')
			}
		end
	end
end

# list of fsm_transition fact names
Facter.add('fsm_transitions') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		found.keys.sort.collect {|x| 'fsm_transition_'+x }.join(',')
	}
end

Facter.add('fsm_transition_chains') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		(found.keys & chain.keys).sort.collect {|x| 'fsm_transition_chain_'+x }.join(',')
	}
end

Facter.add('fsm_debug') do
	#confine :operatingsystem => %w{CentOS, RedHat, Fedora}
	setcode {
		'this fsm module is experimental...'
	}
end

