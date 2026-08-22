# copy phase 1 atomicity

The existing transactional directory replacement primitive in `scripts/lib_backup.sh` must be used by `copy_phase1()` for existing config directories.

Invariant: prepare the replacement before moving the live destination; preserve the old destination as a backup; restore the backup if the final replacement fails.
