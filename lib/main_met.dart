import 'config/app_config.dart';
import 'config/met_config.dart';
import 'services/art_api.dart';
import 'services/met_api.dart';
import 'main.dart';

void main() {
  appConfig = metConfig;
  artApi = MetApi();
  startApp();
}
