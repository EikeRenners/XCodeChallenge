# locals {
#   lambdas = {
#     lmb-sharepass = {
#       description = "sharepass main handler"
#       timeout     = 10
#     }
#   }

#   null = {
#     lambda_binary_exists = { for key, _ in local.lambdas : key => fileexists("${path.module}/../src/lambdas/bin/${key}/${key}") }
#   }
# }

# resource "null_resource" "lambda_build" {
#   for_each = local.lambdas

#   provisioner "local-exec" {
#     command = "export GO111MODULE=on"
#   }

#   provisioner "local-exec" {
#     command = "GOOS=linux GOARCH=amd64 go build -ldflags '-s -w' -o ${path.module}/../src/lambdas/bin/${each.key}/${each.key} ${path.module}/../src/lambdas/cmd/${each.key}/."
#   }

#   triggers = {
#     binary_exists = local.null.lambda_binary_exists[each.key]
#     timestamp = "${timestamp()}"
#      main = join("", [
#        for file in fileset("${path.module}/../src/lambdas/cmd/${each.key}", "*.go") : filebase64("${path.module}/../src/lambdas/cmd/${each.key}/${file}")
#      ])
#   }
# }