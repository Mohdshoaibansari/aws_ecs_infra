provider "aws" {
  region = "ap-southeast-1"
}


/* 1. cluser
2. Task Definition
3. Load Balancer
4. Auto-scaling Group. */


#Pre-Requisite Resource:

#Image ID
data "aws_ssm_parameter" "ami_id" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

data "aws_iam_policy" "ecs-agent-policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

#Role Policy
data "aws_iam_policy_document" "instance-role-policy" {
  statement {
    sid = "1"
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
  }
}

##Role For Instance

resource "aws_iam_role" "lt_role" {
    name = "ECS-instance-role"
    path = "/"
    assume_role_policy = data.aws_iam_policy_document.instance-role-policy.json
}

# Attach Policy to Role

resource "aws_iam_role_policy_attachment" "ecs-role-policy-attach" {
  role = aws_iam_role.lt_role.name
  policy_arn = data.aws_iam_policy.ecs-agent-policy.arn
  
}

#Instance Profile
resource "aws_iam_instance_profile" "ecs-ec2_profile" {
  name = "ecs-ec2_profile"
  role = aws_iam_role.lt_role.name
}

# Cloudwatch Loggroup

resource "aws_cloudwatch_log_group" "tasks-log-group" {
  name = "/ecs/fargate-task-definition"

  tags = {
    Environment = "Test"
    Application = "serviceA"
  }
}


# Auto-Scaling Group and Launch Template to create instances in ECS Cluster

resource "aws_launch_template" "ec2-template" {
    name = "ec2-ami-launch-template"
    image_id = lookup(jsondecode(data.aws_ssm_parameter.ami_id.value),"image_id")
    instance_type = "t2.micro"
    key_name = "shoaib-Singapore"
    vpc_security_group_ids = [ var.lt-SG ]
    iam_instance_profile {
      arn=aws_iam_instance_profile.ecs-ec2_profile.arn
    }
    user_data = filebase64("${path.module}/ecs-ec2.sh")
}

resource "aws_autoscaling_group" "ecs-asg" {
    name = "ecs-asg"
    max_size                  = 2
    min_size                  = 1
    desired_capacity          = 1

    launch_template {
      id = aws_launch_template.ec2-template.id
    }
    health_check_type = "EC2"
    vpc_zone_identifier = ["subnet-4a585903","subnet-dac9d8bd"]
  
}

#ECS Cluster
resource "aws_ecs_cluster" "ec2-cluster" {
    name = "ec2-cluster"
    setting {
      name = "containerInsights"
      value = "enabled"
    }
}

#Task Definition
resource "aws_ecs_task_definition" "ec2-task-definition" {
    family = "ec2-tasks"
    execution_role_arn = var.taskexecution
    network_mode = "bridge"
    requires_compatibilities = [ "EC2" ]
    task_role_arn = var.taskexecution
    
    container_definitions=file("container.json")

    tags = {
      "Description" = "For EC2 Instance Tasks"

    }
}

resource "aws_ecs_service" "ec2-task-service" {
    name            = "nginx"
    launch_type     = "EC2"
    cluster         = aws_ecs_cluster.ec2-cluster.arn
    task_definition = aws_ecs_task_definition.ec2-task-definition.arn
    scheduling_strategy = "REPLICA"
    /* network_configuration {
      subnets = [ "subnet-4a585903","subnet-dac9d8bd" ]
      security_groups = [ var.lt-SG ]
      assign_public_ip = false
    } */

    desired_count   = 1
    deployment_controller {
      type = "ECS"
    }
    deployment_minimum_healthy_percent  = 50
    deployment_maximum_percent  = 100

    
  
}

output "image_id" {
    /* value = lookup(jsondecode(data.aws_ssm_parameter.ami_id.value),"image_id") */
    value = aws_iam_instance_profile.ecs-ec2_profile.arn
}