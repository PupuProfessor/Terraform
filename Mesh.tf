variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}

#VPC 
resource "aws_vpc" "backend_vpc" {
  cidr_block           = var.vpc_cidr_block
  tags = {
    Name = "vpc-backend"
  }
}

resource "aws_subnet" "backend_main" {
  vpc_id            = aws_vpc.backend_vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone  = var.avail_zone
  tags = {
    Name = "subnet--backend-main"
  }
}

#Security group
resource "aws_security_group" "security_group" {
  name        = "security_group-backend"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.backend_vpc.id
}

#create tasks in ECS ##一共需要10个
resource "aws_ecs_task_definition" "service-1" {
  family                = "service"
  container_definitions = file("task-definitions/service.json")
  requires_compatibilities = ["FARGATE"]

  proxy_configuration {
    type           = "APPMESH"
    container_name = "applicationContainerName"
    properties = {
      AppPorts         = "8080"
      EgressIgnoredIPs = "169.254.170.2,169.254.169.254"
      IgnoredUID       = "1337"
      ProxyEgressPort  = 15001
      ProxyIngressPort = 15000
    }
  }
}
  
#ECS 
resource "aws_ecs_cluster" "cluster" {
  name = "my-cluster"
}

#一共需要10个ECS service
resource "aws_ecs_service" "ecs_service" {
  name = "my-ecs-service"
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.service-1.arn
  desired_count = 10
 }
 

#App mesh 一共需要10个node！
resource "aws_appmesh_virtual_node" "virtual_node1" {
  name      = "my-virtual-node"
  mesh_name = "my-mesh"
  spec {
    backend{
        virtual_service {
          virtual_service_name= "virtual_service"
        }
      }
    }
  }


#一共需要10个route
resource "aws_appmesh_route" "route1" {
  name      = "service-route1"
  mesh_name = aws_appmesh_mesh.mesh.id
  virtual_router_name = aws_appmesh_virtual_router.router.name
  spec {
    grpc_route {
      match {
        prefix = "/"
      }
      action {
        weighted_target {
          virtual_node = aws_appmesh_virtual_node.virtual_node1.name
          weight      = 100
        }
      }
    }
  }
}

resource "aws_appmesh_virtual_service" "virtual_service" {
  name      = "my-virtual-service"
  mesh_name = "my-mesh"
  spec {
    provider {
      virtual_node {
        virtual_node_name = aws_appmesh_virtual_node.virtual_node1.name
      }
    }
  }
}

resource "aws_appmesh_virtual_router" "router" {
  name = "virtual_router"
  mesh_name = aws_appmesh_mesh.mesh.id  
  spec {
    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }
    }
  }
}


resource "aws_appmesh_mesh" "mesh" {
  name="mesh"
}




