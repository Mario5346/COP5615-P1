
# Project 2: Gossip Algorithms

## Team members:

Srikar Tadeparti,
Mario Ponte

## What is working

You can run the code using the following command:

`gleam run project2 <nodes> <topology> <algorithm>`

For example:
`gleam run project2 27 3D push-sum`


All 4 topologies work with both algorithms. Feel free to modify the parameters. 3D rounds up to the next highest number of nodes.
Eg. a value of 10 would give 27 nodes.


## Largest tested values

Imp3D and 3D: 64 nodes on both push-sum and gossip. Our program seemed to inexplicably run forever if we tried to use any more than 64 nodes for these 2 topologies regardless of algorithm despite having no issues building the topology itself.

Full: 5000+ nodes seem to work for push-sum, but take so long sometimes that it is hard to tell if it is actually working as intended due to random chance, especially for gossip.

Line: For the Gossip algorithm we managed to run with over 100,000 nodes almost instantaneously! (probably not a good sign), as for push sum, we got up to 5000 nodes with little problem
