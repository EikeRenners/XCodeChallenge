package sharepass

import (
	"encoding/json"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

type SharepassRepository interface {
	PutObject(s *SecretDepositDto) (string, error)
	GetObject(id string) (*Secret, error)
	Delete(id string) error
}

type SecretId struct {
	Id string `json:"id"`
}

type SecretDepositDto struct {
	Secret  string `json:"secret"`
	Key     string `json:"key"`
	OneTime bool   `json:"onetime"`
}

type SecretAccessDto struct {
	Secret  string `json:"secret"`
	Key     string `json:"key"`
	Deleted bool   `json:"deleted"`
}

// Actual DynamoDB table structure...
type Secret struct {
	SecretId         string `json:"SecretId"` // PK
	Secret           string `json:"Secret"`
	Key              string `json:"Key"`
	OneTime          bool   `json:"Onetime"`
	DepositTimestamp string `json:"Created"`
	Ttl              string `json:"TTL"`
}

type SharepassApplication struct {
	Db SharepassRepository
}

func (a SharepassApplication) GetSecret(context *gin.Context) {
	defer context.Request.Body.Close()
	buf, err := io.ReadAll(context.Request.Body)
	if err != nil {
		context.JSON(http.StatusBadRequest, http.StatusText(http.StatusBadRequest))
		log.Fatal("Error reading request body: {}", err)
	}
	log.Printf("body: %s", buf)

	id := SecretId{}
	err = json.Unmarshal(buf, &id)
	if err != nil {
		context.JSON(http.StatusBadRequest, http.StatusText(http.StatusBadRequest))
		log.Fatal("Error parsing Id from body: {}", err)
	}

	// db look up secret
	sec, err := a.Db.GetObject(id.Id)
	if err != nil {
		context.JSON(http.StatusInternalServerError, http.StatusText(http.StatusInternalServerError))
		log.Fatal("Error retrieving secret from DB: {}", err)
	}
	if sec == nil {
		context.JSON(http.StatusNotFound, http.StatusText(http.StatusNotFound))
		return
	}

	ret := SecretAccessDto{
		Secret:  sec.Secret,
		Key:     sec.Key,
		Deleted: true,
	}

	if sec.OneTime == true {
		err := a.Db.Delete(id.Id)
		if err != nil {
			context.JSON(http.StatusInternalServerError, http.StatusText(http.StatusInternalServerError))
			log.Println("Error deleting after read: {}", err)
			ret.Deleted = false // Todo: add some more error handling here? Retry perhaps?
		}
	}

	log.Printf("secret from db: %v", sec)
	var txt, _ = json.Marshal(ret)

	context.JSON(http.StatusOK, string(txt))
}

func (a SharepassApplication) PostSecret(context *gin.Context) {
	defer context.Request.Body.Close()
	buf, err := io.ReadAll(context.Request.Body)
	if err != nil {
		context.JSON(http.StatusBadRequest, http.StatusText(http.StatusBadRequest))
		log.Fatal("Error reading request body: {}", err)
	}
	log.Printf("body: %s", buf)

	secret := SecretDepositDto{}
	err = json.Unmarshal(buf, &secret)
	if err != nil {
		context.JSON(http.StatusBadRequest, http.StatusText(http.StatusBadRequest))
		log.Fatal("Error parsing secret dto from body: {}", err)
	}

	key, err := a.Db.PutObject(&secret)
	if err != nil {
		context.JSON(http.StatusInternalServerError, http.StatusText(http.StatusInternalServerError))
		log.Fatal("Error storing secret in dynDB table: {}", err)
	}

	sid := SecretId{Id: key}
	var txt, _ = json.Marshal(sid)
	context.JSON(http.StatusOK, string(txt))
}

func (a SharepassApplication) DeleteSecret(context *gin.Context) {
	defer context.Request.Body.Close()
	buf, err := io.ReadAll(context.Request.Body)
	if err != nil {
		context.JSON(http.StatusBadRequest, http.StatusText(http.StatusBadRequest))
		log.Fatal("Error reading request body: {}", err)
	}
	log.Printf("body: %s", buf)

	id := SecretId{}
	err = json.Unmarshal(buf, &id)
	if err != nil {
		context.JSON(http.StatusBadRequest, http.StatusText(http.StatusBadRequest))
		log.Fatal("Error parsing Id from body: {}", err)
	}

	// db look up and delete secret
	err = a.Db.Delete(id.Id)
	if err != nil {
		context.JSON(http.StatusInternalServerError, http.StatusText(http.StatusInternalServerError))
		log.Fatal("Error deleting secret from dynDB: {}", err)
	}

	context.JSON(http.StatusOK, http.StatusText(http.StatusOK))
}
