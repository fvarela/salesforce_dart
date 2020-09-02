import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'dart:convert';
import 'dart:core';

const String DEFAULT_SF_VERSION = '49.0';

class Salesforce {
  String _username;
  String _password;
  String _securityToken;
  final bool sandBox;
  String sfVersion;
  String sfInstance;
  var headers;

  Salesforce(
      {@required username,
      @required password,
      @required securityToken,
      this.sandBox : false,
      this.sfVersion}) {
    _username = username;
    _password = password;
    _securityToken = securityToken;
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
                    <n1:username>$_username</n1:username>
                    <n1:password>$_password$_securityToken</n1:password>
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

  Future<Map> querySoql(String queryTxt) async {
    // var auth = {'Authorization':headers['Authorization']};
    var response;
    try {
      response = await http.get(
          'https://${this.sfInstance}/services/data/v${this
              .sfVersion}/queryAll?q=$queryTxt',
          headers: this.headers);
    } catch(e){
      print('Client error caught $e');
    }
    if (response.statusCode == 200) {
      String data = response.body;
      return jsonDecode(data);
    } else {
      print(response.statusCode);
      return null;
    }
  }

  Future<Map> getPickListValues(String object, List fields) async{
  var response;
  Map pickLists = {};
  try{
    response = await http.get(
      'https://${this.sfInstance}/services/data/v${this
          .sfVersion}/sobjects/$object/describe', headers: this.headers);

  } catch(e){
      print('Client error caught $e');
    }
  if (response.statusCode == 200) {
    String data = response.body;
    Map decoded = jsonDecode(data);
    for (Map objectField in decoded['fields']){
      for (String field in fields){
        if (field == objectField['name']){
          List pickList = [];
          for (Map singleValue in objectField['picklistValues']){
            pickList.add(singleValue['value']);
          }
          pickLists[field] = pickList;
          break;
        }
      }
    }
    return pickLists;
  }
  else{
    print(response.statusCode);
    return {};
  }
  }



  Future<List> querySosl(String queryTxt) async {
    var response = await http.get(
        'https://${this.sfInstance}/services/data/v${this
            .sfVersion}/search?q=${Uri.encodeComponent(queryTxt)}',
        headers: this.headers);
    Map soslResults = jsonDecode(response.body);
    List ids = [];
    soslResults["searchRecords"].forEach((element) => ids.add(element["Id"]));
    return ids;
  }

  String listToString(List ids) {
    String someIds;
    if (ids.length > 0) {
      someIds = '(';
      for (int i = 0; i < ids.length; i++) {
        if (i < ids.length - 1) {
          someIds += "'${ids[i]}', ";
        } else {
          someIds += "'${ids[i]}')";
        }
      }
    }
    return someIds;
  }

  String getUserEmail(){

      RegExp regExp = new RegExp(r'^[a-zA-Z0-9_.+-]+@varian.com');
    return regExp.stringMatch(_username);
  }


   // print('Stop');
//    String someIds = '(';
//    if (soslResults['searchRecords'].length > 0) {
//      for (int i = 0; i < soslResults['searchRecords'].length; i++) {
//        if (i < soslResults['searchRecords'].length - 1) {
//          someIds += "'${soslResults['searchRecords'][i]['Id']}', ";
//        } else {
//          someIds += "'${soslResults['searchRecords'][i]['Id']}')";
//        }
//      }
//
//      String soqlTxt = """SELECT Id,
//                            Title,
//                            ValidationStatus,
//                            Manager_Name__c
//                        FROM Service_Article__kav
//                        WHERE Id IN $someIds""";

//      return querySoql(soqlTxt);
//    }
  }

