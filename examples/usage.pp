# inside one of your puppet manifests...

# after each puppet run change the input in a sequence of your choosing...
fsm::transition { 'water':
	input => 'solid',
	#input => 'liquid',
	#input => 'gas',
	#input => 'liquid',
	#input => 'solid',
	#input => 'gas',
	#input => 'plasma',
	#input => 'gas',
	#input => 'solid',

	#chain_maxlength => 4,	# optionally limit the max size of the stack
}

# NOTE: multiple fsm::transition types can be also used simultaneously...
fsm::transition { 'hydrogen':
	input => 'liquid',
	#input => 'gas',
	#input => 'plasma',
	#input => 'gas',
}

