variable "SUBID"  {
  type = string
  default = "f476e58b-5b40-478c-9ac9-461dc8f39866"
}

variable "CLIENTID" {
  type = string
  default = "f9c37912-27c8-41e5-89e0-dde8cdd74adb"
}

variable "CERTPATH" {
  type= string
  default = "/home/nick/terraform_install/cert2/service-principal.pfx"
}

variable "CERTPASS" {
  type = string
  default = "Fattycakes1"
}

variable "TENANTID" {
  type = string
  default = "72f988bf-86f1-41af-91ab-2d7cd011db47"
}

variable "location" {
  type = "string"
  default = "eastus"
  description = "Specify a location. See: az account list-locations -o table"
}

variable "tags" {
  type = "map"
  description = "A list of tags associated to all resources."
  default = {
    maintained_by = "terraform"
  }
}


