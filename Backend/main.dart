import 'dart:io';
import 'dart:convert';
import 'package:mysql1/mysql1.dart';

void main() async {
  // var chain = Platform.script.resolve('chain.pem').toFilePath();
  // var key = Platform.script.resolve('key.pem').toFilePath();
  // var context = SecurityContext()
  //   ..useCertificateChain(chain)
  //   ..usePrivateKey(key);

  var settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'emsUser',
    password: 'password',
    db: 'ems',
  );

  MySqlConnection db = await MySqlConnection.connect(settings);

  // var server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 443, context);
  var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);
  await server.forEach((HttpRequest request) async {
    if (request.uri.path == '/get-notification' && request.method == 'POST') {
      // retrieve the lat/long from the request body
      String body = await utf8.decodeStream(request);
      List<double> latLong = body.split('|').map((e) => double.parse(e)).toList();

      int latitude = (latLong[0] * 100000).toInt();
      int longitude = (latLong[1] * 100000).toInt();
      // check db for ems within 1 mile of the lat/long
      var results = await db.query("select * from ems where latitude between ? and ? and longitude between ? and ? and lastUpdate > ?", [latitude - 10, latitude + 10, longitude - 10, longitude + 10, "10 min ago"]);
    
      request.response.write("${results.length}");
      request.response.close();
      return;
    }

    if (request.uri.path == '/send-notification' && request.method == 'POST') {
      // Authentication
      //???

      // retrieve the lat/long from the ems vehicle
      String body = await utf8.decodeStream(request);
      List<double> latLong = body.split('|').map((e) => double.parse(e)).toList();
      
      // update db with the new lat/long
      var results = await db.query("update ems set latitude = ?, longitude = ? where id = ?", [
        (latLong[1] * 100000).toInt(), (latLong[2] * 100000).toInt(), latLong[0].toInt()]);
    
      // ??? 
      // profit
      
      request.response.write('1');
      request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not found');
    request.response.close();
  });
}