# XCodeChallenge - Proof Of Concept 

## Overview
![image](https://user-images.githubusercontent.com/25135647/185209970-d8633922-71aa-4655-b195-4cce79df87c2.png)

## Architecture key elements 
- Privately deployed API Gateway for secure network internal access
- Lambda back-end with proxy integration for request handling
- API Gateway, Lambda + DynamoDB all HIGHLY scalable and highly available 
- Basically NO infrastructure cost when not used 
- VPN connection single point of failure 
- Built with least privileges on resources in mind 
- Jump-Host / Bastion-Host for debugging purposes... 

### API Gateway 
- Highly scalable (10.000 requests per seconds max per account) 
- Highly available by design 
- Can add custom authorization if required (-> authorized users in company network?) 
- Can implement throttling 

### Lambda Back-End 
- Highly scalable (configurable with allowed and reserved concurrency)
- Highly available by design 
- Cold start of lambda can be slow, with go acceptable (some seconds) 

### DynamoDB 
- Highly scalable and highly available 
- VERY fast 
- Cheap for small objects and "GET" operations on partition key (SCAN ops can be VERY expensive, but not used here) 
- Larger objects or files should be stored in S3 rather than in DynamoDB (not implemented!) 


## Considerations

### Performance 
- Lambda cold start can be long
- On prolonged high request volume different solutions *could* be more suitable
- Generally very performant (API GW + warm lambda + DynDB VERY quick response time) 
- Access & VPN stability mainly relying on client connection 

### Security 
- When deployed in real scenario: No account should have read access to DynDB directly
- If read access to DynDB -> Secrects which are stored with decryption key can be directly read & decrypted 
- Same for S3 with larger files -> If read access on S3 AND DynDB table -> user can decrypt message! 
- All communication (even internal in VPC) is using HTTPS 
- Encryption & Decryption happens client side - client can choose not to supply key for decryption 
- If read access cannot be restricted -> encrypt key in lambda using additional key stored in SecretsManager, restrict access to Secret

### Costs 
- Assuming there is NO infrastructure to start with: 
  - ALB & DNS Resolver endpoints very expensive
  - AWS Client VPN also expensive on extended use 
- Assuming On-Prem <> AWS VPC already connected (site-to-site VPN, DNS available on both ends)
  - Routing & VPN connection free 
  - No additional cost for infrastructure needed 
  - Only ALB still needed to point alias to (API Gateway no valid target for private DNS) 
- Main service and components virtually free (pay per use except for VPC Endpoints)
- Lambda, DynamoDB and S3 very cost efficient the way they are used

# Current Implementation

## Overview
Red marked are the currently available connection and interface options. 
![image](https://user-images.githubusercontent.com/25135647/185219629-99b2ecac-f11c-42d2-9deb-44fef7a6785e.png)

## Usage 

### Create Mutual Auth. Certificates: 
LINK: https://docs.aws.amazon.com/vpn/latest/clientvpn-admin/client-authentication.html#mutual

Create new certificate using easyrsa 
```
git clone https://github.com/OpenVPN/easy-rsa.git
cd easy-rsa/easyrsa3
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa build-client-full client1.domain.tld nopass
```

Copy newly baked certificates in directory: 
```
mkdir ~/sharepass-cert/
cp pki/ca.crt ~/sharepass-cert/
cp pki/issued/server.crt ~/sharepass-cert/
cp pki/private/server.key ~/sharepass-cert/
cp pki/issued/client1.domain.tld.crt ~/sharepass-cert
cp pki/private/client1.domain.tld.key ~/sharepass-cert/
cd ~/sharepass-cert/
```

Add certificates to AWS Certificate Manager (make sure regions & profile match with deployment templates!): 
```
aws acm import-certificate --certificate fileb://server.crt --private-key fileb://server.key --certificate-chain fileb://ca.crt
aws acm import-certificate --certificate fileb://client1.domain.tld.crt --private-key fileb://client1.domain.tld.key --certificate-chain fileb://ca.crt
```

Now for local usage with OpenVPN, pack files together into on .p12 file 
```
openssl pkcs12 -export -in client1.domain.tld.crt -inkey client1.domain.tld.key -certfile ca.crt -name MyClient -out client.p12
```

Assuming this repo is already cloned, adapt the certificates (chain of trust, server cert) in the deployment template: 
**deploy/vpc.tf**:
```
resource "aws_ec2_client_vpn_endpoint" "sharepass-vpn" {
  client_cidr_block      = "10.0.16.0/20"
  split_tunnel           = false
  server_certificate_arn = "arn:aws:acm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" // server certificate server.domain....crt

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = "arn:aws:acm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" // root authority certificate ca.crt
  }
```

Finally, after connecting to the VPN, use {api-gw-deployment}-{vpc-endpoint-name}.execute-api.{region}.amazonaws.com/{stage}/... to make request: 
```
curl -X POST -H "Content-Type: application/json" -d '{"Id": "4ebbbfcc-7035-43e7-9f01-b326d46ef554"}' https://nvar1lcbmf-vpce-0981eba939b153643.execute-api.us-east-1.amazonaws.com/dev/api/v1/sharepass/actions/retrieve 
curl -X POST -H "Content-Type: application/json" -d '{"Secret":"TestSecret","Key":"TestKey","OneTime":true}' https://nvar1lcbmf-vpce-0981eba939b153643.execute-api.us-east-1.amazonaws.com/dev/api/v1/sharepass/actions/deposit
curl -X POST -H "Content-Type: application/json" -d '{"Id": "07e421d1-a8e7-41f1-aeea-b7fd40cbae0e"}' https://nvar1lcbmf-vpce-0981eba939b153643.execute-api.us-east-1.amazonaws.com/dev/api/v1/sharepass/actions/remove 
```


## Todo: 
- Add remote state!!! 
- file / binary handling (encrypted large files) 
- Private endpoint & policies for DynamoDB (https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/vpc-endpoints-dynamodb.html)
- Add error handling / retry logic for CRUD operations on DynDB
- TTL implementation for secrets in DynDB (can configure directly in DynDB per item) 
- Build client to encrypt / decrypt secrets (cli & webapp) 
- finalize documentation 
- review security of overall solution
- Consider additional crypto for storing secrets - perhaps KMS + SecretsMan? 

## Hints & Findings 
- R53 resolver resource apparently needs AT LEAST 2 subnets... 
- R53 resolvers are expensive! (180$ per endpoint per month) 
- In openVPN profile -> create pkcs12 container for openVPN import 
- Private hosted zone cannot directly create alias to internal API Gateway (endpoints) -> must use ALB inbetween

