import 'config/app_config.dart';
import 'config/aic_config.dart';
import 'services/art_api.dart';
import 'services/aic_api.dart';
import 'main.dart';

void main() {
  appConfig = aicConfig;
  artApi = AicApi();
  startApp();
}
