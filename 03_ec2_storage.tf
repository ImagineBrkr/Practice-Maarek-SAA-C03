# EBS Volumes


resource "aws_ebs_volume" "ebs_volume_web_server_secondary" {
  # It must be on the same AZ as the instance
  availability_zone = "us-east-1a"
  size              = 40
  type              = "gp2"
  # This volume has no encryption
}

resource "aws_volume_attachment" "ebs_volume_attachment_web_server_secondary" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs_volume_web_server_secondary.id
  instance_id = aws_instance.ec2_instance_web_server.id
}


# EBS Snapshots


resource "aws_ebs_snapshot" "ebs_snapshot_web_server_secondary" {
  volume_id    = aws_ebs_volume.ebs_volume_web_server_secondary.id
  storage_tier = "standard" # It can also be archive
  #Since the volume is encrypted, the snapshot is unencrypted
}

# We can copy the snapshot o another region
resource "aws_ebs_snapshot_copy" "ebs_snapshot_copy_web_server_secondary" {
  source_snapshot_id = aws_ebs_snapshot.ebs_snapshot_web_server_secondary.id
  source_region      = "us-east-1"
}

# We can recreate the volume from an Snapshot in another AZ or Region
resource "aws_ebs_volume" "ebs_volume_web_server_third" {
  availability_zone = "us-east-1b"
  snapshot_id       = aws_ebs_snapshot.ebs_snapshot_web_server_secondary.id
}

# We can enable FSR on the snapshots
resource "aws_ebs_fast_snapshot_restore" "ebs_fsr_snapshot_web_server_secondary" {
  availability_zone = "us-west-1a"
  snapshot_id       = aws_ebs_snapshot.ebs_snapshot_web_server_secondary.id
}

# We can configure rules so when the Snapshots are deleted, they go to the Recycle bin
resource "aws_rbin_rule" "rbin_rule_snapshot_30_days" {
  description   = "retain_snapshots_for_30_days"
  resource_type = "EBS_SNAPSHOT"

  retention_period {
    retention_period_value = 30
    retention_period_unit  = "DAYS"
  }

  resource_tags {
    resource_tag_key   = "Environment"
    resource_tag_value = "test"
  }
}


# AMI


resource "aws_ami_from_instance" "ami_web_server" {
  name               = "ami-web-server"
  source_instance_id = aws_instance.ec2_instance_web_server.id
}


# Encrypt a volume


# We can copy the snapshot of an unencrypted volume and encrypt it
resource "aws_ebs_snapshot_copy" "ebs_snapshot_copy_encrypted_web_server_secondary" {
  source_snapshot_id = aws_ebs_snapshot.ebs_snapshot_web_server_secondary.id
  source_region      = "us-east-1"
  encrypted          = true
}


# Elastic File System


resource "aws_efs_file_system" "efs_cms_file_system" {
  creation_token = "cms-file-system"

  availability_zone_name = "us-east-1a" # This uses One-Zone, less cost

  # You can move the files between storage tiers based on rules
  lifecycle_policy {
    transition_to_ia      = "AFTER_30_DAYS"
    transition_to_archive = "AFTER_90_DAYS"
  }
  throughput_mode = "elastic"
  # provisioned_throughput_in_mibps = 1000 # You need to indicate the throughput if the throughput_mode is provisioned
  performance_mode = "generalPurpose" # Max I/O can't be used on elastic throughput_mode
}

resource "aws_efs_mount_target" "efs_mount_target_cms" {
  file_system_id = aws_efs_file_system.efs_cms_file_system.id
  subnet_id      = module.vpc.private_subnets[0] # Subnet in the same AZ we created the EFS
  # If we chosed the regional type, we can have multiple mount targets.
  security_groups = [aws_security_group.vpc_sg_allow_ssh.id]
}
