import '../serialized/user_data.dart';
import 'state_collection.dart';

class StateUsers extends StateCollection {
  @override
  int limitDefault = 20;

  @override
  List<UserData> get serialized {
    if (data == null) return [];
    List<UserData> items = (data as List<dynamic>)
        .map((value) => UserData.fromJson(value))
        .toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }
}
