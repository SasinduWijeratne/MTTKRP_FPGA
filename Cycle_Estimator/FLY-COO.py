import sys
import math

def proposed_memory_layout(file_name, dim, num_cache_lines, associativity, width_cache_line, size_matrix_rank, size_matrix_element): # All the function inputs are power of 2	
# put dimensions as dim
	dim = dim-1
	num_elements_per_cache_line = width_cache_line/(size_matrix_rank*size_matrix_element)
	fpga_bit_width = 512/8
	numberofpe = 8

	cache_address = [[[-1 for i in range(associativity)] for j in range(num_cache_lines)] for k in range(dim)]
	# cache_time = [[[-1 for i in range(associativity)] for j in range(num_cache_lines)] for k in range(dim)]

	coordinates = [0 for i in range(dim)]
	num_cache_hits = 0
	num_cache_miss = 0
	tensor_accesses = 0
	prev_misses_track = 0

	with open(file_name) as infile:
		infile.readline()
		for line in infile:
			int_vals = [int(i) for i in line.split(',')]
			tensor_accesses += 1

			for dimension0 in range(dim):
				coordinates[dimension0] = int_vals[dimension0+1]

			temp_cache_miss = 0
			prev_misses_track = prev_misses_track +1
			for dimension in range(dim):
				coo = int(coordinates[dimension]*fpga_bit_width)

				dim_cache_addr =  cache_address[dimension]
				# dim_cache_time = cache_time[dimension]

				bit_num_cache_lines = int(math.log2(num_cache_lines))
				bit_width_cache_line_pl_associativity = int(math.log2(width_cache_line)) + int(math.log2(associativity))

				temp_coo = coo >> bit_width_cache_line_pl_associativity

				tag = temp_coo >> bit_num_cache_lines
				cache_addr = temp_coo & ((1 << bit_num_cache_lines) -1)

				if(tag in dim_cache_addr[cache_addr]):
					cache_address[dimension][cache_addr].remove(tag)
					cache_address[dimension][cache_addr].insert(0, tag)

					# num_cache_hits = num_cache_hits + 1
					# print("Cache HIT! ",coo, cache_addr, tag, cache_address[dimension][cache_addr])

				else:
					cache_address[dimension][cache_addr].insert(0, tag)
					cache_address[dimension][cache_addr].pop()

					temp_cache_miss = temp_cache_miss +1
					prev_misses_track = 0

					# num_cache_miss = num_cache_miss + 1
					# print("Cache MISS!",coo, cache_addr, tag, cache_address[dimension][cache_addr])
			if(temp_cache_miss == 0):
				if(prev_misses_track >= numberofpe):
					num_cache_hits = num_cache_hits + 1
			else:
				num_cache_miss = num_cache_miss + temp_cache_miss

	print("semi-alto_memory_layout :: Total Only Cache Accesses: ", num_cache_hits)
	print("semi-alto_memory_layout :: Total Main Memory Accesses: ", num_cache_miss)
	print("semi-alto_memory_layout :: Total tensor accesses: ", tensor_accesses)

proposed_memory_layout(str(sys.argv[1]), int(sys.argv[2]), 1024, 4, 512, 16, 32)





