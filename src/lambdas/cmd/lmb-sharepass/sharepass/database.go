package sharepass

import (
	"context"
	"time"

	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/google/uuid"
)

const TableName string = "sharepass-dyndb-table"

///
/// DynamoDB Repository
///
type SharepassRepositoryDynDB struct {
	timeout time.Duration
	client  *dynamodb.Client
}

func NewDynDBRepo(cl *dynamodb.Client, timeout time.Duration) SharepassRepositoryDynDB {
	return SharepassRepositoryDynDB{
		timeout: timeout,
		client:  cl,
	}
}

func (db SharepassRepositoryDynDB) PutObject(s *SecretDepositDto) (string, error) {
	secret := Secret{
		SecretId:         uuid.NewString(),
		Secret:           s.Secret,
		Key:              s.Key,
		Ttl:              "",
		OneTime:          s.OneTime,
		DepositTimestamp: time.Now().Format("2006-01-02T15:04:05Z"),
	}

	item, err := attributevalue.MarshalMap(secret)
	if err != nil {
		return "", err
	}

	input := &dynamodb.PutItemInput{
		TableName: aws.String(TableName),
		Item:      item,
	}

	res, err := db.client.PutItem(context.TODO(), input)
	if err != nil {
		return "", err
	}

	err = attributevalue.UnmarshalMap(res.Attributes, &secret)
	if err != nil {
		return "", err
	}

	return secret.SecretId, nil
}

func (db SharepassRepositoryDynDB) GetObject(id string) (*Secret, error) {
	key, err := attributevalue.Marshal(id)
	if err != nil {
		return nil, err
	}

	input := &dynamodb.GetItemInput{
		TableName: aws.String(TableName), // this needs to be env var!!!
		Key: map[string]types.AttributeValue{
			"SecretId": key,
		},
	}

	result, err := db.client.GetItem(context.TODO(), input)
	if err != nil {
		return nil, err
	}

	if result.Item == nil {
		return nil, nil
	}

	secret := Secret{}
	err = attributevalue.UnmarshalMap(result.Item, &secret)
	if err != nil {
		return nil, err
	}

	return &secret, nil
}

func (db SharepassRepositoryDynDB) Delete(id string) error {
	key, err := attributevalue.Marshal(id)
	if err != nil {
		return err
	}

	input := &dynamodb.DeleteItemInput{
		TableName: aws.String(TableName), // this needs to be env var!!!
		Key: map[string]types.AttributeValue{
			"SecretId": key,
		},
	}

	_, err = db.client.DeleteItem(context.TODO(), input)
	if err != nil {
		return err
	}

	return nil
}

///
/// Dummy Repository
///
type SharepassRepositoryDummy struct {
}

func (db SharepassRepositoryDummy) PutObject(s *SecretDepositDto) (string, error) {
	return "ENCRYPTIONKEY", nil
}

func (db SharepassRepositoryDummy) GetObject(id string) (*Secret, error) {
	var temp = Secret{
		Secret:  "SUPERMEGASECRETSTRINGYO",
		Key:     "ENCRYPTIONKEY",
		OneTime: true,
	}

	return &temp, nil
}

func (db SharepassRepositoryDummy) Delete(key string) error {
	return nil
}
