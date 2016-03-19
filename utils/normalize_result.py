#!/usr/bin/env python
import fileinput


for line in fileinput.input():
    (u1, u2, sim) = line.split()
    if u2 <= u1:
        (u1, u2) = (u2, u1)

    print u1, u2
