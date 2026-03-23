import 'config/app_config.dart';
import 'config/smithsonian_config.dart';
import 'services/art_api.dart';
import 'services/smithsonian_api.dart';
import 'main.dart';

void main() {
  appConfig = smithsonianConfig;
  artApi = SmithsonianApi();
  startApp();
}
