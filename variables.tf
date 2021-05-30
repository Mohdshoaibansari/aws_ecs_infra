variable "TaskRole" {
    type = string
    default = "arn:aws:iam::070814490905:role/ecsInstanceRole"
}

variable "taskexecution" {
    type = string
    default = "arn:aws:iam::070814490905:role/ecsTaskExecutionRole"
  
}

variable "lt-SG" {
    type = string
    default = "sg-0754aedc73a558b59"
  
}