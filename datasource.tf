data "aws_availability_zones" "available" {}
resource "aws_subnet" "public-subnet-a" {
  vpc_id = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = true
  cidr_block = "10.0.10.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  tags = {
  Name = "public-subnet-a:${var.labname}"
  }
}


data "aws_route53_zone" "zone" {
  name = "${var.route53_hosted_zone_name}"
}