import 'package:flutter/foundation.dart';
import '../../core/services/networkcaller.dart';
import '../../data/models/remote_file_model.dart';

class RemoteFilesProvider extends ChangeNotifier {
  final NetworkCaller _network = NetworkCaller.instance;

  List<RemoteFileModel> _files = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RemoteFileModel> get files => List.unmodifiable(_files);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _files.isEmpty && !_isLoading;

  Future<void> fetchFiles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _network.getRequest('/get');
    _isLoading = false;

    if (response.isSuccess) {
      _files = RemoteFileModel.parseList(response.responseData);
    } else {
      _errorMessage = response.errorMessage;
      _files = [];
    }

    notifyListeners();
  }

  Future<bool> deleteFile(String fileName) async {
    final response = await _network
        .deleteRequest('/delete?file=${Uri.encodeQueryComponent(fileName)}');
    if (response.isSuccess) {
      _files.removeWhere((f) => f.name == fileName);
      notifyListeners();
      return true;
    }
    _errorMessage = response.errorMessage;
    notifyListeners();
    return false;
  }
}
