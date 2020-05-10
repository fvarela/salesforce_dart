import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:convert';

const String DEFAULT_SF_VERSION = '48.0';

class Salesforce {
  final String username;
  final String password;
  final String securityToken;
  final bool sandBox;
  String sfVersion;
  String sfInstance;
  var headers;

  Salesforce(
      {this.username,
      this.password,
      this.securityToken,
      this.sandBox: false,
      this.sfVersion}) {
    final String domain = sandBox ? 'test' : 'login';
    this.sfVersion = (sfVersion == null) ? DEFAULT_SF_VERSION : sfVersion;

    final String clientId = 'RestForce';

    final soapUrl = 'https://$domain.salesforce.com/services/Soap/u/$sfVersion';
    final String loginSoapRequestBody =
        '''<?xml version="1.0" encoding="utf-8" ?>
        <env:Envelope
                xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"
                xmlns:urn="urn:partner.soap.sforce.com">
            <env:Header>
                <urn:CallOptions>
                    <urn:client>$clientId</urn:client>
                    <urn:defaultNamespace>sf</urn:defaultNamespace>
                </urn:CallOptions>
            </env:Header>
            <env:Body>
                <n1:login xmlns:n1="urn:partner.soap.sforce.com">
                    <n1:username>$username</n1:username>
                    <n1:password>$password$securityToken</n1:password>
                </n1:login>
            </env:Body>
        </env:Envelope>''';
    final loginSoapRequestHeaders = {
      'content-type': 'text/xml',
      'charset': 'UTF-8',
      'SOAPAction': 'login'
    };
    _soapLogin(soapUrl, loginSoapRequestBody, loginSoapRequestHeaders);
  }
  _soapLogin(soapUrl, loginSoapRequestBody, loginSoapRequestHeaders) async {
    var response = await http.post(soapUrl,
        headers: loginSoapRequestHeaders, body: loginSoapRequestBody);
    String data = response.body;
    var decodedData = xml.parse(data);

    if (response.statusCode == 200) {
      var sessionId = decodedData
          .findAllElements('sessionId')
          .map((node) => node.text)
          .first;
      var sfInstance = decodedData
          .findAllElements('serverUrl')
          .map((node) => node.text)
          .first
          .replaceAll('http://', '')
          .replaceAll('https://', '')
          .split('/')[0]
          .replaceAll('-api', '');

      this.sfInstance = sfInstance;
      this.headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + sessionId,
        'X-PrettyPrint': '1'
      };
    } else {
      String exceptionCode = decodedData
          .findAllElements('sf:exceptionCode')
          .map((node) => node.text)
          .first;
      String errorMessage = decodedData
          .findAllElements('sf:exceptionMessage')
          .map((node) => node.text)
          .first;
      throw ('Cold not log in to salesforce. Error code: $exceptionCode\nError message: $errorMessage');
    }
  }

  querySoql(queryTxt) async {
    // var auth = {'Authorization':headers['Authorization']};
    var response = await http.get(
        'https://${this.sfInstance}/services/data/v${this.sfVersion}/queryAll?q=$queryTxt',
        headers: this.headers);

    if (response.statusCode == 200) {
      String data = response.body;
      return jsonDecode(data);
    } else {
      print(response.statusCode);
    }
  }
}
