variable "public_key" {
  type = string
}
output "public_ip" {
  value = aws_instance.wireguard.public_ip
}

output "public_dns" {
  value = aws_instance.wireguard.public_dns
}
