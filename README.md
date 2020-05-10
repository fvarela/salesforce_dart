# salesforce_dart
Handles login to Salesforce with username, password and secure_token.
Retrieves SOQL querys from Salesforce

Note that I just compied what I needed from the python library simple_salesforce and translated it to dart. If you need any other feature it should be easy to take it from simple_salesforce and add it here.

## Usage example
import:
`import 'package:Salesforce/salesforce.dart';`

#### Initilize
Use your regular Salesforce credentials plus the securetoken:
`Salesforce salesforce = Salesforce(
    username: 'yourname@yourcompany.com',
    password: 'yourpassword',
    securityToken: 'yoursecuretoken');`

#### Use
`var queryResults = await salesforce.querySoql(
    "SELECT Name FROM User WHERE Emain = 'yourname@yourcompany.com'");`
