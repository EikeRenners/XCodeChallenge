package router

import (
	"net/http"
	"x/sharepass/sharepass"

	"github.com/gin-gonic/gin"
)

func LoadRoutes(r *gin.Engine, app sharepass.SharepassApplication) {

	r.GET("/api/v1/ping", func(context *gin.Context) {
		context.JSON(http.StatusOK, gin.H{
			"message": "pong",
		})
	})
	r.GET("/api/v1/health", func(context *gin.Context) {
		context.JSON(http.StatusOK, gin.H{
			"message": "OK",
		})
	})

	// API For Sharepass
	r.POST("/api/v1/sharepass/actions/deposit", app.PostSecret)  // {secret}
	r.POST("/api/v1/sharepass/actions/retrieve", app.GetSecret)  // {"id"="uuid"}
	r.POST("/api/v1/sharepass/actions/remove", app.DeleteSecret) // {"id"="uuid"}
}
