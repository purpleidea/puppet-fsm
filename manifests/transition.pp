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

define fsm::transition(
	$input = '',
	$chain_maxlength = '-1'	# unlimited
) {
	include fsm::transition::base
	include fsm::vardir
	#$vardir = $::fsm::vardir::module_vardir	# with trailing slash
	$vardir = regsubst($::fsm::vardir::module_vardir, '\/$', '')

	file { "${vardir}/transition/${name}/":
		ensure => directory,	# make sure this is a directory
		recurse => true,	# recurse into directory
		purge => false,		# don't purge unmanaged files
		force => false,		# don't purge subdirs and links
		require => File["${vardir}/transition/"],
	}

	#notify { "fsm-${name}":
	#	message => 'Running puppet-fsm with ${name}',
	#}

	$valid_input = "${input}" ? {
		'solid' => 'solid',
		'liquid' => 'liquid',
		'gas' => 'gas',
		'plasma' => 'plasma',
		default => '',
	}
	if "${valid_input}" == '' {
		fail('Specify a valid input state, eg: solid, liquid, gas or plasma.')
	}
	$last = getvar("fsm_transition_${name}")	# fact !
	$valid_last = "${last}" ? {
		'solid' => 'solid',
		'liquid' => 'liquid',
		'gas' => 'gas',
		'plasma' => 'plasma',
		# initialize the $last var to match the $input if it's empty...
		'' => "${valid_input}",
		default => '',
	}
	if "${valid_last}" == '' {
		fail('Previous state is invalid.')	# fact was tampered with
	}

	$chain_fact = getvar("fsm_transition_chain_${name}")	# fact !
	$fullchain = split("${chain_fact}", ',')
	$chain = "${chain_maxlength}" ? {
		'-1' => $fullchain,	# unlimited
		#default => split(inline_template('<%= fullchain[0,chain_maxlength.to_i.abs].join(",") %>'), ','),
		default => split(inline_template('<%= fullchain[[fullchain.size-chain_maxlength.to_i.abs,0].max,chain_maxlength.to_i.abs].join(",") %>'), ','),
	}

	# from: https://en.wikipedia.org/wiki/File:Phase_change_-_en.svg
	# solid
	#	-> solid:	noop!
	#	-> liquid:	melting
	#	-> gas:		sublimation
	#	-> plasma:	error!
	# liquid
	#	-> solid:	freezing
	#	-> liquid:	noop!
	#	-> gas:		vaporization
	#	-> plasma:	error!
	# gas
	#	-> solid:	deposition
	#	-> liquid:	condensation
	#	-> gas:		noop!
	#	-> plasma:	ionization
	# plasma
	#	-> solid:	error!
	#	-> liquid:	error!
	#	-> gas:		recombination
	#	-> plasma:	noop!

	$transition = "${valid_last}" ? {
		'solid' => "${valid_input}" ? {
			'solid' => true,
			'liquid' => 'melting',
			'gas' => 'sublimation',
			'plasma' => false,
			default => '',
		},
		'liquid' => "${valid_input}" ? {
			'solid' => 'freezing',
			'liquid' => true,
			'gas' => 'vaporization',
			'plasma' => false,
			default => '',
		},
		'gas' => "${valid_input}" ? {
			'solid' => 'deposition',
			'liquid' => 'condensation',
			'gas' => true,
			'plasma' => 'ionization',
			default => '',
		},
		'plasma' => "${valid_input}" ? {
			'solid' => false,
			'liquid' => false,
			'gas' => 'recombination',
			'plasma' => true,
			default => '',
		},
		default => '',
	}

	if size($chain) >= 3 {
		notify { "fsm-${name}-previous":
			message => sprintf("The last three states were: %s.", inline_template('<%= chain[[chain.size-3,0].max,3].join(", ") %>')),
		}
	}
	case $transition {
		true: {
			# no transition... (noop)
		}
		false: {
			fail("Can't transition from: ${valid_last} to: ${valid_input}.")
		}
		'': {
			# error: the physics doesn't exist yet :P
			# this should only happen if there's a bug in the table
			fail('You must specify a valid state.')
		}
		default: {
			# do the transition!
			notify { "fsm-${name}-transition":
				message => "fsm: The phase transition of: ${name} from: ${valid_last} to: ${valid_input} is called: ${transition}.",
				before => Exec["fsm-transition-${name}"],	# important!
			}
		}
	}

	$f = "${vardir}/transition/${name}/state"
	$c = "${vardir}/transition/${name}/chain"
	$diff = "/usr/bin/test '${valid_input}' != '${valid_last}'"
	$truncate = "${chain_maxlength}" ? {
		'-1' => '',	# unlimited
		#default => sprintf("&& /bin/sed -i '%d,$ d' ${c}", inline_template('<%= chain_maxlength.to_i.abs+1 %>')),
		default => sprintf(" && (/bin/grep -v '^$' ${c} | /usr/bin/tail -%d | /usr/bin/tee ${c})", inline_template('<%= chain_maxlength.to_i.abs %>')),
	}

	# TODO: future versions should pickle (but with yaml)
	exec { "/bin/echo '${valid_input}' > '${f}'":
		logoutput => on_failure,
		onlyif => "/usr/bin/test ! -e '${f}' || ${diff}",
		require => File["${vardir}/transition/${name}/"],
		alias => "fsm-transition-${name}",
	}

	# NOTE: there's no reason we can't keep a stack of past transitions, and
	# load them in as a list...
	exec { "/bin/echo '${valid_input}' >> '${c}'${truncate}":
		logoutput => on_failure,
		onlyif => "/usr/bin/test ! -e '${c}' || ${diff}",
		require => [
			File["${vardir}/transition/${name}/"],
			# easy way to ensure the transition types don't need to
			# add a before to both exec's since this one follows it
			Exec["fsm-transition-${name}"],
		],
		alias => "fsm-transition-chain-${name}",
	}
}

