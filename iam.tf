resource "aws_iam_instance_profile" "ecs_profile" {
  name_prefix = "${replace(format("%.102s", replace("tf-ECSProfile-${var.name}-", "_", "-")), "/\\s/", "-")}"
  role        = "${aws_iam_role.ecs-role.name}"
  path        = "${var.iam_path}"
}

resource "aws_iam_role" "ecs-role" {
  name_prefix = "${replace(format("%.32s", replace("tf-ECSInRole-${var.name}-", "_", "-")), "/\\s/", "-")}"
  path        = "${var.iam_path}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
      "Service": ["ecs.amazonaws.com", "ec2.amazonaws.com", "spotfleet.amazonaws.com"]

    },
    "Effect": "Allow",
    "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "fleet" {
  name       = "${var.name}-fleet"
  roles      = ["${aws_iam_role.ecs-role.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetRole"
}

# It may be useful to add the following for troubleshooting the InstanceStatus
# Health check if using the fitnesskeeper/consul docker image
# "ec2:Describe*",
# "autoscaling:Describe*",

resource "aws_iam_policy" "ecs-policy" {
  name_prefix = "${replace(format("%.102s", replace("tf-ECSInPol-${var.name}-", "_", "-")), "/\\s/", "-")}"
  description = "A terraform created policy for ECS"
  path        = "${var.iam_path}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:RegisterContainerInstance",
        "ecs:StartTask",
        "ecs:ListClusters",
        "ecs:DescribeClusters",
        "ecs:RegisterTaskDefinition",
        "ecs:RunTask",
        "ecs:StopTask",
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",

        "ecr:UploadLayerPart",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",

        "logs:CreateLogStream",
        "logs:PutLogEvents",

        "autoscaling:Describe*",
        
        "ec2:Describe*"

      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "attach-ecs" {
  name       = "ecs-attachment"
  roles      = ["${aws_iam_role.ecs-role.name}"]
  policy_arn = "${aws_iam_policy.ecs-policy.arn}"
}

# IAM Resources for Consul and Registrator Agents

data "aws_iam_policy_document" "consul_task_policy" {
  statement {
    actions = [
      "ec2:Describe*",
      "autoscaling:Describe*",
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "assume_role_consul_task" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "consul_task" {
  count              = "${var.enable_agents ? 1 : 0}"
  name_prefix        = "${replace(format("%.32s", replace("tf-agentTaskRole-${var.name}-", "_", "-")), "/\\s/", "-")}"
  path               = "${var.iam_path}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_consul_task.json}"
}

resource "aws_iam_role_policy" "consul_ecs_task" {
  count       = "${var.enable_agents ? 1 : 0}"
  name_prefix = "${replace(format("%.102s", replace("tf-agentTaskPol-${var.name}-", "_", "-")), "/\\s/", "-")}"
  role        = "${aws_iam_role.consul_task.id}"
  policy      = "${data.aws_iam_policy_document.consul_task_policy.json}"
}
