provider "aws" {
    region="ap-northeast-1"
    access_key = ""
    secret_key = ""
}
variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix"{}

#VPC
resource"aws_vpc""reservation"{
    cidr_block = var.vpc_cidr_block
    tags={
        Name:"${var.env_prefix}-vpc"
    }
}

#subnet to hold backend function
resource"aws_subnet""backend_main"{
vpc_id=aws_vpc.reservation.id
cidr_block = var.subnet_cidr_block
availability_zone = var.avail_zone
tags={
   Name="${var.env_prefix}-subnet-1" 
}
}

#App Mesh
resource "aws_appmesh_gateway_route" "GTW-R-backend" {
  name                 = "GTW-R-backend"
  mesh_name            = "Mesh-backend"
  virtual_gateway_name = aws_appmesh_virtual_gateway.GTW-backend.id

  spec {
    http_route {
      action {
        target {
          virtual_service {
            virtual_service_name = aws_appmesh_virtual_service.main-service.id
          }
        }
      }

      match {
        prefix = "/"
      }
    }
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_appmesh_virtual_gateway" "GTW-backend" {
  name      = "GTW-backend"
  mesh_name = "Mesh-backend"

  spec {
    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }
    }
  }

  tags = {
    Environment = "dev"
  }
}


resource "aws_appmesh_mesh" "Mesh-backend" {
  name = "Backend"

  spec {
    egress_filter {
      type = "ALLOW_ALL"
    }
  }
}

resource "aws_appmesh_virtual_service" "main-service" {
  name      = "main-service"
  mesh_name = aws_appmesh_mesh.Mesh-backend.id
 
  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.VRT.id
      }
    }
  }
}

resource "aws_appmesh_virtual_router" "VRT" {
  name      = "VRT"
  mesh_name = aws_appmesh_mesh.Mesh-backend.id

  spec {
    listener {
      port_mapping {
        port     = XXXX
        protocol = "gRCP"
      }
    }
  }
}

resource "aws_appmesh_virtual_node" "Node-1" {
  name      = "Node-1"
  mesh_name = aws_appmesh_mesh.Mesh-backend.id

  spec {
    backend {
      virtual_service {
        virtual_service_name = "main-service"
      }
    }

    listener {
      port_mapping {
        port     = XXXX
        protocol = "gRCP"
      }
    }
  }
}

