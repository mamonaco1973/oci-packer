# IAM instance roles are not needed on OCI for this workload.
# Instance management uses direct SSH (key from 01-infrastructure) rather
# than AWS Systems Manager, which required an IAM role + instance profile.
