# ==================== ALB SECURITY GROUP ====================
resource "aws_security_group" "alb" {
  name        = "${var.cluster_name}-alb"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-alb"
  }
}

# ==================== DATA SOURCES ====================
data "aws_security_group" "cluster_sg" {
  id = module.eks.cluster_security_group_id
}

data "aws_security_group" "node_sg" {
  id = module.eks.cluster_primary_security_group_id
}

# ==================== SECURITY GROUP RULES ====================
# Rules for CLUSTER security group (pods use this)
resource "aws_security_group_rule" "alb_to_frontend_cluster" {
  description              = "Allow ALB to access frontend pods on port 3000"
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = data.aws_security_group.cluster_sg.id
  depends_on               = [module.eks]
}

resource "aws_security_group_rule" "alb_to_backend_cluster" {
  description              = "Allow ALB to access backend pods on port 3001"
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = data.aws_security_group.cluster_sg.id
  depends_on               = [module.eks]
}

# Rules for NODE security group
resource "aws_security_group_rule" "alb_to_frontend_node" {
  description              = "Allow ALB to access frontend on nodes"
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = data.aws_security_group.node_sg.id
  depends_on               = [module.eks]
}

resource "aws_security_group_rule" "alb_to_backend_node" {
  description              = "Allow ALB to access backend on nodes"
  type                     = "ingress"
  from_port                = 3001
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = data.aws_security_group.node_sg.id
  depends_on               = [module.eks]
}
