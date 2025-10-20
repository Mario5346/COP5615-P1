# Chord Protocol

## Team members:

Srikar Tadeparti,
Mario Ponte Garofalo

Team 65

## What is working

You can run the code using the following command:

`gleam run project3 <nodes> <requests>`

For example:

`gleam run project3 10 1`

Everything seems to be working as expected, though the average number of hops seems to be a bit lower than expected. Since we are not deleting nodes in our implementation, we left did not implement the check predecessor function as it is not necessary if nodes do not leave or fail.

## Largest tested values

We managed to work with numbers of up to 20 requests with 500 nodes, but due to time constraints could not test bigger, more time consumming values