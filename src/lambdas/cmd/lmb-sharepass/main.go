package main

import (
	"context"
	"log"
	"x/sharepass/router"
	"x/sharepass/sharepass"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	ginadapter "github.com/awslabs/aws-lambda-go-api-proxy/gin"
	"github.com/gin-gonic/gin"
	//"x/sharepass/sharepass"
)

var ginLambda *ginadapter.GinLambda

func init() {
	// stdout and stderr are sent to AWS CloudWatch Logs
	log.Printf("Gin cold start")

	sdkConfig, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatal(err)
	}

	dbImpl := *dynamodb.NewFromConfig(sdkConfig)
	dynDb := sharepass.NewDynDBRepo(&dbImpl, 10)
	//d := sharepass.SharepassRepositoryDummy{}
	a := sharepass.SharepassApplication{
		Db: dynDb,
	}

	r := gin.Default()
	router.LoadRoutes(r, a)

	ginLambda = ginadapter.New(r)
}

func Handler(
	ctx context.Context,
	req events.APIGatewayProxyRequest,
) (events.APIGatewayProxyResponse, error) {
	// If no name is provided in the HTTP request body, throw an error
	return ginLambda.ProxyWithContext(ctx, req)
}

func main() {
	lambda.Start(Handler)
}
