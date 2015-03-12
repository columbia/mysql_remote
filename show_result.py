import sys

file = open(sys.argv[1], 'r')
for line in file:
        components = line.strip().split("\t")
        sum = float(components[3]) + float(components[4]) + float(components[5])
        print sum / 3
