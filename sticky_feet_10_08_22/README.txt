Sticky Feet

This program allows you to observe the process of evolution as it unfolds
in a simulated environment.  A simulation begins with 100 virtual
creatures.  At the start, just one of these creatures can crawl.  This
single moving creature will eat the unmoving ones by piercing their hearts
(red circles) with its mouth (an open black circle).  Each time that one
creature eats another, the winner is copied.  This means that soon
there are many moving creatures.  Sometimes a creature is copied with
mutation, which means that the newly born creature will be slightly
different than its parent creature.  This new creature may be either more
or less successful at competing with others.  Creatures that are more
successful at between-creature encounters become more numerous over time.

The program is written in the Processing language, which is a flavor of
Java that has additional routines for ease of use in graphics.  Processing
is available on many platforms, including Windows, Mac OS X, and Linux.
Processing can be downloaded and installed in a matter of minutes.  Visit
www.processing.org for details.

The Sticky Feet evolutionary simulation program is more fully described in
the following paper:

"Sticky Feet: Evolution in a Multi-Creature Physical Simulation"
Greg Turk
Artificial Life XII, August 19-23, 2010, Odense, Denmark

The program responds to several key stroke commands:

<space> - stop and start the simulation
s - take one simulation step
i - re-initialize the simulation (just one moving creature)

p - save a picture of the current window to disk (image name frame-####.png)
R - read creatures from the file "creatures.txt"
r - read creatures from file (pop-up menu)
w - write creatures to a file in a sub-directory named run##

d - toggle he drawing of information such as timestep number
t - toggle drawing of creature "tails"
x - toggle drawing of creature sensors

q - quit the program

The program saves the state of the creatures to a file every 200,000 time
steps.  These state files are in automatically created sub-directories that
are called run00, run01, and so on.  Using the "r" command, these files
can be read back into the program to review the history of the simulation.
The automatic file writing behavior can be turned off by setting
auto_write_flag to false.

Some of the program parameters that can be modified are:

sx, sy - window size
target_creature_count - number of creatures in the simulation
mutation_rate - how often creature mutation occurs
auto_write_flag - whether to automatically write out creature files
auto_write_count - number of time steps between automatic creature file writing

Feel free to modify this program and to use it for any non-commerical
purpose.  One of the best ways to learn about programming is to make
changes to someone else's code.

If you are a newcomer to programming in Processing, you might try playing
around with the display routines of the creature, such as modifying the
size of the lines and circles or making each line segment a different
color.  Another potential modification is to make parts of the creatures
change color when they sense the presence of another creature.  If you are
an expert in simulation, you might consider modifications such as adding
angular springs.  Another possibility is to change the reproduction rules
to include mating between creatures.  Yet another idea is to allow a
user to hand-draw a creature (similar to the program Sodaplay).

Greg Turk
August 18, 2010

