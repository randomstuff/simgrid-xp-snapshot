# Experiments for snapshotting strategies for SimGridMC

Strategies:

* plain snapshots

* KSM enabled snapshots

* per-page snapshots

* per-page snapshots with soft-dirty tracking

Files:

* snapshot.org

* snapshot.sh, script for (re)producing the experiment.

  It is tangled from snapshot.org with emacs `org-babel-tangle`.

* snapshot.pl, produce tabular data (TSV output) from the stdout of the script

* results/*.tsv, results as TSV files

Usage:

~~~sh
# Submit to Grid5000:
./snapshot.sh --submit nancy.grid5000.fr

#
ssh nancy.grid5000.fr cat OAR.$jobid.stdout | ./snapshot.pl
~~~

or run from a VM:

~~~sh
./snapshot.sh > snapshot.stdout
cat snapshot.stdout | ./snapshot.pl | column -ts $'\t' > snapshot.txt
~~~
