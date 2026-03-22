import 'config/app_config.dart';
import 'config/rembrandt_config.dart';
import 'services/art_api.dart';
import 'services/rembrandt_api.dart';
import 'main.dart';

void main() {
  appConfig = rembrandtConfig;
  artApi = RembrandtApi();
  startApp();
}
